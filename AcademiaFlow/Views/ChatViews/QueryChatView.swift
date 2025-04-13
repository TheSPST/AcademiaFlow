import SwiftUI
import SwiftData

@MainActor
struct QueryChatView: View {
    @Binding var isPresented: Bool
    @State private var queryText = ""
    @State private var results: [QueryResult] = []
    @State private var isLoading = false
    @Environment(\.modelContext) private var modelContext
    
    let chatService = ChatService()
    
    struct QueryResult: Identifiable {
        let id = UUID()
        let type: String
        let items: [Any]
        let summary: String
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Ask about your documents")
                    .font(.headline)
                Spacer()
                Button(action: { withAnimation { isPresented = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(results) { result in
                        QueryResultView(result: result)
                    }
                }
                .padding()
            }
            
            HStack {
                TextField("Ask something...", text: $queryText)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: executeQuery) {
                    Image(systemName: isLoading ? "clock" : "magnifyingglass.circle.fill")
                        .font(.title2)
                }
                .disabled(queryText.isEmpty || isLoading)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
    
    private func executeQuery() {
        isLoading = true
        
        // Example queries to support
        let query = queryText.lowercased()
        Task {
            do {
                if query.contains("document") || query.contains("documents") {
                    let documents = try modelContext.fetch(FetchDescriptor<Document>())
                    let summary = try await generateSummary(for: documents, type: "documents")
                    results.append(QueryResult(type: "Documents", items: documents, summary: summary))
                }
                
                if query.contains("pdf") || query.contains("pdfs") {
                    let pdfs = try modelContext.fetch(FetchDescriptor<PDF>())
                    let summary = try await generateSummary(for: pdfs, type: "PDFs")
                    results.append(QueryResult(type: "PDFs", items: pdfs, summary: summary))
                }
                
                if query.contains("note") || query.contains("notes") {
                    let notes = try modelContext.fetch(FetchDescriptor<Note>())
                    let summary = try await generateSummary(for: notes, type: "notes")
                    results.append(QueryResult(type: "Notes", items: notes, summary: summary))
                }
                
                if query.contains("reference") || query.contains("references") {
                    let references = try modelContext.fetch(FetchDescriptor<Reference>())
                    let summary = try await generateSummary(for: references, type: "references")
                    results.append(QueryResult(type: "References", items: references, summary: summary))
                }
                
            } catch {
                print("Query error:", error)
            }
            
            isLoading = false
            queryText = ""
        }
    }
    
    private func generateSummary(for items: [Any], type: String) async throws -> String {
        let context = "Summary request for \(items.count) \(type)"
        return try await chatService.sendMessage("Summarize these \(type)", context: context)
    }
}

struct QueryResultView: View {
    let result: QueryChatView.QueryResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.type)
                .font(.headline)
            
            Text("Found \(result.items.count) items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(result.summary)
                .font(.body)
                .padding(.vertical, 4)
            
            if !result.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(0..<min(5, result.items.count), id: \.self) { index in
                            ItemPreviewCard(item: result.items[index])
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ItemPreviewCard: View {
    let item: Any
    
    var body: some View {
        VStack(alignment: .leading) {
            if let document = item as? Document {
                Text(document.title)
                    .lineLimit(2)
            } else if let pdf = item as? PDF {
                Text(pdf.fileName)
                    .lineLimit(2)
            } else if let note = item as? Note {
                Text(note.title ?? "Untitled Note")
                    .lineLimit(2)
            } else if let reference = item as? Reference {
                Text(reference.title)
                    .lineLimit(2)
            }
        }
        .frame(width: 120)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}