import SwiftUI
import SwiftData
import PDFKit
import AppKit

struct PDFPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: PDFViewModel
    let pdf: PDF
    
    init(pdf: PDF, modelContext: ModelContext) {
        self.pdf = pdf
        let viewMo = PDFViewModel(pdf: pdf, modelContext: modelContext)
        self._viewModel = StateObject(wrappedValue: viewMo)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Optional Thumbnail Sidebar
            if viewModel.showThumbnailView {
                thumbnailSidebar
                    .frame(width: 200)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    searchBar
                    Spacer()
                    
                    Toggle(isOn: $viewModel.showThumbnailView) {
                        Label("Thumbnails", systemImage: "sidebar.left")
                    }
                    .toggleStyle(.button)
                    
                    Toggle(isOn: $viewModel.showBookmarks) {
                        Label("Bookmarks", systemImage: "bookmark")
                    }
                    .toggleStyle(.button)
                    
                    Toggle(isOn: $viewModel.showNotes) {
                        Label("Notes", systemImage: "note.text")
                    }
                    .toggleStyle(.button)
                    Spacer()
                }
                // PDF View with Toolbar
                VStack(spacing: 0) {
                    // Annotation Toolbar
                    annotationToolbar
                    
                    // PDF View
                    PDFKitView(viewModel: viewModel)
                        .task {
                            await viewModel.loadInitialData()
                        }
                        .onDisappear(perform: {
                            Task {
                                await viewModel.saveAnnotation()
                            }
                        })
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
                }
                
                // Toolbar
                toolbar
            }
            
            // Bookmarks Sidebar
            if viewModel.showBookmarks {
                bookmarksSidebar
                    .frame(width: 250)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            
            // Notes Sidebar
            if viewModel.showNotes {
                notesSidebar
                    .frame(width: 250)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .sheet(isPresented: $viewModel.isAddingNote) {
            NavigationStack {
                Form {
                    TextField("Title", text: $viewModel.newNoteTitle)
                    TextEditor(text: $viewModel.newNoteContent)
                        .frame(height: 100)
                    
                    Section("Tags") {
                        TagEditorView(tags: $viewModel.newNoteTags)
                    }
                }
                .padding()
                .navigationTitle("Add Note")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            viewModel.isAddingNote = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.addNote()
                        }
                        .disabled(viewModel.newNoteTitle.isEmpty && viewModel.newNoteContent.isEmpty)
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 300)
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
    
    private var annotationToolbar: some View {
        HStack(spacing: 16) {
            Picker("Annotation Type", selection: $viewModel.currentAnnotationType) {
                Image(systemName: "highlighter").tag(PDFViewModel.AnnotationType.highlight)
                Image(systemName: "underline").tag(PDFViewModel.AnnotationType.underline)
                Image(systemName: "strikethrough").tag(PDFViewModel.AnnotationType.strikethrough)
                Image(systemName: "note.text").tag(PDFViewModel.AnnotationType.note)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            ColorPicker("Annotation Color", selection: Binding(
                get: { Color(viewModel.currentAnnotationColor) },
                set: { viewModel.currentAnnotationColor = NSColor($0) }
            ))
            
            Button(action: viewModel.addAnnotation) {
                Label("Add Annotation", systemImage: "plus")
            }
            
            Button(action: { viewModel.copySelectedText() }) {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var thumbnailSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(0..<viewModel.totalPages, id: \.self) { index in
                    ThumbnailView(pageIndex: index, viewModel: viewModel)
                        .frame(height: 150)
                        .cornerRadius(8)
                        .padding(.horizontal, 8)
                        .onTapGesture {
//                            $viewModel.thumbnailSelected(index)
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var bookmarksSidebar: some View {
        VStack {
            HStack {
                Text("Bookmarks")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.addBookmark()
                } label: {
                    Label("Add Bookmark", systemImage: "bookmark.fill")
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            List {
                ForEach(viewModel.bookmarks, id: \.timestamp) { bookmark in
                    BookmarkRow(bookmark: bookmark)
                        .onTapGesture {
                            viewModel.goToBookmark(bookmark)
                        }
                }
            }
        }
    }
    
    private var notesSidebar: some View {
        VStack {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.isAddingNote = true }) {
                    Label("Add Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            List {
                ForEach(viewModel.notes) { note in
                    VStack(alignment: .leading) {
                        Text(note.title)
                            .font(.headline)
                        Text(note.content)
                            .lineLimit(2)
                            .font(.body)
                            .foregroundColor(.secondary)
                        if !note.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(note.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
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

struct ThumbnailView: View {
    let pageIndex: Int
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
        // Implement thumbnail rendering using PDFKit
        Color.gray.opacity(0.2)
    }
}

struct BookmarkRow: View {
    let bookmark: PDFBookmark
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Page \(bookmark.pageLabel)")
                    .font(.headline)
                Text(bookmark.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "bookmark.fill")
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

//#Preview {
//    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
////        PDFPreviewView(pdf: PDF(fileName: "sample.pdf", fileURL: url), modelContext: ModelContext())
//    } else {
//        Text("No PDF available for preview")
//    }
//}
