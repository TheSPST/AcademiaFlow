import SwiftUI
import SwiftData

struct DocumentVersionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: Document
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(document.versions.sorted { $0.versionNumber > $1.versionNumber }, id: \.versionNumber) { version in
                    VersionRow(version: version)
                }
            }
            .navigationTitle("Version History")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct VersionRow: View {
    let version: DocumentVersion
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Version \(version.versionNumber)")
                    .font(.headline)
                Spacer()
                Text(version.createdAt.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let summary = version.aiSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetails.toggle()
        }
        .sheet(isPresented: $showingDetails) {
            VersionDetailView(version: version)
        }
    }
}

struct VersionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let version: DocumentVersion
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(version.content)
                        .padding()
                    
                    if let changes = version.changes {
                        VStack(alignment: .leading) {
                            Text("Changes")
                                .font(.headline)
                            Text(changes)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Version \(version.versionNumber)")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("Version History") {
    DocumentVersionsView(document: PreviewSampleData.shared.sampleDocument)
        .modelContainer(PreviewSampleData.shared.container)
}

#Preview("Version Row") {
    if let version = PreviewSampleData.shared.sampleDocument.versions.first {
        VersionRow(version: version)
            .padding()
    }
}
