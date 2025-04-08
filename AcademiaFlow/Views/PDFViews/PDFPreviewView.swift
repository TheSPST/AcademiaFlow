import SwiftUI
import PDFKit
import AppKit

struct PDFPreviewView: View {
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isAddingNote = false
    @State private var selectedPage: PDFPage?
    @State private var zoomLevel: CGFloat = 1.0
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @Environment(\.modelContext) private var modelContext
    let pdf: PDF
    
    var body: some View {
        VStack(spacing: 0) {
            // PDF View
            PDFKitView(url: pdf.fileURL,
                      isLoading: $isLoading,
                      loadError: $loadError,
                      selectedPage: $selectedPage,
                      currentPage: $currentPage,
                      totalPages: $totalPages,
                      zoomLevel: $zoomLevel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    if let error = loadError {
                        ErrorView(error: error)
                    }
                }
            
            // Toolbar
            HStack {
                // Zoom controls
                HStack(spacing: 12) {
                    Button(action: zoomOut) {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                    
                    Button(action: resetZoom) {
                        Label("Actual Size", systemImage: "1.magnifyingglass")
                    }
                    
                    Button(action: zoomIn) {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    
                    Button(action: fitToWidth) {
                        Label("Fit to Width", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                    }
                }
                .labelStyle(.iconOnly)
                
                Divider()
                    .padding(.horizontal)
                
                // Page navigation
                HStack(spacing: 12) {
                    Button(action: goToPreviousPage) {
                        Label("Previous Page", systemImage: "chevron.left")
                    }
                    
                    Text("\(currentPage) of \(totalPages)")
                        .monospacedDigit()
                    
                    Button(action: goToNextPage) {
                        Label("Next Page", systemImage: "chevron.right")
                    }
                }
                
                Spacer()
                
                // Note adding button
                Button(action: { isAddingNote = true }) {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }
                .disabled(selectedPage == nil)
            }
            .frame(height: 44)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .sheet(isPresented: $isAddingNote) {
            if let page = selectedPage {
                AddNoteView(pdf: pdf, pageNumber: page.pageRef?.pageNumber ?? 0)
            }
        }
    }
    
    // MARK: - Actions
    private func zoomIn() {
        zoomLevel = min(zoomLevel * 1.25, 4.0)
    }
    
    private func zoomOut() {
        zoomLevel = max(zoomLevel / 1.25, 0.25)
    }
    
    private func resetZoom() {
        zoomLevel = 1.0
    }
    
    private func fitToWidth() {
        zoomLevel = -1.0 // Special value for fit to width
    }
    
    private func goToNextPage() {
        if currentPage < totalPages {
            currentPage += 1
        }
    }
    
    private func goToPreviousPage() {
        if currentPage > 1 {
            currentPage -= 1
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: Error?
    @Binding var selectedPage: PDFPage?
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var zoomLevel: CGFloat
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Add mouse click handler
        pdfView.allowedTouchTypes = .direct
        let gestureRecognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePageClick))
        pdfView.addGestureRecognizer(gestureRecognizer)
        context.coordinator.pdfView
        = pdfView
        
        loadPDF(pdfView)
        return pdfView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Handle zoom level changes
        if zoomLevel == -1.0 {
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            DispatchQueue.main.async {
                self.zoomLevel = pdfView.scaleFactor
            }
        } else {
            pdfView.scaleFactor = zoomLevel
        }
        
        // Handle page changes
        if let document = pdfView.document,
           let page = document.page(at: currentPage - 1) {
            pdfView.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).size.height)))
        }
        
        pdfView.needsDisplay = true
    }
    
    private func loadPDF(_ pdfView: PDFView) {
        Task { @MainActor in
            do {
                isLoading = true
                
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw NSError(domain: "PDFViewError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "PDF file not found at path: \(url.path)"])
                }
                
                guard let document = PDFDocument(url: url) else {
                    throw NSError(domain: "PDFViewError",
                                code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Could not create PDF document from file"])
                }
                
                pdfView.document = document
                totalPages = document.pageCount
                
                // Initial view setup
                pdfView.autoScales = true
                pdfView.maxScaleFactor = 4.0
                pdfView.minScaleFactor = 0.25
                
                if let firstPage = document.page(at: 0) {
                    pdfView.go(to: PDFDestination(page: firstPage, at: NSPoint(x: 0, y: firstPage.bounds(for: .mediaBox).size.height)))
                }
                
                // Set initial zoom to fit width
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                DispatchQueue.main.async {
                    self.zoomLevel = pdfView.scaleFactor
                }
                
                isLoading = false
                
            } catch {
                loadError = error
                isLoading = false
            }
        }
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        @MainActor
        @objc func handlePageClick(_ sender: Any?) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage else { return }
            
            parent.selectedPage = currentPage
            if let pageNum = currentPage.pageRef?.pageNumber {
                parent.currentPage = pageNum
            }
        }
    }
}

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let pdf: PDF
    let pageNumber: Int
    
    @State private var title = ""
    @State private var content = ""
    @State private var tags: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextEditor(text: $content)
                    .frame(height: 100)
                
                Section("Tags") {
                    TagEditorView(tags: $tags)
                }
            }
            .padding()
            .navigationTitle("Add Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(title.isEmpty && content.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func saveNote() {
        let note = Note(title: title,
                       content: content,
                       tags: tags,
                       pageNumber: pageNumber)
        note.pdf = pdf
        modelContext.insert(note)
    }
}

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Failed to load PDF")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
        PDFPreviewView(pdf: PDF(fileName: "sample.pdf", fileURL: url))
    } else {
        Text("No PDF available for preview")
    }
}
