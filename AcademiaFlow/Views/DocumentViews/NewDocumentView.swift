import SwiftUI
import SwiftData

struct NewDocumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var documentType: DocumentType = .paper
    @State private var citationStyle: CitationStyle = .apa
    @State private var template: DocumentTemplate = .default
    @State private var tags: Array<String> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                }
                
                Section {
                    HStack {
                        Text("Document Type")
                        Spacer()
                        Menu {
                            ForEach(DocumentType.allCases, id: \.self) { type in
                                Button {
                                    documentType = type
                                } label: {
                                    if documentType == type {
                                        Label(type.rawValue.capitalized, systemImage: "checkmark")
                                    } else {
                                        Text(type.rawValue.capitalized)
                                    }
                                }
                            }
                        } label: {
                            Text(documentType.rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Citation Style")
                        Spacer()
                        Menu {
                            ForEach(CitationStyle.allCases, id: \.self) { style in
                                Button {
                                    citationStyle = style
                                } label: {
                                    if citationStyle == style {
                                        Label(style.rawValue.uppercased(), systemImage: "checkmark")
                                    } else {
                                        Text(style.rawValue.uppercased())
                                    }
                                }
                            }
                        } label: {
                            Text(citationStyle.rawValue.uppercased())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Template") {
                    ForEach(DocumentTemplate.allCases, id: \.self) { template in
                        TemplateCard(template: template, isSelected: self.template == template)
                            .onTapGesture {
                                withAnimation {
                                    self.template = template
                                }
                            }
                    }
                }
                
                Section("Tags") {
                    TagEditorView(tags: $tags)
                }
            }
            .navigationTitle("New Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createDocument()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .formStyle(.grouped)
        }
    }
    
    private func createDocument() {
        let filePath = UUID().uuidString + ".rtf"
        let document = Document(
            title: title,
            documentType: documentType,
            tags: tags,
            citationStyle: citationStyle,
            template: template, filePath: filePath
        )
        modelContext.insert(document)
    }
}

struct TemplateCard: View {
    let template: DocumentTemplate
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(template.rawValue.capitalized)
                    .font(.headline)
                
                Text(templateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var templateDescription: String {
        switch template {
        case .default:
            return "Basic document structure"
        case .academic:
            return "Formal academic paper format"
        case .research:
            return "Research paper with methodology"
        case .custom:
            return "Custom template"
        }
    }
}

#Preview {
    NewDocumentView()
        .modelContainer(PreviewSampleData.shared.container)
}
