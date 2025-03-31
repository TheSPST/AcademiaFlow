import Foundation
import SwiftData

@Model
final class PDF {
    var fileName: String
    var fileURL: URL
    var title: String?
    var authors: [String]
    var addedAt: Date
    var tags: Array<String>
    
    @Relationship(deleteRule: .cascade) var notes: [Note]
    @Relationship(deleteRule: .cascade) var references: [Reference]
    
    init(fileName: String,
         fileURL: URL,
         title: String? = nil,
         authors: [String] = [],
         tags: Array<String> = []) {
        self.fileName = fileName
        self.fileURL = fileURL
        self.title = title
        self.authors = authors
        self.tags = tags
        self.addedAt = Date()
        // Initialize relationships
        self.notes = []
        self.references = []
    }
}
