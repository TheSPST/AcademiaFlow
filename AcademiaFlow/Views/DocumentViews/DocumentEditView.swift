import SwiftUI
import SwiftData
import RichTextKit
@MainActor
struct DocumentEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: Document
    @Binding var isEditing: Bool
    @Binding var contentText: NSAttributedString
    @StateObject var context = RichTextContext()

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
                //                .viewDebug()
                .padding()
            }
        }
        .background(Color(.textBackgroundColor))
        .focusedSceneValue(\.richTextContext, context) // <– REQUIRED for commands to work
//        .commands {
//            RichTextCommands() // <– This adds undo/redo/copy/paste/cut etc
//        }
    }
    
    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            if isEditing {
                TextField("Document Title", text: $document.title)
                    .font(.system(size: 24, weight: .bold))
                    .textFieldStyle(.plain)
            } else {
                Text(document.title)
                    .font(.system(size: 24, weight: .bold))
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
extension DocumentEditView {
    @ToolbarContentBuilder
    func documentToolbar(_ isPresented: Binding<Bool>) -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Toggle(isOn: isPresented) {
                Image.richTextFormatBrush
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}
