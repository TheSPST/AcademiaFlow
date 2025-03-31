import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Protocols
protocol DocumentDisplayable {
    var title: String { get }
    var content: String { get }
}

protocol DocumentExportable {
    func export(as format: ExportFormat) async throws -> URL
}

// MARK: - View Models
@MainActor
final class DocumentDetailViewModel: ObservableObject {
    @Published var activeTab: Tab = .editor
    @Published var isEditing = false
    @Published var showingExportOptions = false
    @Published var selectedExportFormat: ExportFormat?
    @Published var exportedFile: ExportedFile?
    @Published var isExporting = false
    
    private let document: Document
    
    init(document: Document) {
        self.document = document
    }
    
    func setActiveTab(_ tab: Tab) {
        activeTab = tab
    }
    
    func toggleEditing() {
        isEditing.toggle()
    }
    
    func prepareExport(as format: ExportFormat) async {
        do {
            let snapshot = DocumentSnapshot(from: document)
            let service = DefaultDocumentExportService()
            let url = try await service.export(snapshot)
            let data = try Data(contentsOf: url)
            
            await MainActor.run {
                selectedExportFormat = format
                exportedFile = ExportedFile(data: data, format: format)
                showingExportOptions = false
                isExporting = true
            }
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Views
struct DocumentDetailView: View {
    @StateObject private var viewModel: DocumentDetailViewModel
    @Bindable private var document: Document
    
    init(document: Document) {
        self.document = document
        self._viewModel = StateObject(wrappedValue: DocumentDetailViewModel(document: document))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: Binding(
                get: { viewModel.activeTab },
                set: { viewModel.setActiveTab($0) }
            )) {
                DocumentEditView(document: document, isEditing: $viewModel.isEditing)
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
        .sheet(isPresented: $viewModel.showingExportOptions) {
            ExportOptionsSheet(
                document: document,
                isExporting: $viewModel.isExporting,
                exportedFile: $viewModel.exportedFile,
                selectedFormat: $viewModel.selectedExportFormat,
                onExport: { format in
                    Task {
                        await viewModel.prepareExport(as: format)
                    }
                }
            )
        }
        .fileExporter(
            isPresented: $viewModel.isExporting,
            document: viewModel.exportedFile,
            contentType: viewModel.selectedExportFormat?.contentType ?? .pdf,
            defaultFilename: document.title
        ) { result in
            switch result {
            case .success(let url):
                print("Exported successfully to \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
            viewModel.exportedFile = nil
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Picker("View Mode", selection: Binding(
                get: { viewModel.activeTab },
                set: { viewModel.setActiveTab($0) }
            )) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            if viewModel.activeTab == .editor {
                Button(viewModel.isEditing ? "Done" : "Edit") {
                    withAnimation {
                        viewModel.toggleEditing()
                    }
                }
            }
            
            DocumentControlsMenu(
                showingExportOptions: $viewModel.showingExportOptions,
                document: document
            )
        }
    }
}

// MARK: - Supporting Types
enum Tab: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case outline = "Outline"
    case preview = "Preview"
    
    var id: String { rawValue }
}

extension Tab: Hashable {}

// MARK: - Supporting Views
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
    let onExport: (ExportFormat) async -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            Task {
                                await onExport(format)
                            }
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
}

struct DocumentOutlineView: View {
    let document: Document
    
    var body: some View {
        Text("Outline View - Coming Soon")
            .foregroundColor(.secondary)
    }
}

// Make ExportedFile conform to Sendable since it's used in async context
struct ExportedFile: FileDocument, Sendable {
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

#Preview {
    NavigationStack {
        DocumentDetailView(document: PreviewSampleData.shared.sampleDocument)
    }
    .modelContainer(PreviewSampleData.shared.container)
}
