import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Protocols
protocol DocumentExportable {
    func export(as format: ExportFormat) async throws -> URL
}

// MARK: - View Models
@MainActor
class DocumentDetailViewModel: ObservableObject {
    @Published var activeTab: Tab = .editor
    @Published var isEditing = false
    @Published var showingExportOptions = false
    @Published var showingVersionHistory = false
    @Published var showingReferences = false
    @Published var selectedExportFormat: ExportFormat?
    @Published var exportedFile: ExportedFile?
    @Published var isExporting = false
    @Published var exportError: ExportError?
    @Published var showingErrorAlert = false
    @Published var exportProgress: Double?
    @Published var contentText = NSAttributedString()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? nil
    private let document: Document
    init(document: Document) {
        self.document = document
        self.readAttributedStringToRTF()
    }
    
    func setActiveTab(_ tab: Tab) {
        activeTab = tab
    }
    
    func toggleEditing() {
        defer {
            if !isEditing {
                saveAttributedStringToRTF(contentText)
            }
        }
        isEditing.toggle()
    }
    
    func prepareExport(as format: ExportFormat) async {
        do {
            exportProgress = 0.1
            let snapshot = DocumentSnapshot(from: document)
            let service = DefaultDocumentExportService()
            
            exportProgress = 0.3
            let url = try await service.export(snapshot)
            
            exportProgress = 0.7
            let data = try Data(contentsOf: url)
            
            await MainActor.run {
                selectedExportFormat = format
                exportedFile = ExportedFile(data: data, format: format)
                showingExportOptions = false
                isExporting = true
                exportProgress = 1.0
            }
            
        } catch let error as ExportError {
            await MainActor.run {
                exportError = error
                showingErrorAlert = true
                exportProgress = nil
            }
        } catch {
            await MainActor.run {
                exportError = .conversionFailed
                showingErrorAlert = true
                exportProgress = nil
            }
        }
    }
    
    private func readAttributedStringToRTF() {
        
        guard let fileURL = documentsDirectory?.appendingPathComponent(document.filePath) else { print("❌ Cannot access documents directory")
            self.contentText = NSAttributedString(string: "This is demo Please delete this and write here")
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedAttributedString = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            self.contentText = loadedAttributedString
        } catch let error {
            print("❌ Failed to read RTF: \(error.localizedDescription)")
            self.contentText = NSAttributedString(string: "This is demo Please delete this and write here")
            return
        }
    }
    private func saveAttributedStringToRTF(_ attributedString: NSAttributedString) {
        guard let fileURL = documentsDirectory?.appendingPathComponent(document.filePath) else { print("❌ Cannot access documents directory")
            return
        }
        do {
            let rtfData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            
            try rtfData.write(to: fileURL)
            print("✅ RTF saved to: \(fileURL.path)")
        } catch {
            print("❌ Failed to save RTF: \(error.localizedDescription)")
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
                DocumentEditView(document: document, isEditing: $viewModel.isEditing, contentText: $viewModel.contentText)
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
            ExportOptionsView(viewModel: viewModel)
        }
        .fileExporter(
            isPresented: $viewModel.isExporting,
            document: viewModel.exportedFile,
            contentType: viewModel.selectedExportFormat?.contentType ?? .pdf,
            defaultFilename: "\(document.title).\(viewModel.selectedExportFormat?.fileExtension ?? "pdf")"
        ) { result in
            switch result {
            case .success(let url):
                print("Exported successfully to \(url)")
            case .failure:
                viewModel.exportError = .fileCreationFailed
                viewModel.showingErrorAlert = true
            }
            viewModel.exportedFile = nil
            viewModel.exportProgress = nil
        }
        .alert("Export Error",
               isPresented: $viewModel.showingErrorAlert,
               presenting: viewModel.exportError) { error in
            Button("OK") {
                viewModel.exportError = nil
                viewModel.exportProgress = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onAppear {
            print("🪵 Loaded DocumentDetailView for: \(document.title)")
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
            Button {
                viewModel.showingExportOptions = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        // 💡 Add the editor toolbar ONLY when on the editor tab
        if viewModel.activeTab == .editor {
            DocumentEditView(
                document: document,
                isEditing: $viewModel.isEditing,
                contentText: $viewModel.contentText
            ).documentToolbar($viewModel.isEditing)
        }
    }
}

// MARK: - File Type
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

// MARK: - Export Options View
private struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DocumentDetailViewModel
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            debugPrint("format", format.displayName)
                            Task {
                                await viewModel.prepareExport(as: format)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Label(format.displayName, systemImage: format.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
// MARK: - Tab
enum Tab: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case outline = "Outline"
    case preview = "Preview"
    
    var id: String { rawValue }
}

extension Tab: Hashable {}

#Preview {
    NavigationStack {
        DocumentDetailView(document: PreviewSampleData.shared.sampleDocument)
    }
    .modelContainer(PreviewSampleData.shared.container)
}
