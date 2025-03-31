import SwiftUI
import SwiftData

struct ReferenceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var references: [Reference]
    
    var body: some View {
        List {
            ForEach(references) { reference in
                Text(reference.title)
            }
        }
        .navigationTitle("References")
    }
}