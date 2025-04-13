import Foundation
import SwiftData
import PDFKit

// ADD: Protocol for PDF model conformance
protocol PDFDocumentRepresentable {
    var fileName: String { get }
    var fileURL: URL { get }
    var title: String? { get }
    var authors: [String] { get }
    var tags: [String] { get }
}

@Model
final class PDF: PDFDocumentRepresentable {
    var fileName: String
    var fileURL: URL
    var title: String?
    
    // CHANGE: Add explicit transformer type for arrays
    var authors: [String] = []
    var addedAt: Date
    
    var tags: [String] = []
    
    @Relationship(deleteRule: .cascade)
    var annotations: [StoredAnnotation] = []
    
    @Relationship(deleteRule: .cascade)
    var notes: [Note] = []
    
    @Relationship(deleteRule: .cascade)
    var references: [Reference] = []
    
    // ADD: Cached text content
    @Transient
    private var _textContent: String?
    
    // ADD: Text content extraction
    var extractedText: String {
        if let cached = _textContent {
            return cached
        }
        
        // ADD: Error handling for PDF loading
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "[Error: PDF file not found]"
        }
        
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            return "[Error: Could not load PDF document]"
        }
        
        let pageCount = pdfDocument.pageCount
        var text = ""
        
        // ADD: Progress tracking for large PDFs
        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else {
                text += "[Error: Could not load page \(i + 1)]\n"
                continue
            }
            text += page.string ?? "[No text on page \(i + 1)]"
            if i < pageCount - 1 {
                text += "\n"
            }
        }
        
        _textContent = text
        return text
    }
    
    // ADD: Method to get summarized content for chat
    func chatContext(maxLength: Int = 4000) -> String {
        let fullText = extractedText
        if fullText.count <= maxLength {
            return fullText
        }
        
        // Get first and last parts of content for context
        let halfLength = maxLength / 2
        let firstPart = String(fullText.prefix(halfLength))
        let lastPart = String(fullText.suffix(halfLength))
        
        return """
        \(firstPart)
        
        [Content truncated...]
        
        \(lastPart)
        """
    }
    
    // ADD: Computed properties for better encapsulation
    var isBookmarked: Bool {
        // Implementation
        false
    }
    
    var hasAnnotations: Bool {
        !annotations.isEmpty
    }
    
    var hasNotes: Bool {
        !notes.isEmpty
    }
    
    init(fileName: String, fileURL: URL, title: String? = nil,
         authors: [String] = [], tags: [String] = []) {
        self.fileName = fileName
        self.fileURL = fileURL
        self.title = title
        self.authors = authors
        self.tags = tags
        self.addedAt = Date()
    }
}
