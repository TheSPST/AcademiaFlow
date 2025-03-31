import Foundation
import SwiftUI
import SwiftData

// MARK: - Document Protocols
protocol DocumentManageable {
    var title: String { get set }
    var content: String { get set }
    var documentType: DocumentType { get set }
    var tags: [String] { get set }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
}

protocol VersionControlled {
    var versions: [DocumentVersion] { get set }
    func createNewVersion() -> DocumentVersion
}

protocol Exportable {
    func prepareForExport() async throws -> Data
}

protocol Annotatable {
    var notes: [Note] { get set }
    func addNote(_ note: Note)
    func removeNote(_ note: Note)
}

// MARK: - Export Protocols
protocol DocumentExportService: Actor {
    func export(_ documentSnapshot: DocumentSnapshot) async throws -> URL
}

// MARK: - Default Implementations
extension DocumentManageable {
    var displayTitle: String {
        title.isEmpty ? "Untitled Document" : title
    }
}

extension VersionControlled where Self: DocumentManageable {
    func createNewVersion() -> DocumentVersion {
        DocumentVersion(title: title, content: content, createdAt: Date())
    }
}
