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
    @Environment(\.chatService) private var chatService: ChatService?

    @State private var selectedNavigation: NavigationType? = .documents
    @State private var selectedPDF: PDF?
    @State private var selectedDocument: Document?
    @State private var selectedReference: Reference?
    @State private var selectedNote: Note?
    @State private var container: ModelContainer?
    
    var body: some View {
        Group {
            if container != nil {
                ZStack {
                    NavigationSplitView {
                        List(NavigationType.allCases, selection: $selectedNavigation) { type in
                            NavigationLink(value: type) {
                                Label(type.title, systemImage: type.icon)
                            }
                        }
                        .navigationTitle("AcademiaFlow")
                        .onChange(of: selectedNavigation) { _, newValue in
                            // Reset selections when navigation changes
                            selectedPDF = nil
                            selectedDocument = nil
                            selectedReference = nil
                            selectedNote = nil
                        }
                    } content: {
                        if let selected = selectedNavigation {
                            selected.destinationView(
                                selectedPDF: $selectedPDF,
                                selectedDocument: $selectedDocument,
                                selectedReference: $selectedReference,
                                selectedNote: $selectedNote
                            )
                        } else {
                            Text("Select a section from the sidebar")
                                .foregroundStyle(.secondary)
                        }
                    } detail: {
                        if let selected = selectedNavigation {
                            selected.detailView(
                                modelContext: modelContext,
                                errorHandler: errorHandler,
                                chatService: chatService,
                                selectedPDF: $selectedPDF,
                                selectedDocument: $selectedDocument,
                                selectedReference: $selectedReference,
                                selectedNote: $selectedNote
                            )
                        } else {
                            Text("Select a section")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    FloatingChatButton(
                        selectedNavigation: $selectedNavigation,
                        selectedDocument: $selectedDocument,
                        selectedPDF: $selectedPDF,
                        selectedNote: $selectedNote,
                        selectedReference: $selectedReference
                    )
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
    func destinationView(
        selectedPDF: Binding<PDF?>,
        selectedDocument: Binding<Document?>,
        selectedReference: Binding<Reference?>,
        selectedNote: Binding<Note?>
    ) -> some View {
        switch self {
        case .documents:
            DocumentListView(selectedDocument: selectedDocument)
        case .pdfs:
            PDFListView(selectedPDF: selectedPDF)
        case .references:
            ReferenceListView(selectedReference: selectedReference)
        case .notes:
            NoteListView(selectedNote: selectedNote)
        }
    }
    
    @ViewBuilder
    func detailView(
        modelContext: ModelContext,
        errorHandler: ErrorHandler,
        chatService: ChatService?,
        selectedPDF: Binding<PDF?>,
        selectedDocument: Binding<Document?>,
        selectedReference: Binding<Reference?>,
        selectedNote: Binding<Note?>
    ) -> some View {
        switch self {
        case .documents:
            if let document = selectedDocument.wrappedValue {
                DocumentDetailView(document: document)
            } else {
                Text("Select a document")
                    .foregroundStyle(.secondary)
            }
        case .pdfs:
            if let pdf = selectedPDF.wrappedValue {
                PDFPreviewView(pdf: pdf, 
                               modelContext: modelContext, 
                               errorHandler: errorHandler, 
                               chatService: chatService)
                    .id(pdf.id)
            } else {
                Text("Select a PDF")
                    .foregroundStyle(.secondary)
            }
        case .references:
            if let reference = selectedReference.wrappedValue {
                ReferenceDetailView(reference: reference)
            } else {
                Text("Select a reference")
                    .foregroundStyle(.secondary)
            }
        case .notes:
            if let note = selectedNote.wrappedValue {
                NoteDetailView(note: note)
            } else {
                Text("Select a note")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
