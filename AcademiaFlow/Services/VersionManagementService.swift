import Foundation
import SwiftData

actor VersionManagementService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func createNewVersion(for document: Document, content: String) async throws -> DocumentVersionSnapshot {
        let versionNumber = DocumentVersion.nextVersionNumber(for: document)
        let newVersion = DocumentVersion(versionNumber: versionNumber, content: content)
        
        if let lastVersion = document.versions.last {
            newVersion.generateChangeSummary(from: lastVersion)
        }
        
        document.versions.append(newVersion)
        document.updatedAt = Date()
        
        try modelContext.save()
        
        // Return a snapshot for actor isolation
        return DocumentVersionSnapshot(from: newVersion)
    }
    
    func getVersionHistory(for document: Document) -> [DocumentVersionSnapshot] {
        document.versions
            .sorted { $0.versionNumber > $1.versionNumber }
            .map { DocumentVersionSnapshot(from: $0) }
    }
    
    func compareVersions(v1: DocumentVersionSnapshot, v2: DocumentVersionSnapshot) async -> String {
        // TODO: Implement proper diff comparison
        "Comparing version \(v1.versionNumber) with \(v2.versionNumber)"
    }
}