import SwiftUI
import SwiftData

@MainActor
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNavigation: NavigationType? = .documents
    
    var body: some View {
        NavigationSplitView {
            List(NavigationType.allCases, selection: $selectedNavigation) { type in
                NavigationLink(value: type) {
                    Label(type.title, systemImage: type.icon)
                }
            }
            .navigationTitle("AcademiaFlow")
        } content: {
            if let selected = selectedNavigation {
                selected.destinationView
            } else {
                Text("Select a section from the sidebar")
                    .foregroundStyle(.secondary)
            }
        } detail: {
            Text("Select an item")
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
enum NavigationType: String, CaseIterable, @preconcurrency Identifiable {
    case documents
    case pdfs
    case references
    case notes
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .documents: return "Documents"
        case .pdfs: return "PDFs"
        case .references: return "References"
        case .notes: return "Notes"
        }
    }
    
    var icon: String {
        switch self {
        case .documents: return "doc.text"
        case .pdfs: return "doc.richtext"
        case .references: return "books.vertical"
        case .notes: return "note.text"
        }
    }
    
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .documents:
            DocumentListView()
        case .pdfs:
            PDFListView()
        case .references:
            ReferenceListView()
        case .notes:
            NoteListView()
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Document.self, PDF.self, Reference.self, Note.self, configurations: config)
        return MainView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview container")
    }
}
