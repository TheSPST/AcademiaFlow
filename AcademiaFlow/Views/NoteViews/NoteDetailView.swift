import SwiftUI
import SwiftData

struct NoteDetailView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(note.title)
                .font(.title)
            
            ScrollView {
                Text(note.content)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(note.tags, id: \.self) { tag in
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
            
            if let pageNumber = note.pageNumber {
                Text("Page: \(pageNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Created: \(note.timestamp.formatted())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}