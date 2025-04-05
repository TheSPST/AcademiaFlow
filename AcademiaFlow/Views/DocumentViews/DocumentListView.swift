import SwiftUI
import SwiftData
struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.updatedAt, order: .reverse) private var documents: [Document]
    @State private var showingNewDocument = false
    @State private var searchText = ""
    @State private var selectedDocument: Document?
    @State private var showingSortMenu = false
    @State private var sortOption: SortOption = .modified
    enum SortOption {
        case modified, created, title, type
        
        var label: String {
            switch self {
            case .modified: return "Last Modified"
            case .created: return "Date Created"
            case .title: return "Title"
            case .type: return "Document Type"
            }
        }
    }
    
    var filteredAndSortedDocuments: [Document] {
        let filtered = searchText.isEmpty ? documents : documents.filter { document in
            document.title.localizedCaseInsensitiveContains(searchText) ||
            document.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered.sorted { doc1, doc2 in
            switch sortOption {
            case .modified:
                return doc1.updatedAt > doc2.updatedAt
            case .created:
                return doc1.createdAt > doc2.createdAt
            case .title:
                return doc1.title < doc2.title
            case .type:
                return doc1.documentType.rawValue < doc2.documentType.rawValue
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredAndSortedDocuments) { document in
                NavigationLink(value: document) {
                    DocumentRow(document: document)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        duplicateDocument(document)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteDocument(document)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    DocumentContextMenu(document: document,
                                     onDuplicate: { duplicateDocument(document) },
                                     onDelete: { deleteDocument(document) })
                }
            }
        }
        .navigationTitle("Documents")
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document)
                .id(document.id)
        }
        .searchable(text: $searchText, prompt: "Search documents")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        Text("Last Modified").tag(SortOption.modified)
                        Text("Date Created").tag(SortOption.created)
                        Text("Title").tag(SortOption.title)
                        Text("Type").tag(SortOption.type)
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                
                Button(action: { showingNewDocument = true }) {
                    Label("New Document", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewDocument) {
            NewDocumentView()
                .interactiveDismissDisabled()
        }
        .animation(.default, value: sortOption)
        .animation(.default, value: searchText)
    }
    
    private func duplicateDocument(_ document: Document) {
        let duplicate = Document(
            title: document.title + " (Copy)",
            content: document.content,
            documentType: document.documentType,
            tags: document.tags,
            citationStyle: document.citationStyle,
            template: document.template, filePath: document.filePath
        )
        modelContext.insert(duplicate)
    }
    
    private func deleteDocument(_ document: Document) {
        withAnimation {
            modelContext.delete(document)
        }
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.title)
                .font(.headline)
            
            Text("\(document.documentType.rawValue.capitalized) • \(document.citationStyle.rawValue.uppercased())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Last modified: \(document.updatedAt.formatted())")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if !document.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(document.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DocumentContextMenu: View {
    let document: Document
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onDuplicate()
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview("Document List") {
    NavigationStack {
        DocumentListView()
    }
    .modelContainer(PreviewSampleData.shared.container)
}

#Preview("Document Row") {
    DocumentRow(document: PreviewSampleData.shared.sampleDocument)
        .padding()
}
