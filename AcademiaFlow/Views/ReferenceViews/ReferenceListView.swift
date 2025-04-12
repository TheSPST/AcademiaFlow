import SwiftUI
import SwiftData

struct ReferenceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var references: [Reference]
    @Binding var selectedReference: Reference?
    @State private var searchText = ""
    @State private var sortOption: SortOption = .modified
    
    var body: some View {
        GenericListView(
            searchText: $searchText,
            sortOption: $sortOption,
            items: references,
            title: "References",
            rowContent: { reference in
                Button {
                    selectedReference = reference
                } label: {
                    ItemRowView(
                        item: reference,
                        subtitle: reference.authors.joined(separator: ", "),
                        metadata: reference.year.map { "Year: \($0)" }
                    )
                }
                .buttonStyle(.plain)
                .background(selectedReference?.id == reference.id ? Color.accentColor.opacity(0.1) : Color.clear)
            },
            onDelete: deleteReference,
            onDuplicate: nil
        )
        .onChange(of: references) { _, newReferences in
            if selectedReference == nil && !newReferences.isEmpty {
                selectedReference = newReferences[0]
            }
        }
        .onAppear {
            if selectedReference == nil && !references.isEmpty {
                selectedReference = references[0]
            }
            // Add some sample references if none exist
            if references.isEmpty {
                addSampleReferences()
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: addSampleReference) {
                    Label("Add Reference", systemImage: "plus")
                }
            }
        }
    }
    
    private func deleteReference(_ reference: Reference) {
        modelContext.delete(reference)
    }
    
    private func addSampleReference() {
        let reference = Reference(
            title: "Sample Reference \(Date().formatted())",
            authors: ["Author One", "Author Two"],
            year: 2025,
            doi: "10.1234/sample",
            url: URL(string: "https://example.com"),
            publisher: "Sample Publisher",
            journal: "Sample Journal",
            abstract: "This is a sample reference abstract for testing purposes."
        )
        modelContext.insert(reference)
    }
    
    private func addSampleReferences() {
        // Add a few sample references
        let references = [
            Reference(
                title: "SwiftUI and Data Flow",
                authors: ["John Doe", "Jane Smith"],
                year: 2025,
                doi: "10.1234/swiftui",
                url: URL(string: "https://example.com/swiftui"),
                publisher: "Tech Publishing",
                journal: "Swift Journal",
                abstract: "A comprehensive study of data flow in SwiftUI applications."
            ),
            Reference(
                title: "Modern iOS Architecture",
                authors: ["Alice Johnson"],
                year: 2024,
                doi: "10.1234/ios-arch",
                url: URL(string: "https://example.com/ios"),
                publisher: "iOS Press",
                journal: "iOS Development Journal",
                abstract: "Exploring modern architectural patterns in iOS development."
            )
        ]
        
        references.forEach { modelContext.insert($0) }
    }
}
