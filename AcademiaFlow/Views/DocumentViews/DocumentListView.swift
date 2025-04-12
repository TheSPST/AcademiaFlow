// Optimize imports
import SwiftUI
import SwiftData

// Remove preview for production builds
#if DEBUG
import Foundation
#endif

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.updatedAt, order: .reverse) private var documents: [Document]
    @State private var showingNewDocument = false
    @State private var searchText = ""
    @State private var selectedDocument: Document?
    @State private var sortOption: SortOption = .modified
    
    var body: some View {
        GenericListView(
            searchText: $searchText,
            sortOption: $sortOption,
            items: documents,
            title: "Documents",
            rowContent: { document in
                NavigationLink(value: document) {
                    ItemRowView(
                        item: document,
                        subtitle: "\(document.documentType.rawValue.capitalized) • \(document.citationStyle.rawValue.uppercased())",
                        metadata: "Last modified: \(document.displayTimestamp.formatted())"
                    )
                }
            },
            onDelete: deleteDocument,
            onDuplicate: duplicateDocument
        )
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document)
                .id(document.id)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                SortByMenuView(sortOption: $sortOption)
                Button(action: { showingNewDocument = true }) {
                    Label("New Document", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewDocument) {
            NewDocumentView()
                .interactiveDismissDisabled()
        }
    }
    
    private func duplicateDocument(_ document: Document) {
        let duplicate = Document(
            title: document.title + " (Copy)",
            content: document.content,
            documentType: document.documentType,
            tags: document.tags,
            citationStyle: document.citationStyle,
            template: document.template,
            filePath: document.filePath
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

#if DEBUG
struct DocumentListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DocumentListView()
        }
        .modelContainer(PreviewSampleData.shared.container)
    }
}

struct DocumentRow_Previews: PreviewProvider {
    static var previews: some View {
        DocumentRow(document: PreviewSampleData.shared.sampleDocument)
            .padding()
    }
}
#endif
