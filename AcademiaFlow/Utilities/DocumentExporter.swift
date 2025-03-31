import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Hashable {
    case pdf = "PDF"
    case markdown = "Markdown"
    case plainText = "Plain Text"
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .markdown: return "md"
        case .plainText: return "txt"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .pdf: return .pdf
        case .markdown: return .plainText
        case .plainText: return .plainText
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .markdown: return "doc.text.fill"
        case .plainText: return "doc.text"
        }
    }
}

// DocumentExporter utility class
struct DocumentExporter {
    static func export(_ document: Document, as format: ExportFormat) async throws -> URL {
        let service = DefaultDocumentExportService()
        let snapshot = DocumentSnapshot(from: document)
        return try await service.export(snapshot)
    }
}
