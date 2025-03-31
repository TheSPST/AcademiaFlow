import Foundation
import SwiftUI
import SwiftData

// MARK: - Document Export Service
actor DefaultDocumentExportService: DocumentExportService {
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.temporaryDirectory = fileManager.temporaryDirectory
    }
    
    func export(_ documentSnapshot: DocumentSnapshot) async throws -> URL {
        // Create a temporary file URL
        let fileName = documentSnapshot.title.isEmpty ? "Untitled" : documentSnapshot.title
        let fileURL = temporaryDirectory.appendingPathComponent(fileName).appendingPathExtension("pdf")
        
        // Ensure old temporary files are cleaned up
        try? fileManager.removeItem(at: fileURL)
        
        // Convert document to requested format
        let data = try await prepareForExport(documentSnapshot)
        
        // Write to temporary file
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    private func prepareForExport(_ snapshot: DocumentSnapshot) async throws -> Data {
        // TODO: Implement actual export logic
        guard let data = snapshot.content.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }
        return data
    }
    
    func cleanupTemporaryFiles() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            for url in contents where url.pathExtension == "pdf" || url.pathExtension == "md" || url.pathExtension == "txt" {
                try? fileManager.removeItem(at: url)
            }
        } catch {
            print("Failed to cleanup temporary files: \(error)")
        }
    }
}

// MARK: - Document Export Helpers
extension Document: Exportable {
    func prepareForExport() async throws -> Data {
        debugPrint("preparing document for export...")
        return try await exportToPDF()
    }
    
    func prepareForExport(as format: ExportFormat) async throws -> Data {
        switch format {
        case .pdf:
            return try await exportToPDF()
//        case .markdown:
//            return try await exportToMarkdown()
        case .plainText:
            return try await exportToPlainText()
        }
    }
    
    private func exportToPDF() async throws -> Data {
        // TODO: Implement PDF conversion using PDFKit
        // This would typically involve rendering the document content
        // through a WebKit or PDFKit pipeline
        throw ExportError.notImplemented
    }
    
    private func exportToMarkdown() async throws -> Data {
        guard let data = content.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }
        return data
    }
    
    private func exportToPlainText() async throws -> Data {
        guard let data = content.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }
        return data
    }
}

// MARK: - Errors
enum ExportError: Error, Sendable {
    case conversionFailed
    case fileCreationFailed
    case invalidFormat
    case notImplemented
    
    var localizedDescription: String {
        switch self {
        case .conversionFailed:
            return "Failed to convert document to the requested format"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .invalidFormat:
            return "Invalid export format"
        case .notImplemented:
            return "This export format is not yet implemented"
        }
    }
}
