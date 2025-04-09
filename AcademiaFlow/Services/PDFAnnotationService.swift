import PDFKit
import SwiftData

// ADD: Separate service for annotation handling
actor PDFAnnotationService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveAnnotation(_ annotation: StoredAnnotation) async throws {
        modelContext.insert(annotation)
        try modelContext.save()
    }
    
    func loadAnnotations(for pdf: PDF) async throws -> [StoredAnnotation] {
        let descriptor = FetchDescriptor<StoredAnnotation>()
        let allAnnotations = try modelContext.fetch(descriptor)
        return allAnnotations.filter { $0.pdf?.persistentModelID == pdf.persistentModelID }
    }
    
    func deleteAnnotation(_ annotation: StoredAnnotation) async throws {
        modelContext.delete(annotation)
        try modelContext.save()
    }
}