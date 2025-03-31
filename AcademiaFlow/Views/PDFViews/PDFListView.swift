import SwiftUI
import SwiftData

struct PDFListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pdfs: [PDF]
    
    var body: some View {
        List {
            ForEach(pdfs) { pdf in
                Text(pdf.title ?? "No title Available")
            }
        }
        .navigationTitle("PDFs")
    }
}
