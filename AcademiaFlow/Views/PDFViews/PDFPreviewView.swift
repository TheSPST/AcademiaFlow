import SwiftUI
import PDFKit
import AppKit

struct PDFPreviewView: View {
    @StateObject private var viewModel: PDFViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingNote = false
    
    let pdf: PDF
    
    init(pdf: PDF) {
        self.pdf = pdf
        self._viewModel = StateObject(wrappedValue: PDFViewModel(pdf: pdf))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // PDF View
            PDFKitView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    if let error = viewModel.loadError {
                        ErrorView(error: error)
                    }
                }
            
            // Toolbar
            toolbar
        }
        .sheet(isPresented: $isAddingNote) {
            if let page = viewModel.selectedPage {
                AddNoteView(pdf: pdf, pageNumber: page.pageRef?.pageNumber ?? 0)
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search in PDF", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.searchText) { oldValue, newValue in
                        viewModel.performSearch()
                    }
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            Spacer()
            if viewModel.isSearching {
                HStack(spacing: 8) {
                    Text("\(viewModel.currentSearchResult) of \(viewModel.totalSearchResults)")
                        .monospacedDigit()
                    
                    Button(action: viewModel.previousSearchResult) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(viewModel.totalSearchResults == 0)
                    
                    Button(action: viewModel.nextSearchResult) {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(viewModel.totalSearchResults == 0)
                }
            }
        }
        .padding()
    }
    
    private var toolbar: some View {
        HStack {
            // Zoom controls
            HStack(spacing: 12) {
                Button(action: viewModel.zoomOut) {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                
                Button(action: viewModel.resetZoom) {
                    Label("Actual Size", systemImage: "1.magnifyingglass")
                }
                
                Button(action: viewModel.zoomIn) {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
                
                Button(action: viewModel.fitToWidth) {
                    Label("Fit to Width", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
            }
            .labelStyle(.iconOnly)
            
            Divider()
                .padding(.horizontal)
            
            // Page navigation
            HStack(spacing: 12) {
                Button(action: viewModel.goToPreviousPage) {
                    Label("Previous Page", systemImage: "chevron.left")
                }
                
                Text("\(viewModel.currentPage) of \(viewModel.totalPages)")
                    .monospacedDigit()
                
                Button(action: viewModel.goToNextPage) {
                    Label("Next Page", systemImage: "chevron.right")
                }
            }
            
            Spacer()
            
            // Note adding button
            Button(action: { isAddingNote = true }) {
                Label("Add Note", systemImage: "note.text.badge.plus")
            }
            .disabled(viewModel.selectedPage == nil)
        }
        .frame(height: 44)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PDFKitView: NSViewRepresentable {
    @ObservedObject var viewModel: PDFViewModel
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        let gestureRecognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePageClick))
        pdfView.addGestureRecognizer(gestureRecognizer)
        
        viewModel.setPDFView(pdfView)
        Task {
            await viewModel.loadPDF()
        }
        
        return pdfView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.scaleFactor = viewModel.zoomLevel
        
        if let document = pdfView.document,
           let page = document.page(at: viewModel.currentPage - 1) {
            pdfView.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).size.height)))
        }
    }
    
    class Coordinator: NSObject {
        private let viewModel: PDFViewModel
        
        init(viewModel: PDFViewModel) {
            self.viewModel = viewModel
        }
        
        @MainActor @objc func handlePageClick() {
            viewModel.handlePageClick()
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
