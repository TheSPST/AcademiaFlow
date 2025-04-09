import Foundation
import SwiftUI
import SwiftData
import PDFKit
import WebKit

// MARK: - Document Export Service
actor DefaultDocumentExportService: DocumentExportService {
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.temporaryDirectory = fileManager.temporaryDirectory
    }
    
    func export(_ documentSnapshot: DocumentSnapshot) async throws -> URL {
        do {
            // Create a temporary file URL
            let fileName = documentSnapshot.title.isEmpty ? "Untitled" : documentSnapshot.title
            let fileURL = temporaryDirectory.appendingPathComponent(fileName).appendingPathExtension("pdf")
            
            // Ensure old temporary files are cleaned up
            try? fileManager.removeItem(at: fileURL)
            
            // Convert document to requested format
            let data = try await generatePDF(from: documentSnapshot)
            
            // Write to temporary file
            try data.write(to: fileURL)
            
            return fileURL
        } catch {
            throw DocumentError.exportFailed(error)
        }
    }
    
    private func generatePDF(from snapshot: DocumentSnapshot) async throws -> Data {
        // Create HTML content
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    margin: 40px;
                    line-height: 1.6;
                }
                h1 { margin-bottom: 20px; }
                .metadata {
                    color: #666;
                    margin-bottom: 30px;
                    font-size: 0.9em;
                }
            </style>
        </head>
        <body>
            <h1>\(snapshot.title)</h1>
            <div class="metadata">
                <div>Document Type: \(snapshot.documentType.rawValue)</div>
                <div>Created: \(formatDate(snapshot.createdAt))</div>
                <div>Last Modified: \(formatDate(snapshot.updatedAt))</div>
                \(snapshot.tags.isEmpty ? "" : "<div>Tags: \(snapshot.tags.joined(separator: ", "))</div>")
            </div>
            <div class="content">
                \(snapshot.content)
            </div>
        </body>
        </html>
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Convert HTML to PDF using WebKit
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter size
                webView.loadHTMLString(htmlContent, baseURL: nil)
                
                let config = WKPDFConfiguration()
                webView.createPDF(configuration: config) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: ExportError.pdfGenerationFailed(error))
                    }
                }
            }
        }
    }
    
    private func generateMarkdown(from snapshot: DocumentSnapshot) -> Data {
        let markdown = """
        # \(snapshot.title)
        
        Type: \(snapshot.documentType.rawValue)
        Created: \(formatDate(snapshot.createdAt))
        Modified: \(formatDate(snapshot.updatedAt))
        Tags: \(snapshot.tags.joined(separator: ", "))
        
        \(snapshot.content)
        """
        
        return markdown.data(using: .utf8) ?? Data()
    }
    
    private func generatePlainText(from snapshot: DocumentSnapshot) -> Data {
        let plainText = """
        \(snapshot.title.uppercased())
        
        Document Type: \(snapshot.documentType.rawValue)
        Created: \(formatDate(snapshot.createdAt))
        Modified: \(formatDate(snapshot.updatedAt))
        Tags: \(snapshot.tags.joined(separator: ", "))
        
        \(snapshot.content)
        """
        
        return plainText.data(using: .utf8) ?? Data()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func cleanupTemporaryFiles() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            for url in contents where url.pathExtension == "pdf" {
                try? fileManager.removeItem(at: url)
            }
        } catch {
            print("Failed to cleanup temporary files: \(error)")
        }
    }
}

// MARK: - Document Export Helpers
extension Document: Exportable {
    func prepareForExport(as format: ExportFormat) async throws -> Data {
        switch format {
        case .pdf:
            return try await exportToPDF()
        case .markdown:
            return try await exportToMarkdown()
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
    case pdfGenerationFailed(Error)
    
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
        case .pdfGenerationFailed(let error):
            return "PDF generation failed: \(error.localizedDescription)"
        }
    }
}
