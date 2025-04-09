import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

struct PDFListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @Query private var pdfs: [PDF]
    @State private var selectedPDF: PDF?
    @State private var isShowingFilePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var sortOption: SortOption = .modified
    var filteredAndSortedPDF: [PDF] {
        let filtered = searchText.isEmpty ? pdfs : pdfs.filter { pdf in
            pdf.fileName.localizedCaseInsensitiveContains(searchText) ||
            pdf.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        return filtered.sorted { pdf1, pdf2 in
            switch sortOption {
            case .modified:
                return pdf1.addedAt > pdf2.addedAt
            case .created:
                return pdf1.addedAt > pdf2.addedAt
            case .title, .type:
                return pdf1.fileName > pdf2.fileName
            }
        }
    }
    var body: some View {
        List {
            ForEach(filteredAndSortedPDF) { pdf in
                NavigationLink(value: pdf) {
                    PDFRowView(pdf: pdf)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        duplicatePDF(pdf)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletePDF(pdf)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    PDFContextMenu(document: pdf,
                                   onDuplicate: { duplicatePDF(pdf) },
                                   onDelete: { deletePDF(pdf) })
                }
            }
        }
        .navigationTitle("PDFs")
        .navigationDestination(for: PDF.self) { pdf in
            PDFPreviewView(pdf: pdf, modelContext: modelContext)
                .id(pdf.id)
        }
        .searchable(text: $searchText, prompt: "Search pdf")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                SortByMenuView(sortOption: $sortOption)
                Button(action: { isShowingFilePicker.toggle() }) {
                    Label("Import PDF", systemImage: "doc.badge.plus")
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: true
        ) { result in
            Task {
                await handleSelectedFiles(result)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func duplicatePDF(_ pdf: PDF) {
        do {
            let newFileName = pdf.fileName.replacingOccurrences(
                of: ".pdf",
                with: " (copy).pdf",
                options: .anchored
            )
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newFileURL = documentsURL.appendingPathComponent(UUID().uuidString + "_" + newFileName)
            
            try FileManager.default.copyItem(at: pdf.fileURL, to: newFileURL)
            
            let newPDF = PDF(
                fileName: newFileName,
                fileURL: newFileURL,
                title: pdf.title.map { $0 + " (copy)" },
                authors: pdf.authors,
                tags: pdf.tags
            )
            
            modelContext.insert(newPDF)
            try modelContext.save()
            
        } catch {
            errorMessage = "Failed to duplicate PDF: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func deletePDF(_ pdf: PDF) {
        do {
            try FileManager.default.removeItem(at: pdf.fileURL)
            modelContext.delete(pdf)
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete PDF: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func handleSelectedFiles(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let fileName = url.lastPathComponent
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let destinationURL = documentsURL.appendingPathComponent(UUID().uuidString + "_" + fileName)
                    
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    await MainActor.run {
                        let pdf = PDF(fileName: fileName, fileURL: destinationURL)
                        modelContext.insert(pdf)
                        try? modelContext.save()
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct PDFRowView: View {
    let pdf: PDF
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pdf.title ?? pdf.fileName)
                .font(.headline)
            let authors = pdf.authors
            if !authors.isEmpty {
                Text(pdf.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            let tags = pdf.tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(pdf.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Text("Added \(pdf.addedAt.formatted())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
struct SortByMenuView: View {
    @Binding var sortOption: SortOption
    var body: some View {
        Menu {
            Picker("Sort by", selection: $sortOption) {
                Text("Last Modified").tag(SortOption.modified)
                Text("Date Created").tag(SortOption.created)
                Text("Title").tag(SortOption.title)
                Text("Type").tag(SortOption.type)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}
struct PDFContextMenu: View {
    let document: PDF
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onDuplicate()
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

#Preview {
    NavigationStack {
        PDFListView()
            .modelContainer(PreviewSampleData.shared.container)
    }
}

