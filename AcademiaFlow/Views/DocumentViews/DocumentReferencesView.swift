import SwiftUI
import SwiftData

struct DocumentReferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: Document
    @Query private var allReferences: [Reference]
    @State private var showingNewReference = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Document References") {
                    ForEach(document.references) { reference in
                        ReferenceRow(reference: reference)
                    }
                    .onDelete(perform: removeReferences)
                }
                
                Section("Available References") {
                    ForEach(allReferences.filter { !document.references.contains($0) }) { reference in
                        ReferenceRow(reference: reference)
                            .swipeActions {
                                Button("Add") {
                                    document.references.append(reference)
                                }
                                .tint(.green)
                            }
                    }
                }
            }
            .navigationTitle("References")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewReference = true }) {
                        Label("Add Reference", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewReference) {
//                NewReferenceView()
            }
        }
    }
    
    private func removeReferences(at offsets: IndexSet) {
        for index in offsets {
            document.references.remove(at: index)
        }
    }
}

struct ReferenceRow: View {
    let reference: Reference
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(reference.title)
                .font(.headline)
            
            if !reference.authors.isEmpty {
                Text(reference.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let year = reference.year {
                Text("\(year)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
