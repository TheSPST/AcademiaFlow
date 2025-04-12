import SwiftUI
import PDFKit
import SwiftData

/// ViewModel for handling PDF document viewing and annotation
@MainActor
protocol PDFViewModelProtocol: ObservableObject {
    var isLoading: Bool { get }
    var currentPage: Int { get set }
    var totalPages: Int { get }
    func loadPDF() async -> (any AppError)?
    func addNote()
}

/// Protocol for PDF search functionality
@MainActor
protocol PDFSearchable {
    func performSearch()
    func nextSearchResult()
    func previousSearchResult()
}

/// Protocol for PDF annotation functionality
//@MainActor
//protocol PDFAnnotatable {
//    func addAnnotation() -> (any AppError)?
//    func removeAnnotation(_ annotation: PDFAnnotation)
//}

/// Protocol for PDF navigation functionality
@MainActor
protocol PDFNavigatable {
    func goToNextPage()
    func goToPreviousPage()
    func navigateToPage(_ pageIndex: Int)
}

@MainActor
class PDFViewModel: ObservableObject, PDFViewModelProtocol, PDFSearchable, PDFNavigatable {
    // MARK: - Published Properties
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: Error?
    @Published var selectedPage: PDFPage?
    @Published var currentPage = 1
    @Published private(set) var totalPages = 1
    @Published var zoomLevel: CGFloat = 1.0
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var currentSearchResult = 0
    @Published var totalSearchResults = 0
    @Published var showThumbnailView = false
    @Published var currentAnnotationColor = NSColor.yellow
    @Published var currentAnnotationType: AnnotationType = .highlight
    @Published var notes: [Note] = []
    @Published var annotations: [StoredAnnotation] = []
    private var annotationSnapshots: [StoredAnnotationSnapshot] = []
    @Published var isAddingNote = false
    @Published var newNoteTitle = ""
    @Published var newNoteContent = ""
    @Published var newNoteTags: [String] = []
    @Published var showNotes: Bool = false
    @Published var showBookmarks = false
    @Published var bookmarks: [PDFBookmark] = []
    
    @Published var showChatView: Bool = true
    @Published var chatMessages: [(question: String, answer: String)] = []
    @Published var currentQuestion: String = ""
    @Published var isProcessingQuestion: Bool = false
    
    @Published var selectedAnnotation: PDFAnnotation?
    @Published var isEditingAnnotation = false
    @Published var annotationPreviewActive = false
    @Published var lastAnnotations: [PDFAnnotation] = [] // For undo functionality
    
    @Published private(set) var isScrollingAnimated = false
    
    @Published var filteredAnnotations: [StoredAnnotation] = []
    @Published var selectedAnnotations: Set<String> = []
    @Published var annotationFilter: AnnotationFilter = .all
    @Published var redoStack: [PDFAnnotation] = []
    @Published var selectedCategory: String?
    @Published var selectedTags: Set<String> = []
    
    var annotationService: PDFAnnotationService!
    // MARK: - Private Properties
    private var searchResults: [PDFSelection] = []
    private weak var pdfView: PDFView?
    private let pdf: PDF
    private let modelContext: ModelContext
    private var document: PDFDocument?
    private let chatService = ChatService()
    private var shortcutMonitor: Any?
    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0
    private let zoomStep: CGFloat = 1.25
    private var lastScrollPosition: CGPoint?
    
    // MARK: - Types
    enum AnnotationType {
        case highlight
        case underline
        case strikethrough
        case note
    }
    
    enum AnnotationFilter {
        case all
        case highlights
        case underlines
        case strikethrough
        case notes
        case category(String)
        case tags([String])
    }
    
    // MARK: - Initialization
    init(pdf: PDF, modelContext: ModelContext) {
        self.pdf = pdf
        self.modelContext = modelContext
        
        Task { @MainActor in
            self.annotationService = PDFAnnotationService(modelContainer: modelContext.container)
            await self.loadInitialData()
            self.setupShortcuts()
        }
    }
    
    // MARK: - Public Methods
    func setPDFView(_ view: PDFView) {
        self.pdfView = view
    }
    
    func loadPDF() async -> (any AppError)? {
        isLoading = true
        
        guard FileManager.default.fileExists(atPath: pdf.fileURL.path) else {
            return PDFError.fileNotFound
        }
        
        guard let document = PDFDocument(url: pdf.fileURL) else {
            return PDFError.invalidDocument
        }
        
        self.document = document
        pdfView?.document = document
        totalPages = document.pageCount
        
        setupInitialView()
        isLoading = false
        return nil
    }
    
    // MARK: - Search Methods
    func performSearch() {
        guard let document = document else { return }
        
        searchResults.removeAll()
        currentSearchResult = 0
        totalSearchResults = 0
        
        if searchText.isEmpty {
            isSearching = false
            return
        }
        
        isSearching = true
        
        if let selection = document.findString(searchText, withOptions: .caseInsensitive).first {
            searchResults = [selection]
            
            var lastSelection = selection
            while let nextSelection = document.findString(searchText, fromSelection: lastSelection, withOptions: .caseInsensitive) {
                searchResults.append(nextSelection)
                lastSelection = nextSelection
            }
            
            totalSearchResults = searchResults.count
            if !searchResults.isEmpty {
                currentSearchResult = 1
                highlightCurrentSelection()
            }
        }
    }
    
    func nextSearchResult() {
        if currentSearchResult < totalSearchResults {
            currentSearchResult += 1
        } else {
            currentSearchResult = 1
        }
        highlightCurrentSelection()
    }
    
    func previousSearchResult() {
        if currentSearchResult > 1 {
            currentSearchResult -= 1
        } else {
            currentSearchResult = totalSearchResults
        }
        highlightCurrentSelection()
    }
    
    // MARK: - Zoom Controls
    func zoomIn() {
        withAnimation(.easeInOut(duration: 0.25)) {
            zoomLevel = min(zoomLevel * zoomStep, maxZoom)
            pdfView?.scaleFactor = zoomLevel
        }
    }
    
    func zoomOut() {
        withAnimation(.easeInOut(duration: 0.25)) {
            zoomLevel = max(zoomLevel / zoomStep, minZoom)
            pdfView?.scaleFactor = zoomLevel
        }
    }
    
    func resetZoom() {
        zoomLevel = 1.0
        pdfView?.scaleFactor = zoomLevel
    }
    
    func fitToWidth() {
        guard let pdfView = pdfView else { return }
        // Store current vertical position
        let currentY = pdfView.enclosingScrollView?.documentVisibleRect.origin.y
        
        // Calculate new zoom
        let newZoom = pdfView.scaleFactorForSizeToFit
        
        withAnimation(.easeInOut(duration: 0.25)) {
            zoomLevel = newZoom
            pdfView.scaleFactor = newZoom
            
            // Restore vertical position
            if let currentY = currentY {
                pdfView.enclosingScrollView?.contentView.scroll(to: CGPoint(x: 0, y: currentY))
            }
        }
    }

    // MARK: - Page Navigation
    func handlePageClick() {
        guard let currentPage = pdfView?.currentPage else { return }
        selectedPage = currentPage
        if let pageNum = currentPage.pageRef?.pageNumber {
            self.currentPage = pageNum
        }
    }
    
    func goToNextPage() {
        if currentPage < totalPages {
            currentPage += 1
            navigateToPage(currentPage - 1)
        }
    }
    
    func goToPreviousPage() {
        if currentPage > 1 {
            currentPage -= 1
            navigateToPage(currentPage - 1)
        }
    }
    private func pdfNSError(_ message: String) -> NSError {
        return NSError(domain: "PDF", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    // MARK: - Annotation Methods
    @MainActor
    func addAnnotation() async -> (any AppError)? {
        do {
            guard let pdfView = pdfView,
                  let currentSelection = pdfView.currentSelection,
                  let currentPage = pdfView.currentPage else {
                return PDFError.annotationFailed(pdfNSError("Invalid view state"))
            }
            
            let bounds = currentSelection.bounds(for: currentPage)
            let boundsArray: [Double] = [
                bounds.origin.x,
                bounds.origin.y,
                bounds.size.width,
                bounds.size.height
            ]
            
            let storedAnnotation = StoredAnnotation(
                pageIndex: currentPage.pageRef?.pageNumber ?? 0,
                type: annotationTypeString(),
                color: currentAnnotationColor.toHex(),
                contents: currentAnnotationType == .note ? "Note" : nil,
                bounds: boundsArray,
                pdf: pdf
            )
            
            annotations.append(storedAnnotation)
            
            let pdfAnnotation = PDFAnnotation(bounds: bounds,
                                            forType: PDFAnnotationSubtype(rawValue: annotationTypeString()),
                                            withProperties: nil)
            pdfAnnotation.color = currentAnnotationColor
            pdfAnnotation.contents = currentAnnotationType == .note ? "Note" : nil
            
            currentPage.addAnnotation(pdfAnnotation)
            
            if let lastAnnotation = currentPage.annotations.last {
                lastAnnotations.append(lastAnnotation)
            }
            
            // Send snapshot instead of StoredAnnotation
            try await annotationService.saveAnnotation(storedAnnotation.snapshot, pdfID: pdf.persistentModelID)
            return nil
            
        } catch {
            return PDFError.annotationFailed(error)
        }
    }
    
    func removeAnnotation(_ annotation: PDFAnnotation) {
        guard let page = annotation.page else { return }
        
        page.removeAnnotation(annotation)
        
        let bounds = annotation.bounds
        if let storedAnnotation = annotations.first(where: { $0.bounds == [bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height] }) {
            modelContext.delete(storedAnnotation)
            annotations.removeAll { $0.id == storedAnnotation.id }
        }
    }
    
    func deleteSelectedAnnotations() {
        for id in selectedAnnotations {
            if let annotation = annotations.first(where: { $0.id == id }),
               let pdfAnnotation = pdfView?.currentPage?.annotations.first(where: { $0.bounds.array == annotation.bounds }) {
                removeAnnotation(pdfAnnotation)
            }
        }
        selectedAnnotations.removeAll()
    }
    
    // MARK: - Note Management
    func addNote() {
        guard let currentPage = pdfView?.currentPage,
              let pageNumber = currentPage.pageRef?.pageNumber else { return }
        
        let note = Note(
            title: newNoteTitle,
            content: newNoteContent,
            tags: newNoteTags,
            pageNumber: pageNumber
        )
        note.pdf = pdf
        
        modelContext.insert(note)
        notes.append(note)
        
        // Reset form
        resetNoteForm()
    }
    
    // MARK: - Bookmark Methods
    func addBookmark() {
        guard let currentPage = selectedPage else { return }
        let bookmark = PDFBookmark(
            pageIndex: currentPage.pageRef?.pageNumber ?? 0,
            pageLabel: currentPage.label ?? "",
            timestamp: Date()
        )
        bookmarks.append(bookmark)
    }
    
    func goToBookmark(_ bookmark: PDFBookmark) {
        guard let document = document,
              let page = document.page(at: bookmark.pageIndex) else { return }
        pdfView?.go(to: page)
    }
    
    // MARK: - Text Selection
    func copySelectedText() {
        guard let selection = pdfView?.currentSelection?.string else { return }
        let selectedText = selection
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
    }
    
    // MARK: - Private Methods
    private func setupInitialView() {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              let firstPage = document.page(at: 0) else { return }
        
        pdfView.autoScales = true
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = 0.25
        pdfView.go(to: PDFDestination(page: firstPage, at: NSPoint(x: 0, y: firstPage.bounds(for: .mediaBox).size.height)))
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        self.zoomLevel = pdfView.scaleFactor
    }
    
    internal func navigateToPage(_ pageIndex: Int) {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              let page = document.page(at: pageIndex) else { return }
        
        // Store horizontal scroll position
        let currentX = pdfView.enclosingScrollView?.documentVisibleRect.origin.x
        
        // Animate to new page
        isScrollingAnimated = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            let destination = PDFDestination(page: page, at: NSPoint(x: currentX ?? 0,
                                           y: page.bounds(for: .mediaBox).size.height))
            pdfView.go(to: destination)
        }, completionHandler: {
            self.isScrollingAnimated = false
        })
    }
    
    private func highlightCurrentSelection() {
        guard currentSearchResult > 0,
              currentSearchResult <= searchResults.count,
              let pdfView = pdfView else { return }
        
        let selection = searchResults[currentSearchResult - 1]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.scrollSelectionToVisible(nil)
        
        if let page = selection.pages.first {
            currentPage = pdfView.document?.index(for: page) ?? 0 + 1
        }
    }
    
    func loadInitialData() async {
        await loadAnnotations()
        await loadNotes()
    }
    
    private func loadAnnotations() async {
        do {
            // Pass persistentModelID instead of PDF object
            let snapshots = try await annotationService.loadAnnotations(forPDFWithID: pdf.persistentModelID)
            await MainActor.run {
                // Create new StoredAnnotations from snapshots on the main actor
                self.annotations = snapshots.map { snapshot in
                    StoredAnnotation(from: snapshot, pdf: self.pdf)
                }
            }
            await restoreAnnotations()
        } catch {
            print("Error loading annotations: \(error)")
        }
    }
    
    private func loadNotes() async {
        do {
            let descriptor = FetchDescriptor<Note>()
            let allNotes = try modelContext.fetch(descriptor)
            notes = allNotes.filter { $0.pdf?.persistentModelID == pdf.persistentModelID }
        } catch {
            print("Error loading notes: \(error)")
        }
    }
    
    @MainActor
    private func restoreAnnotations() async {
        guard let document = pdfView?.document else { return }
        
        for annotation in annotations {
            if let page = document.page(at: annotation.pageIndex) {
                //print("DEBUG: Restoring annotation on page \(annotation.pageIndex)")
                //print("DEBUG: Stored bounds: \(annotation.bounds)")
                //print("DEBUG: Page bounds: \(page.bounds(for: .mediaBox))")
                
                let pdfAnnotation = annotation.toPDFAnnotation()
                //print("DEBUG: Restored annotation bounds: \(pdfAnnotation.bounds)")
                page.addAnnotation(pdfAnnotation)
            }
        }
    }
    
    private func resetNoteForm() {
        newNoteTitle = ""
        newNoteContent = ""
        newNoteTags = []
        isAddingNote = false
    }
    
    private func annotationTypeString() -> String {
        switch currentAnnotationType {
        case .highlight: return "highlight"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .note: return "note"
        }
    }
    
    @MainActor
    func askQuestion(pageText: String) async {
        guard !currentQuestion.isEmpty else { return }
        
        isProcessingQuestion = true
        let question = currentQuestion
        currentQuestion = ""
        
        do {
            let answer = try await chatService.sendMessage(question, context: pageText)
            chatMessages.append((question: question, answer: answer))
        } catch {
            chatMessages.append((question: question, answer: "Error: \(error.localizedDescription)"))
        }
        
        isProcessingQuestion = false
    }
    
    nonisolated func asyncCleanup() {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }

    
    deinit {
        asyncCleanup()
    }

    @MainActor
    private func cleanup() {
        annotations.removeAll()
        notes.removeAll()
        document = nil
        searchResults.removeAll()
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func setupShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Command + H = Highlight
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "h" {
                self.currentAnnotationType = .highlight
                return nil
            }
            
            // Command + U = Underline
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "u" {
                self.currentAnnotationType = .underline
                return nil
            }
            
            // Command + S = Strikethrough
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "s" {
                self.currentAnnotationType = .strikethrough
                return nil
            }
            
            // Command + N = Note
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "n" {
                self.currentAnnotationType = .note
                return nil
            }
            
            // Command + Z = Undo
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" {
                self.undoLastAnnotation()
                return nil
            }
            
            // Command + Shift + Z = Redo
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "z" {
                self.redoAnnotation()
                return nil
            }
            
            return event
        }
    }
    
    func handlePinchGesture(scale: CGFloat) {
        let newZoom = zoomLevel * scale
        if newZoom >= minZoom && newZoom <= maxZoom {
            zoomLevel = newZoom
            pdfView?.scaleFactor = newZoom
        }
    }
    
    func undoLastAnnotation() {
        guard let lastAnnotation = lastAnnotations.popLast(),
              let page = lastAnnotation.page else { return }
        
        redoStack.append(lastAnnotation)
        page.removeAnnotation(lastAnnotation)
        if let storedAnnotation = annotations.last {
            modelContext.delete(storedAnnotation)
            annotations.removeLast()
        }
    }
    
    func redoAnnotation() {
        guard let annotationToRedo = redoStack.popLast(),
              let page = annotationToRedo.page else { return }
        
        page.addAnnotation(annotationToRedo)
        lastAnnotations.append(annotationToRedo)
        
        // Recreate stored annotation
        let bounds = annotationToRedo.bounds
        let storedAnnotation = StoredAnnotation(
            pageIndex: page.pageRef?.pageNumber ?? 0,
            type: annotationToRedo.type ?? "highlight",
            color: annotationToRedo.color.toHex(),
            contents: annotationToRedo.contents,
            bounds: bounds.array,
            pdf: pdf
        )
        
        annotations.append(storedAnnotation)
        Task {
            try await annotationService.saveAnnotation(storedAnnotation.snapshot, pdfID: pdf.persistentModelID)
        }
    }
    
    func filterAnnotations() {
        switch annotationFilter {
        case .all:
            filteredAnnotations = annotations
        case .highlights:
            filteredAnnotations = annotations.filter { $0.type == "highlight" }
        case .underlines:
            filteredAnnotations = annotations.filter { $0.type == "underline" }
        case .strikethrough:
            filteredAnnotations = annotations.filter { $0.type == "strikethrough" }
        case .notes:
            filteredAnnotations = annotations.filter { $0.type == "note" }
        case .category(let category):
            filteredAnnotations = annotations.filter { $0.category == category }
        case .tags(let tags):
            filteredAnnotations = annotations.filter { !Set($0.tags).isDisjoint(with: tags) }
        }
    }
    
    func selectAnnotation(_ annotation: PDFAnnotation) {
        selectedAnnotation = annotation
        isEditingAnnotation = true
    }
    
    func updateSelectedAnnotation(color: NSColor? = nil, contents: String? = nil) {
        guard let annotation = selectedAnnotation else { return }
        
        if let color = color {
            annotation.color = color
        }
        
        if let contents = contents {
            annotation.contents = contents
        }
        
        // Update stored annotation
        if let storedAnnotation = annotations.first(where: { $0.bounds == annotation.bounds.array }) {
            storedAnnotation.color = color?.toHex() ?? storedAnnotation.color
            storedAnnotation.contents = contents ?? storedAnnotation.contents
            Task {
                try await annotationService.saveAnnotation(storedAnnotation.snapshot, pdfID: pdf.persistentModelID)
            }
        }
    }
}
extension NSRect {
    var array: [Double] {
        [origin.x, origin.y, size.width, size.height]
    }
}

@MainActor
final class BookmarkManager: ObservableObject {
    @Published private(set) var bookmarks: [PDFBookmark] = []
    
    func toggleBookmark(for page: PDFPage) {
        // Bookmark logic here
        if let existingBookmark = bookmarks.first(where: { $0.pageIndex == page.pageRef?.pageNumber }) {
            bookmarks.removeAll { $0.pageIndex == existingBookmark.pageIndex }
        } else {
            let newBookmark = PDFBookmark(
                pageIndex: page.pageRef?.pageNumber ?? 0,
                pageLabel: page.label ?? "",
                timestamp: Date()
            )
            bookmarks.append(newBookmark)
        }
    }
    
    func goToBookmark(_ bookmark: PDFBookmark) {
        // Navigation logic here
    }
}

struct PDFBookmark: Identifiable {
    let id = UUID()
    let pageIndex: Int
    let pageLabel: String
    let timestamp: Date
}
