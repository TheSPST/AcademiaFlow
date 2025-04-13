import SwiftUI
import SwiftData
import RichTextKit

@MainActor
class DocumentEditViewModel: ObservableObject {
    @Published var isEditingTitle = false
    @Published var titleText: String
    @Published var showTitleError = false
    let document: Document
    
    init(document: Document) {
        self.document = document
        self.titleText = document.title
    }
    
    func updateTitle() {
        let newTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle.isEmpty {
            showTitleError = true
            titleText = document.title
            return
        }
        document.title = newTitle
        document.updatedAt = Date()
        isEditingTitle = false
        showTitleError = false
    }
    
    func startEditingTitle() {
        titleText = document.title
        isEditingTitle = true
    }
    
    func cancelEditingTitle() {
        titleText = document.title
        isEditingTitle = false
        showTitleError = false
    }
}

@MainActor
struct DocumentEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: Document
    @Binding var isEditing: Bool
    @Binding var contentText: NSAttributedString
    @StateObject var context = RichTextContext()
    @StateObject private var viewModel: DocumentEditViewModel
    
    init(document: Document, isEditing: Binding<Bool>, contentText: Binding<NSAttributedString>) {
        self.document = document
        self._isEditing = isEditing
        self._contentText = contentText
        self._viewModel = StateObject(wrappedValue: DocumentEditViewModel(document: document))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    documentHeader
                    if isEditing {
                        RichTextEditor(text: $contentText, context: context)
                            .focusedValue(\.richTextContext, context)
                            .frame(minHeight: 500)
                    } else {
                        RichTextViewer(contentText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .inspector(isPresented: $isEditing) {
                    RichTextFormat.Sidebar(context: context)
#if os(macOS)
                        .inspectorColumnWidth(min: 200, ideal: 200, max: 315)
#endif
                }
                .frame(minWidth: 500, minHeight: 400)
                .focusedValue(\.richTextContext, context)
                .toolbarRole(.automatic)
                .richTextFormatSheetConfig(.init(colorPickers: colorPickers))
                .richTextFormatSidebarConfig(
                    .init(
                        colorPickers: colorPickers,
                        fontPicker: isMac
                    )
                )
                .richTextFormatToolbarConfig(.init(colorPickers: []))
                .padding()
            }
        }
        .background(Color(.textBackgroundColor))
        .focusedSceneValue(\.richTextContext, context)
        .alert("Invalid Title", isPresented: $viewModel.showTitleError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Document title cannot be empty.")
        }
    }
    
    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Group {
                if viewModel.isEditingTitle {
                    HStack {
                        TextField("Document Title", text: $viewModel.titleText)
                            .font(.system(size: 24, weight: .bold))
                            .textFieldStyle(.plain)
                            .onSubmit {
                                viewModel.updateTitle()
                            }
                        
                        Button {
                            viewModel.updateTitle()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            viewModel.cancelEditingTitle()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack {
                        Text(document.title)
                            .font(.system(size: 24, weight: .bold))
                        
                        if isEditing {
                            Button {
                                viewModel.startEditingTitle()
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Document Info
            HStack {
                Text(document.documentType.rawValue.capitalized)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .foregroundStyle(.secondary)
                
                Text(document.citationStyle.rawValue.uppercased())
                    .foregroundStyle(.secondary)
                
                if !document.tags.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    
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
            .font(.caption)
        }
    }
}

#Preview("Document Edit") {
    DocumentEditPreviewWrapper()
}

private struct DocumentEditPreviewWrapper: View {
    @State var dummyText = NSAttributedString(string: "This is a test preview text with some bold and italic styles.")

    var body: some View {
        NavigationStack {
            DocumentEditView(
                document: PreviewSampleData.shared.sampleDocument,
                isEditing: .constant(true),
                contentText: $dummyText
            )
        }
        .modelContainer(PreviewSampleData.shared.container)
    }
}
private extension DocumentEditView {

    var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    var colorPickers: [RichTextColor] {
        [.foreground, .background]
    }

    var formatToolbarEdge: VerticalEdge {
        isMac ? .top : .bottom
    }
}

