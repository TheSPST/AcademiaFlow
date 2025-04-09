import SwiftUI
import PDFKit
import SwiftData

/// ViewModel for handling PDF document viewing and annotation
@MainActor
protocol PDFViewModelProtocol: ObservableObject {
    var isLoading: Bool { get }
    var currentPage: Int { get set }
    var totalPages: Int { get }
    func loadPDF() async
    func addAnnotation()
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
@MainActor
protocol PDFAnnotatable {
    func addAnnotation()
    func removeAnnotation(_ annotation: PDFAnnotation)
}

/// Protocol for PDF navigation functionality
@MainActor
protocol PDFNavigatable {
    func goToNextPage()
    func goToPreviousPage()
    func navigateToPage(_ pageIndex: Int)
}

@MainActor
class PDFViewModel: ObservableObject, PDFViewModelProtocol, PDFSearchable, PDFAnnotatable, PDFNavigatable {
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
    
    // MARK: - Private Properties
    private var searchResults: [PDFSelection] = []
    private weak var pdfView: PDFView?
    private let pdf: PDF
    private let modelContext: ModelContext
    private var document: PDFDocument?
    private let chatService = ChatService()
    private var shortcutMonitor: Any?
    
    
    // MARK: - Types
    enum AnnotationType {
        case highlight
        case underline
        case strikethrough
        case note
    }
    
    // MARK: - Initialization
    init(pdf: PDF, modelContext: ModelContext) {
        self.pdf = pdf
        self.modelContext = modelContext
        
        Task { @MainActor in
            await self.loadInitialData()
            self.setupShortcuts()
        }
    }
    
    // MARK: - Public Methods
    func setPDFView(_ view: PDFView) {
        self.pdfView = view
    }
    
    func loadPDF() async {
        do {
            isLoading = true
            
            guard FileManager.default.fileExists(atPath: pdf.fileURL.path) else {
                throw PDFError.fileNotFound
            }
            
            guard let document = PDFDocument(url: pdf.fileURL) else {
                throw PDFError.invalidDocument
            }
            
            self.document = document
            pdfView?.document = document
            totalPages = document.pageCount
            
            setupInitialView()
            isLoading = false
            
        } catch {
            loadError = error
            isLoading = false
        }
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
        zoomLevel = min(zoomLevel * 1.25, 4.0)
        pdfView?.scaleFactor = zoomLevel
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.25, 0.25)
        pdfView?.scaleFactor = zoomLevel
    }
    
    func resetZoom() {
        zoomLevel = 1.0
        pdfView?.scaleFactor = zoomLevel
    }
    
    func fitToWidth() {
        guard let pdfView = pdfView else { return }
        zoomLevel = pdfView.scaleFactorForSizeToFit
        pdfView.scaleFactor = zoomLevel
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
    
    // MARK: - Annotation Methods
    func addAnnotation() {
        guard let pdfView = pdfView,
              let currentSelection = pdfView.currentSelection,
              let currentPage = pdfView.currentPage else { return }
        
        let bounds = currentSelection.bounds(for: currentPage)
        let boundsArray: [Double] = [bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height]
        
        let storedAnnotation = StoredAnnotation(
            pageIndex: currentPage.pageRef?.pageNumber ?? 0,
            type: annotationTypeString(),
            color: currentAnnotationColor.toHex(),
            contents: currentAnnotationType == .note ? "Note" : nil,
            bounds: boundsArray,
            pdf: pdf
        )
        modelContext.insert(storedAnnotation)
        annotations.append(storedAnnotation)
        let pdfAnnotation = storedAnnotation.toPDFAnnotation()
        currentPage.addAnnotation(pdfAnnotation)
        
        // Store for undo functionality
        if let lastAnnotation = currentPage.annotations.last {
            lastAnnotations.append(lastAnnotation)
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
        
        pdfView.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).size.height)))
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
            let descriptor = FetchDescriptor<StoredAnnotation>()
            let allAnnotations = try modelContext.fetch(descriptor)
            annotations = allAnnotations.filter { $0.pdf?.persistentModelID == pdf.persistentModelID }
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
    
    private func restoreAnnotations() async {
        guard let document = pdfView?.document else { return }
        
        for annotation in annotations {
            if let page = document.page(at: annotation.pageIndex) {
                page.addAnnotation(annotation.toPDFAnnotation())
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
            
            return event
        }
    }
    
    func undoLastAnnotation() {
        guard let lastAnnotation = lastAnnotations.popLast(),
              let page = lastAnnotation.page else { return }
        
        page.removeAnnotation(lastAnnotation)
        if let storedAnnotation = annotations.last {
            modelContext.delete(storedAnnotation)
            annotations.removeLast()
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
                await saveAnnotation()
            }
        }
    }
}

extension PDFViewModel {
    func saveAnnotation() async {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save annotation: \(error)")
        }
    }
    func restoreAnnotations() {
        guard let document = document else { return }
        
        // Clear existing annotations first
//        for pageIndex in 0..<document.pageCount {
//            if let page = document.page(at: pageIndex) {
//                page.annotations.removeAll()
//            }
//        }
        // Add stored annotations
        for annotation in annotations {
            if let page = document.page(at: annotation.pageIndex) {
                page.addAnnotation(annotation.toPDFAnnotation())
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

enum PDFError: LocalizedError {
    case fileNotFound
    case invalidDocument
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PDF file not found"
        case .invalidDocument:
            return "Could not create PDF document from file"
        }
    }
}
