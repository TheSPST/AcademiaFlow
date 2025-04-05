import Foundation
import SwiftData

@Model
final class Document {
    // Basic properties
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var content: String
    var filePath: String
    var createdAt: Date
    var updatedAt: Date
    var documentType: DocumentType
    var tags: Array<String>

    // Relationships
    @Relationship(deleteRule: .cascade) var versions: [DocumentVersion] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var references: [Reference] = []
    
    // Format and template info
    var citationStyle: CitationStyle
    var template: DocumentTemplate
    
    init(title: String,
         content: String = "",
         richContentData: Data? = nil,
         documentType: DocumentType = .paper,
         tags: Array<String> = [],
         citationStyle: CitationStyle = .apa,
         template: DocumentTemplate = .default,
         filePath: String) {
        self.title = title
        self.content = content
        self.documentType = documentType
        self.tags = tags
        self.citationStyle = citationStyle
        self.template = template
        self.createdAt = Date()
        self.updatedAt = Date()
        self.filePath = filePath
    }
}

// Supporting enums
enum DocumentType: String, Codable, CaseIterable, Sendable {
    case paper
    case thesis
    case literature_review
    case abstract
    case outline
}

enum CitationStyle: String, Codable, CaseIterable, Sendable {
    case apa
    case mla
    case chicago
    case harvard
}

enum DocumentTemplate: String, Codable, CaseIterable, Sendable {
    case `default`
    case academic
    case research
    case custom
}

// Add a Sendable-compliant document snapshot for passing across actor boundaries
struct DocumentSnapshot: Sendable {
    let id: PersistentIdentifier
    let title: String
    let content: String
    let documentType: DocumentType
    let tags: [String]
    let citationStyle: CitationStyle
    let template: DocumentTemplate
    let createdAt: Date
    let updatedAt: Date
    
    init(from document: Document) {
        self.id = document.persistentModelID
        self.title = document.title
        self.content = document.content
        self.documentType = document.documentType
        self.tags = document.tags
        self.citationStyle = document.citationStyle
        self.template = document.template
        self.createdAt = document.createdAt
        self.updatedAt = document.updatedAt
    }
}
