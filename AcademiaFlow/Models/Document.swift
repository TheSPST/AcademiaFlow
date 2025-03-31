import Foundation
import SwiftData

@Model
final class Document {
    // Basic properties
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var documentType: DocumentType
    var tags: [String]
    
    // Relationships - note: @Relationship properties are automatically initialized
    @Relationship(deleteRule: .cascade) var versions: [DocumentVersion] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var references: [Reference] = []
    
    // Format and template info
    var citationStyle: CitationStyle
    var template: DocumentTemplate
    
    init(title: String,
         content: String = "",
         documentType: DocumentType = .paper,
         tags: [String] = [],
         citationStyle: CitationStyle = .apa,
         template: DocumentTemplate = .default) {
        self.title = title
        self.content = content
        self.documentType = documentType
        self.tags = tags
        self.citationStyle = citationStyle
        self.template = template
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// Supporting enums
enum DocumentType: String, Codable, CaseIterable {
    case paper
    case thesis
    case literature_review
    case abstract
    case outline
}

enum CitationStyle: String, Codable, CaseIterable {
    case apa
    case mla
    case chicago
    case harvard
}

enum DocumentTemplate: String, Codable, CaseIterable {
    case `default`
    case academic
    case research
    case custom
}
