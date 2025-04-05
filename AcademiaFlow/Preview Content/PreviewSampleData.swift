import Foundation
import SwiftData

@MainActor
class PreviewSampleData {
    static let shared = PreviewSampleData()
    
    let container: ModelContainer
    let context: ModelContext
    
    var sampleDocument: Document {
        let document = Document(
            title: "Sample Research Paper",
            content: """
            Abstract:
            This is a sample research paper discussing the implementation of SwiftUI and SwiftData in modern iOS applications.
            
            Introduction:
            The evolution of Apple's frameworks has led to significant improvements in how developers build applications...
            """,
            documentType: .paper,
            tags: ["SwiftUI", "iOS", "Research"],
            citationStyle: .apa,
            template: .academic, filePath: ""
        )
        
        // Add sample versions
        document.versions.append(DocumentVersion(
            versionNumber: 1,
            content: "Initial draft of the research paper",
            aiSummary: "First version with basic structure and introduction"
        ))
        
        document.versions.append(DocumentVersion(
            versionNumber: 2,
            content: "Updated draft with more sections",
            aiSummary: "Added methodology and results sections"
        ))
        
        // Add sample references
        let reference1 = Reference(
            title: "SwiftUI Essentials",
            authors: ["John Doe"],
            year: 2023,
            publisher: "Tech Publications"
        )
        
        let reference2 = Reference(
            title: "Modern iOS Architecture",
            authors: ["Jane Smith", "Bob Wilson"],
            year: 2023,
            journal: "Journal of Swift Development"
        )
        
        document.references = [reference1, reference2]
        
        return document
    }
    
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            container = try ModelContainer(
                for: Document.self, PDF.self, Reference.self, Note.self,
                configurations: config
            )
            context = ModelContext(container)
            
            // Insert sample data
            let document1 = sampleDocument
            
            let document2 = Document(
                title: "Literature Review: Mobile Development",
                content: "This literature review explores various mobile development frameworks...",
                documentType: .literature_review,
                tags: ["Mobile", "Development", "Review"],
                citationStyle: .mla,
                template: .research, filePath: ""
            )
            
            context.insert(document1)
            context.insert(document2)
            
        } catch {
            fatalError("Failed to create preview container: \(error.localizedDescription)")
        }
    }
}
