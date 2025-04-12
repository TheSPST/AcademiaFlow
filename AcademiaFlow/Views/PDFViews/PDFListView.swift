import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

@MainActor
struct PDFListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PDF.addedAt, order: .reverse) private var pdfs: [PDF]
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Binding var selectedPDF: PDF?
    @State private var searchText = ""
    @State private var isShowingFilePicker = false
    @State private var sortOption: SortOption = .modified
    
    var body: some View {
        GenericListView(
            searchText: $searchText,
            sortOption: $sortOption,
            items: pdfs,
            title: "PDFs",
            rowContent: { pdf in
                Button {
                    selectedPDF = pdf // Update selection directly
                } label: {
                    ItemRowView(
                        item: pdf,
                        subtitle: pdf.authors.joined(separator: ", "),
                        metadata: "Added \(pdf.displayTimestamp.formatted())"
                    )
                }
                .buttonStyle(.plain)
                .background(selectedPDF?.id == pdf.id ? Color.accentColor.opacity(0.1) : Color.clear)
            },
            onDelete: deletePDF,
            onDuplicate: duplicatePDF
        )
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
            errorHandler.handle(PDFError.fileNotFound)
        }
    }
    
    private func deletePDF(_ pdf: PDF) {
        do {
            try FileManager.default.removeItem(at: pdf.fileURL)
            modelContext.delete(pdf)
            try modelContext.save()
        } catch {
            errorHandler.handle(PDFError.fileNotFound)
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
                errorHandler.handle(PDFError.fileNotFound)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PDFListView(selectedPDF: .constant(nil))
            .modelContainer(PreviewSampleData.shared.container)
    }
}
