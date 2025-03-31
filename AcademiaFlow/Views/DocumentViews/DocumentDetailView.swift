import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentDetailView: View {
    @Bindable var document: Document
    @State private var activeTab: Tab = .editor
    @State private var isEditing = false
    @State private var showingExportOptions = false
    @State private var selectedExportFormat: ExportFormat?
    @State private var exportedFile: ExportedFile?
    @State private var isExporting = false
    
    enum Tab: String {
        case editor = "Editor"
        case outline = "Outline"
        case preview = "Preview"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $activeTab) {
                DocumentEditView(document: document, isEditing: $isEditing)
                    .tag(Tab.editor)
                DocumentOutlineView(document: document)
                    .tag(Tab.outline)
                
                DocumentPreviewView(document: document)
                    .tag(Tab.preview)
            }
            .tabViewStyle(.automatic)
        }
        .navigationTitle(document.title)
        .toolbar {
            toolbarItems
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsSheet(
                document: document,
                isExporting: $isExporting,
                exportedFile: $exportedFile,
                selectedFormat: $selectedExportFormat
            )
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportedFile,
            contentType: selectedExportFormat?.contentType ?? .pdf,
            defaultFilename: document.title
        ) { result in
            switch result {
            case .success(let url):
                print("Exported successfully to \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
            exportedFile = nil
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // View Mode Selector
            Picker("View Mode", selection: $activeTab) {
                Text(Tab.editor.rawValue).tag(Tab.editor)
                Text(Tab.outline.rawValue).tag(Tab.outline)
                Text(Tab.preview.rawValue).tag(Tab.preview)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            if activeTab == .editor {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation {
                        isEditing.toggle()
                    }
                }
            }
            
            DocumentControlsMenu(
                showingExportOptions: $showingExportOptions,
                document: document
            )
        }
    }
}

struct DocumentControlsMenu: View {
    @Binding var showingExportOptions: Bool
    let document: Document
    @State private var showingVersionHistory = false
    @State private var showingReferences = false
    
    var body: some View {
        Menu {
            Button {
                showingVersionHistory = true
            } label: {
                Label("Version History", systemImage: "clock")
            }
            
            Button {
                showingReferences = true
            } label: {
                Label("References", systemImage: "books.vertical")
            }
            
            Divider()
            
            Button {
                showingExportOptions = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .sheet(isPresented: $showingVersionHistory) {
            DocumentVersionsView(document: document)
        }
        .sheet(isPresented: $showingReferences) {
            DocumentReferencesView(document: document)
        }
    }
}

struct ExportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: Document
    @Binding var isExporting: Bool
    @Binding var exportedFile: ExportedFile?
    @Binding var selectedFormat: ExportFormat?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            exportDocument(as: format)
                        } label: {
                            HStack {
                                Text(format.displayName)
                                Spacer()
                                Image(systemName: "arrow.right.doc.on.clipboard")
                            }
                        }
                    }
                } header: {
                    Text("Choose Format")
                } footer: {
                    Text("Select a format to export your document")
                }
            }
            .navigationTitle("Export Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func exportDocument(as format: ExportFormat) {
        Task {
            do {
                let url = try await DocumentExporter.export(document, as: format)
                let data = try Data(contentsOf: url)
                selectedFormat = format
                exportedFile = ExportedFile(data: data, format: format)
                dismiss()
                isExporting = true
            } catch {
                print("Export failed: \(error.localizedDescription)")
            }
        }
    }
}

struct ExportedFile: FileDocument {
    let data: Data
    let format: ExportFormat
    
    static var readableContentTypes: [UTType] { [.pdf, .plainText] }
    
    init(data: Data, format: ExportFormat) {
        self.data = data
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        format = .pdf // Default format for reading
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DocumentOutlineView: View {
    let document: Document
    
    var body: some View {
        Text("Outline View - Coming Soon")
            .foregroundColor(.secondary)
    }
}

#Preview {
    NavigationStack {
        DocumentDetailView(document: PreviewSampleData.shared.sampleDocument)
    }
    .modelContainer(PreviewSampleData.shared.container)
}
