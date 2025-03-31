import Foundation
import SwiftData

@Model
final class Reference {
    var title: String
    var authors: [String]
    var year: Int?
    var doi: String?
    var url: URL?
    var publisher: String?
    var journal: String?
    var abstract: String?
    var addedAt: Date
    var type: ReferenceType
    
    @Relationship(inverse: \Document.references) var documents: [Document]?
    @Relationship(inverse: \PDF.references) var pdf: PDF?
    
    init(title: String,
         authors: [String],
         year: Int? = nil,
         doi: String? = nil,
         url: URL? = nil,
         publisher: String? = nil,
         journal: String? = nil,
         abstract: String? = nil,
         type: ReferenceType = .article) {
        self.title = title
        self.authors = authors
        self.year = year
        self.doi = doi
        self.url = url
        self.publisher = publisher
        self.journal = journal
        self.abstract = abstract
        self.type = type
        self.addedAt = Date()
    }
}

enum ReferenceType: String, Codable {
    case article
    case book
    case conference
    case thesis
    case website
    case other
}