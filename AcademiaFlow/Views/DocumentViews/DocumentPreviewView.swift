import SwiftUI
import SwiftData

@MainActor
class DocumentPreviewViewModel: ObservableObject {
    @Published var formattedContent: NSAttributedString = NSAttributedString()
    @Published var isLoading = true
    let document: Document
    
    init(document: Document) {
        self.document = document
        Task {
            await loadContent()
        }
    }
    
    func loadContent() async {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Cannot access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(document.filePath)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedAttributedString = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            await MainActor.run {
                self.formattedContent = loadedAttributedString
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to read RTF: \(error.localizedDescription)")
            await MainActor.run {
                self.formattedContent = NSAttributedString(string: document.content)
                self.isLoading = false
            }
        }
    }
}



struct DocumentPreviewView: View {
    let document: Document
    @StateObject private var viewModel: DocumentPreviewViewModel
    @State private var selectedFormat: PreviewFormat = .formatted
    
    init(document: Document) {
            self.document = document
            self._viewModel = StateObject(wrappedValue: DocumentPreviewViewModel(document: document))
    }
    
    enum PreviewFormat {
        case formatted
        case plain
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Format selector
            Picker("Format", selection: $selectedFormat) {
                Text("Formatted").tag(PreviewFormat.formatted)
                Text("Plain").tag(PreviewFormat.plain)
            }
            .pickerStyle(.segmented)
            .padding()
            
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedFormat == .formatted {
                    FormattedDocumentView(document: document, attributedContent: viewModel.formattedContent)
                } else {
                    PlainDocumentView(document: document)
                }
            }
        }
    }
}

struct FormattedDocumentView: View {
    let document: Document
    let attributedContent: NSAttributedString
    var body: some View {
        VStack(spacing: 24) {
            // Title Section
            VStack(spacing: 16) {
                Text(document.title)
                    .font(.system(.title, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                if !document.tags.isEmpty {
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
            .frame(maxWidth: .infinity)
            .padding(.bottom)
            
            AttributedContentView(content: attributedContent)
                .padding(.horizontal)
            
            // References Section
            if !document.references.isEmpty {
                ReferencesSection(references: document.references, style: document.citationStyle)
            }
        }
        .padding()
        .frame(maxWidth: 800)
    }
}

struct PlainDocumentView: View {
    let document: Document
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(document.title)
                .font(.title)
            
            Text(document.content)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: 800)
    }
}
struct AttributedContentView: NSViewRepresentable {
    let content: NSAttributedString
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainer?.lineFragmentPadding = 0
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.textStorage?.setAttributedString(content)
    }
}


struct FormattedSection: View {
    let section: DocumentSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !section.title.isEmpty {
                Text(section.title)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
            }
            
            Text(section.content)
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
        }
        .padding(.vertical, 8)
    }
}

struct ReferencesSection: View {
    let references: [Reference]
    let style: CitationStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("References")
                .font(.system(.title2, design: .serif))
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(references) { reference in
                    Text(formatReference(reference))
                        .font(.system(.body, design: .serif))
                        .lineSpacing(4)
                }
            }
        }
    }
    
    private func formatReference(_ reference: Reference) -> String {
        switch style {
        case .apa:
            return formatAPAStyle(reference)
        case .mla:
            return formatMLAStyle(reference)
        case .chicago:
            return formatChicagoStyle(reference)
        case .harvard:
            return formatHarvardStyle(reference)
        }
    }
    
    private func formatAPAStyle(_ reference: Reference) -> String {
        let authors = reference.authors.joined(separator: ", ")
        let year = reference.year.map { "(\($0))" } ?? ""
        let title = reference.title
        let journal = reference.journal.map { ". \($0)" } ?? ""
        let publisher = reference.publisher.map { ". \($0)" } ?? ""
        
        return "\(authors) \(year). \(title)\(journal)\(publisher)."
    }
    
    // Add other citation style formatters as needed...
    private func formatMLAStyle(_ reference: Reference) -> String {
        // TODO: Implement MLA style
        return formatAPAStyle(reference)
    }
    
    private func formatChicagoStyle(_ reference: Reference) -> String {
        // TODO: Implement Chicago style
        return formatAPAStyle(reference)
    }
    
    private func formatHarvardStyle(_ reference: Reference) -> String {
        // TODO: Implement Harvard style
        return formatAPAStyle(reference)
    }
}

// Helper structs and functions
struct DocumentSection: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

func parseContentSections(_ content: String) -> [DocumentSection]? {
    let lines = content.components(separatedBy: .newlines)
    var sections: [DocumentSection] = []
    var currentTitle = ""
    var currentContent: [String] = []
    
    for line in lines {
        if line.isEmpty { continue }
        
        // Check if line is a header (starts with # or is in all caps)
        if line.hasPrefix("#") || line == line.uppercased() {
            // Save previous section if exists
            if !currentContent.isEmpty {
                sections.append(DocumentSection(
                    title: currentTitle,
                    content: currentContent.joined(separator: "\n")
                ))
                currentContent.removeAll()
            }
            currentTitle = line.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        } else {
            currentContent.append(line)
        }
    }
    
    // Add the last section
    if !currentContent.isEmpty {
        sections.append(DocumentSection(
            title: currentTitle,
            content: currentContent.joined(separator: "\n")
        ))
    }
    
    return sections.isEmpty ? nil : sections
}

#Preview {
    DocumentPreviewView(document: PreviewSampleData.shared.sampleDocument)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
