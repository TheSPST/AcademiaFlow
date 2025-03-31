import Foundation
import SwiftData

@Model
final class Note: Identifiable {
    var id: UUID
    var title: String
    var content: String
    var timestamp: Date
    var tags: Array<String>
    
    @Relationship(inverse: \Document.notes) var document: Document?
    
    init(title: String = "", content: String = "", tags: Array<String> = []) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.timestamp = Date()
        self.tags = tags
    }
}

// Sendable snapshot for Note
struct NoteSnapshot: Sendable {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
    let tags: Array<String>
    
    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.timestamp = note.timestamp
        self.tags = note.tags
    }
}

// MARK: - Note Management
extension Note {
    func update(title: String? = nil, content: String? = nil, tags: Array<String>? = nil) {
        if let title = title {
            self.title = title
        }
        if let content = content {
            self.content = content
        }
        if let tags = tags {
            self.tags = tags
        }
        self.timestamp = Date()
    }
    
    var isEmpty: Bool {
        title.isEmpty && content.isEmpty
    }
    
    var preview: String {
        if content.isEmpty {
            return "Empty note"
        }
        let words = content.split(separator: " ")
        let previewLength = min(words.count, 10)
        return words[..<previewLength].joined(separator: " ") + (words.count > 10 ? "..." : "")
    }
}

// MARK: - Sorting
extension Note {
    static func sortByDate(_ note1: Note, _ note2: Note) -> Bool {
        note1.timestamp > note2.timestamp
    }
    
    static func sortByTitle(_ note1: Note, _ note2: Note) -> Bool {
        note1.title.localizedCaseInsensitiveCompare(note2.title) == .orderedAscending
    }
}
