import Foundation
import SwiftData

@Model
final class DocumentVersion {
    var versionNumber: Int
    var content: String
    var createdAt: Date
    var aiSummary: String?
    var changes: String?
    
    @Relationship(inverse: \Document.versions) var document: Document?
    
    init(versionNumber: Int, content: String, aiSummary: String? = nil) {
        self.versionNumber = versionNumber
        self.content = content
        self.createdAt = Date()
        self.aiSummary = aiSummary
    }
}