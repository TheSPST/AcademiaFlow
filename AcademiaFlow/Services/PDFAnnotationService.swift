import PDFKit
import SwiftData

@ModelActor
final actor PDFAnnotationService {
    static func create(withContainer container: ModelContainer) -> PDFAnnotationService {
        PDFAnnotationService(modelContainer: container)
    }

    func saveAnnotation(_ snapshot: StoredAnnotationSnapshot, pdfID: PersistentIdentifier) throws {
        // All operations now properly isolated within actor
        let descriptor = FetchDescriptor<PDF>(predicate: #Predicate<PDF> { pdf in
            pdf.persistentModelID == pdfID
        })
        guard let pdf = try modelContext.fetch(descriptor).first else {
            throw PDFError.annotationFailed(NSError(domain: "PDF", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDF not found"]))
        }
        
        let annotation = StoredAnnotation(from: snapshot, pdf: pdf)
        modelContext.insert(annotation)
        try modelContext.save()
    }

    func loadAnnotations(forPDFWithID pdfID: PersistentIdentifier) throws -> [StoredAnnotationSnapshot] {
        let descriptor = FetchDescriptor<StoredAnnotation>(
            predicate: #Predicate { annotation in
                annotation.pdf?.persistentModelID == pdfID
            }
        )
        // CHANGE: More efficient single fetch with predicate
        return try modelContext.fetch(descriptor).map(\.snapshot)
    }

    func deleteAnnotation(_ annotation: StoredAnnotation) throws {
        modelContext.delete(annotation)
        try modelContext.save()
    }
}
