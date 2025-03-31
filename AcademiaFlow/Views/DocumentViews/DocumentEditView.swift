import SwiftUI
import SwiftData

@MainActor
struct DocumentEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: Document
    @Binding var isEditing: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    documentHeader
                    
                    documentContent
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height - 200)
                }
                .padding()
            }
        }
        .background(Color(.textBackgroundColor))
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
    
    private var documentContent: some View {
        VStack {
            if isEditing {
                TextEditor(text: $document.content)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .background(Color(.textBackgroundColor))
            } else {
                Text(document.content)
                    .font(.system(.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.textBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2)
        )
    }
}

#Preview("Document Edit") {
    NavigationStack {
        DocumentEditView(
            document: PreviewSampleData.shared.sampleDocument,
            isEditing: .constant(true)
        )
    }
    .modelContainer(PreviewSampleData.shared.container)
}
