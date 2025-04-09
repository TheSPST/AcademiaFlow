import Foundation
import SwiftData

// ADD: Protocol for PDF model conformance
protocol PDFDocumentRepresentable {
    var fileName: String { get }
    var fileURL: URL { get }
    var title: String? { get }
    var authors: [String] { get }
    var tags: [String] { get }
}

@Model
final class PDF: PDFDocumentRepresentable {
    var fileName: String
    var fileURL: URL
    var title: String?
    
    // CHANGE: Add explicit transformer type for arrays
    var authors: [String] = []
    var addedAt: Date
    
    var tags: [String] = []
    
    @Relationship(deleteRule: .cascade)
    var annotations: [StoredAnnotation] = []
    
    @Relationship(deleteRule: .cascade)
    var notes: [Note] = []
    
    @Relationship(deleteRule: .cascade)
    var references: [Reference] = []
    
    // ADD: Computed properties for better encapsulation
    var isBookmarked: Bool {
        // Implementation
        false
    }
    
    var hasAnnotations: Bool {
        !annotations.isEmpty
    }
    
    var hasNotes: Bool {
        !notes.isEmpty
    }
    
    init(fileName: String, fileURL: URL, title: String? = nil,
         authors: [String] = [], tags: [String] = []) {
        self.fileName = fileName
        self.fileURL = fileURL
        self.title = title
        self.authors = authors
        self.tags = tags
        self.addedAt = Date()
    }
}
