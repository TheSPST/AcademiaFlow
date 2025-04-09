import SwiftUI
import SwiftData
import PDFKit
import AppKit

struct PDFPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var errorHandler: ErrorHandler
    @StateObject private var viewModel: PDFViewModel
    let pdf: PDF
    
    init(pdf: PDF, modelContext: ModelContext) {
        self.pdf = pdf
        // Create the view model with a StateObject wrapper
        let viewModel = PDFViewModel(pdf: pdf, modelContext: modelContext)
        self._viewModel = StateObject(wrappedValue: viewModel)
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
                    
                    Toggle(isOn: $viewModel.showChatView) {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right")
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
                                    .controlSize(.small)
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
            
            // Add chat sidebar
            if viewModel.showChatView {
                chatSidebar
                    .frame(width: 300)
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
        VStack(spacing: 8) {
            // Annotation Type Selection
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
                
                Button(action: {
                    Task { @MainActor in
                        if let error = viewModel.addAnnotation() {
                            errorHandler.handle(error)
                        }
                    }
                }) {
                    Label("Add Annotation", systemImage: "plus")
                }
                
                Button(action: viewModel.undoLastAnnotation) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.lastAnnotations.isEmpty)
                
                Button(action: { viewModel.copySelectedText() }) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }
            
            // Annotation Editor (when editing)
            if viewModel.isEditingAnnotation,
               let annotation = viewModel.selectedAnnotation {
                HStack {
                    ColorPicker("Color", selection: Binding(
                        get: { Color(annotation.color) },
                        set: { viewModel.updateSelectedAnnotation(color: NSColor($0)) }
                    ))
                    
                    if annotation.type == PDFAnnotationSubtype.text.rawValue {
                        TextField("Note", text: Binding(
                            get: { annotation.contents ?? "" },
                            set: { viewModel.updateSelectedAnnotation(contents: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("Done") {
                        viewModel.isEditingAnnotation = false
                        viewModel.selectedAnnotation = nil
                    }
                }
                .padding(.horizontal)
                .transition(.move(edge: .top))
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
                            viewModel.navigateToPage(index)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.currentPage - 1 == index ? Color.blue : Color.clear,
                                      lineWidth: 2)
                        )
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
    
    private var chatSidebar: some View {
        VStack {
            Text("Chat")
                .font(.headline)
                .padding()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.chatMessages, id: \.question) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Q: \(message.question)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(message.answer)
                                .font(.body)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Ask a question about this page...", text: $viewModel.currentQuestion)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isProcessingQuestion)
                
                Button {
                    // Get the current page text and pass it to askQuestion
                    if let selectedPage = viewModel.selectedPage {
                        Task {
                            await viewModel.askQuestion(pageText: selectedPage.string ?? "")
                        }
                    } else {
                        Task {
                            await viewModel.askQuestion(pageText: "")
                        }
                    }
                } label: {
                    if viewModel.isProcessingQuestion {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
                .disabled(viewModel.currentQuestion.isEmpty || viewModel.isProcessingQuestion)
            }
            .padding()
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
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .frame(maxHeight: 50)
    }
}
