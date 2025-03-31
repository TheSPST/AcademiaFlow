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
    
    convenience init(title: String, content: String, createdAt: Date) {
        self.init(versionNumber: 1, content: content)
        self.createdAt = createdAt
    }
}

struct DocumentVersionSnapshot: Sendable {
    let id: PersistentIdentifier
    let versionNumber: Int
    let content: String
    let createdAt: Date
    let aiSummary: String?
    let changes: String?
    
    init(from version: DocumentVersion) {
        self.id = version.persistentModelID
        self.versionNumber = version.versionNumber
        self.content = version.content
        self.createdAt = version.createdAt
        self.aiSummary = version.aiSummary
        self.changes = version.changes
    }
}

extension DocumentVersion {
    static func nextVersionNumber(for document: Document) -> Int {
        let currentMax = document.versions.map(\.versionNumber).max() ?? 0
        return currentMax + 1
    }
    
    var isLatestVersion: Bool {
        guard let document = document else { return true }
        return self.versionNumber == document.versions.map(\.versionNumber).max()
    }
    
    func generateChangeSummary(from previousVersion: DocumentVersion) {
        let summary = "Changes from version \(previousVersion.versionNumber) to \(self.versionNumber)"
        self.changes = summary
    }
    
    func generateAISummary() async {
        self.aiSummary = "AI Summary for version \(versionNumber)"
    }
}

extension DocumentVersion {
    func diff(from other: DocumentVersion) -> String {
        "Difference between version \(other.versionNumber) and \(self.versionNumber)"
    }
}
