import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit
import Foundation

enum ExportFormat: String, CaseIterable {
    case pdf
    case plainText
//    case docx
//    case markdown
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .plainText: return "txt"
//        case .docx: return "docx"
//        case .markdown: return "md"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .pdf: return .pdf
        case .plainText: return .plainText
//        case .docx: return .docx
//        case .markdown: return .markdown
        }
    }
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF Document"
        case .plainText: return "Plain Text"
        }
    }
}

@MainActor
class DocumentExporter {
    static func export(_ document: Document, as format: ExportFormat) async throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(document.title)
            .appendingPathExtension(format.fileExtension)
        
        switch format {
        case .pdf:
            try await exportToPDF(document, to: tempURL)
        case .plainText:
            try exportToPlainText(document, to: tempURL)
        }
        
        return tempURL
    }
    
    private static func exportToPDF(_ document: Document, to url: URL) async throws {
        // Create PDF document
        let pdfDocument = PDFDocument()
        
        // Create formatted content
        let content = createFormattedContent(for: document)
        
        // Convert to PDF
        let data = try await renderPDFData(from: content)
        
        // Write PDF to file
        try data.write(to: url)
    }
    
    private static func createFormattedContent(for document: Document) -> NSAttributedString {
        let content = NSMutableAttributedString()
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.paragraphSpacing = 20
                return style
            }()
        ]
        content.append(NSAttributedString(string: document.title + "\n\n", attributes: titleAttributes))
        
        // Tags
        if !document.tags.isEmpty {
            let tagsAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    style.paragraphSpacing = 20
                    return style
                }()
            ]
            let tagsString = "Tags: " + document.tags.joined(separator: ", ") + "\n\n"
            content.append(NSAttributedString(string: tagsString, attributes: tagsAttributes))
        }
        
        // Main content
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 6
                style.paragraphSpacing = 12
                return style
            }()
        ]
        content.append(NSAttributedString(string: document.content + "\n\n", attributes: bodyAttributes))
        
        // References
        if !document.references.isEmpty {
            let referenceTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.paragraphSpacing = 12
                    return style
                }()
            ]
            content.append(NSAttributedString(string: "References\n\n", attributes: referenceTitleAttributes))
            
            let referenceAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.paragraphSpacing = 6
                    return style
                }()
            ]
            
            for reference in document.references {
                let formattedReference = formatReference(reference, style: document.citationStyle) + "\n"
                content.append(NSAttributedString(string: formattedReference, attributes: referenceAttributes))
            }
        }
        
        return content
    }
    
    private static func renderPDFData(from attributedString: NSAttributedString) async throws -> Data {
        // Create PDF data container
        let data = NSMutableData()
        
        // Set up PDF page format (US Letter size)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        var mediaBox = pageRect
        
        // Create PDF context
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }
        
        // Calculate margins
        let margins: CGFloat = 72 // 1 inch margins
        let contentRect = pageRect.insetBy(dx: margins, dy: margins)
        
        // Create frame for text
        let path = CGPath(rect: contentRect, transform: nil)
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
        
        // Set up for multiple pages
        var currentRange = CFRange(location: 0, length: 0)
        var hasMorePages = true
        
        while hasMorePages {
            context.beginPage(mediaBox: &mediaBox)
            
            let frame = CTFramesetterCreateFrame(frameSetter, currentRange, path, nil)
            CTFrameDraw(frame, context)
            
            // Calculate next range
            let frameRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += frameRange.length
            hasMorePages = currentRange.location < attributedString.length
            
            context.endPage()
        }
        
        return data as Data
    }
    
    private static func exportToPlainText(_ document: Document, to url: URL) throws {
        var content = document.title + "\n\n"
        
        if !document.tags.isEmpty {
            content += "Tags: " + document.tags.joined(separator: ", ") + "\n\n"
        }
        
        content += document.content + "\n\n"
        
        if !document.references.isEmpty {
            content += "References:\n\n"
            for reference in document.references {
                content += formatReference(reference, style: document.citationStyle) + "\n"
            }
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func formatReference(_ reference: Reference, style: CitationStyle) -> String {
        let authors = reference.authors.joined(separator: ", ")
        let year = reference.year.map { String($0) } ?? ""
        let title = reference.title
        let journal = reference.journal ?? ""
        
        switch style {
        case .apa:
            return "\(authors) (\(year)). \(title). \(journal)"
        case .mla:
            return "\(authors). \"\(title).\" \(journal), \(year)"
        case .chicago:
            return "\(authors). \(title). \(journal) (\(year))"
        case .harvard:
            return "\(authors) \(year), '\(title)', \(journal)"
        }
    }
}
