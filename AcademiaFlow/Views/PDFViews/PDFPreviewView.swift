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
        let viewModel = PDFViewModel(pdf: pdf, modelContext: modelContext)
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if viewModel.showThumbnailView {
                PDFThumbnailSidebar(viewModel: viewModel)
                    .frame(width: 200)
            }
            
            VStack(spacing: 0) {
                PDFToolbar(viewModel: viewModel)
                PDFContentView(viewModel: viewModel, errorHandler: errorHandler)
            }
            
            PDFSidebarStack(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isAddingNote) {
            AddNoteSheet(viewModel: viewModel)
        }
    }
}

private struct PDFToolbar: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
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

private struct PDFContentView: View {
    @ObservedObject var viewModel: PDFViewModel
    let errorHandler: ErrorHandler
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            // Annotation Toolbar
            PDFAnnotationToolbar(viewModel: viewModel, errorHandler: errorHandler)
            
            // PDF View
            PDFKitView(viewModel: viewModel)
                .task {
                    await viewModel.loadInitialData()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if viewModel.isLoading {
                        LoadingView(message: "Loading PDF...")
                    }
                    if let error = viewModel.loadError {
                        ErrorView(error: error)
                    }
                }
        }
    }
    
    private var searchBar: some View {
        HStack {
            SearchField(
                text: $viewModel.searchText,
                isSearching: viewModel.isSearching,
                currentResult: viewModel.currentSearchResult,
                totalResults: viewModel.totalSearchResults,
                onSearch: viewModel.performSearch,
                onPrevious: viewModel.previousSearchResult,
                onNext: viewModel.nextSearchResult
            )
            
            Spacer()
            
            ViewToggleButtons(viewModel: viewModel)
        }
        .padding()
    }
}

private struct PDFAnnotationToolbar: View {
    @ObservedObject var viewModel: PDFViewModel
    let errorHandler: ErrorHandler
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                AnnotationTypePicker(selection: $viewModel.currentAnnotationType)
                
                AnnotationColorPicker(color: Binding(
                    get: { Color(viewModel.currentAnnotationColor) },
                    set: { viewModel.currentAnnotationColor = NSColor($0) }
                ))
                
                Button(action: {
                    Task {
                        if let error = await viewModel.addAnnotation() {
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
                
                Button(action: viewModel.copySelectedText) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }
            
            if viewModel.isEditingAnnotation,
               let annotation = viewModel.selectedAnnotation {
                AnnotationEditor(
                    annotation: annotation,
                    onUpdate: viewModel.updateSelectedAnnotation,
                    onDone: {
                        viewModel.isEditingAnnotation = false
                        viewModel.selectedAnnotation = nil
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PDFThumbnailSidebar: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PDFBookmarksSidebar: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PDFNotesSidebar: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PDFChatSidebar: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct AddNoteSheet: View {
    @ObservedObject var viewModel: PDFViewModel
    
    var body: some View {
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
