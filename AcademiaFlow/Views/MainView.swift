import SwiftUI
import SwiftData

extension ModelContainer {
    static func create() throws -> ModelContainer {
        return try ModelContainer(
            for:
                Document.self,
                PDF.self,
                Reference.self,
                Note.self,
                StoredAnnotation.self,
            configurations: ModelConfiguration(
                schema: Schema([
                    Document.self,
                    PDF.self,
                    Reference.self,
                    Note.self,
                    StoredAnnotation.self
                ])
            )
        )
    }
}

@MainActor
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var errorHandler: ErrorHandler
    @State private var selectedNavigation: NavigationType? = .documents
    @State private var selectedPDF: PDF?
    @State private var container: ModelContainer?
    
    var body: some View {
        Group {
            if container != nil {
                NavigationSplitView {
                    List(NavigationType.allCases, selection: $selectedNavigation) { type in
                        NavigationLink(value: type) {
                            Label(type.title, systemImage: type.icon)
                        }
                    }
                    .navigationTitle("AcademiaFlow")
                } content: {
                    if let selected = selectedNavigation {
                        selected.destinationView(selectedPDF: $selectedPDF)
                    } else {
                        Text("Select a section from the sidebar")
                            .foregroundStyle(.secondary)
                    }
                } detail: {
                    if let pdf = selectedPDF {
                        PDFPreviewView(pdf: pdf, modelContext: modelContext)
                            .id(pdf.id) // Ensure view updates when PDF changes
                    } else {
                        Text("Select a PDF")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ProgressView()
                    .task {
                        do {
                            container = try ModelContainer.create()
                        } catch {
                            errorHandler.handle(DocumentError.loadFailure(error))
                        }
                    }
            }
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
    func destinationView(selectedPDF: Binding<PDF?>) -> some View {
        switch self {
        case .documents:
            DocumentListView()
        case .pdfs:
            PDFListView(selectedPDF: selectedPDF)
        case .references:
            ReferenceListView()
        case .notes:
            NoteListView()
        }
    }
}
