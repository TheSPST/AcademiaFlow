import Foundation
import SwiftUI

// MARK: - Base Error Protocol
protocol AppError: LocalizedError, Identifiable {
    var id: UUID { get }
    var title: String { get }
    var errorDescription: String? { get }
    var recoveryAction: String? { get }
}

// MARK: - Error Types
enum DocumentError: AppError {
    case saveFailure(Error)
    case loadFailure(Error)
    case versionCreationFailed(Error)
    case exportFailed(Error)
    case invalidFormat
    case outlineGenerationFailed
    
    var id: UUID { UUID() }
    
    var title: String {
        switch self {
        case .saveFailure: return "Save Error"
        case .loadFailure: return "Load Error"
        case .versionCreationFailed: return "Version Error"
        case .exportFailed: return "Export Error"
        case .invalidFormat: return "Format Error"
        case .outlineGenerationFailed: return "Outline Error"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .saveFailure(let error):
            return "Failed to save document: \(error.localizedDescription)"
        case .loadFailure(let error):
            return "Failed to load document: \(error.localizedDescription)"
        case .versionCreationFailed(let error):
            return "Failed to create version: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export document: \(error.localizedDescription)"
        case .invalidFormat:
            return "The document format is invalid"
        case .outlineGenerationFailed:
            return "Failed to generate document outline"
        }
    }
    
    var recoveryAction: String? {
        switch self {
        case .saveFailure:
            return "Try saving again or check your available storage"
        case .loadFailure:
            return "Check if the document exists and try again"
        case .versionCreationFailed:
            return "Try creating the version again"
        case .exportFailed:
            return "Check the export format and try again"
        case .invalidFormat:
            return "Try converting the document to a supported format"
        case .outlineGenerationFailed:
            return "Check document structure and try again"
        }
    }
}

enum PDFError: AppError {
    case fileNotFound
    case invalidDocument
    case annotationFailed(Error)
    case bookmarkFailed
    case searchFailed(Error)
    case loadAnnotationsFailed(Error)
    
    var id: UUID { UUID() }
    
    var title: String {
        switch self {
        case .fileNotFound: return "File Not Found"
        case .invalidDocument: return "Invalid PDF"
        case .annotationFailed: return "Annotation Error"
        case .bookmarkFailed: return "Bookmark Error"
        case .searchFailed: return "Search Error"
        case .loadAnnotationsFailed: return "Annotation Load Error"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The PDF file could not be found"
        case .invalidDocument:
            return "The PDF document is invalid or corrupted"
        case .annotationFailed(let error):
            return "Failed to create annotation: \(error.localizedDescription)"
        case .bookmarkFailed:
            return "Failed to create bookmark"
        case .searchFailed(let error):
            return "Search operation failed: \(error.localizedDescription)"
        case .loadAnnotationsFailed(let error):
            return "Failed to load annotations: \(error.localizedDescription)"
        }
    }
    
    var recoveryAction: String? {
        switch self {
        case .fileNotFound:
            return "Check if the file exists and try again"
        case .invalidDocument:
            return "Try reopening the PDF or check if it's corrupted"
        case .annotationFailed:
            return "Try creating the annotation again"
        case .bookmarkFailed:
            return "Try creating the bookmark again"
        case .searchFailed:
            return "Try searching again with different terms"
        case .loadAnnotationsFailed:
            return "Try reloading the PDF"
        }
    }
}

enum ReferenceError: AppError {
    case importFailed(Error)
    case invalidDOI
    case metadataFetchFailed(Error)
    case duplicateReference
    case citationGenerationFailed
    
    var id: UUID { UUID() }
    
    var title: String {
        switch self {
        case .importFailed: return "Import Error"
        case .invalidDOI: return "Invalid DOI"
        case .metadataFetchFailed: return "Metadata Error"
        case .duplicateReference: return "Duplicate Reference"
        case .citationGenerationFailed: return "Citation Error"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .importFailed(let error):
            return "Failed to import reference: \(error.localizedDescription)"
        case .invalidDOI:
            return "The provided DOI is invalid"
        case .metadataFetchFailed(let error):
            return "Failed to fetch reference metadata: \(error.localizedDescription)"
        case .duplicateReference:
            return "This reference already exists"
        case .citationGenerationFailed:
            return "Failed to generate citation"
        }
    }
    
    var recoveryAction: String? {
        switch self {
        case .importFailed:
            return "Check the import source and try again"
        case .invalidDOI:
            return "Check the DOI and try again"
        case .metadataFetchFailed:
            return "Try fetching metadata again or enter manually"
        case .duplicateReference:
            return "Use the existing reference or modify the new one"
        case .citationGenerationFailed:
            return "Check citation style and try again"
        }
    }
}

enum CoreError: AppError {
    case fileNotFound(String)
    case fileReadError(String, Error?)
    case directoryCreationFailed(String, Error?)
    case exportFailed(String, Error?)
    case general(String, Error? = nil)
    case unknown
    case versionCreationError(String)
    case versionLoadError(String)
    case databaseError(Error)
    case invalidData
    case chatServiceError(String)
    case chatConnectionError(String)
    case chatResponseError(String)
    case chatRequestEncodingError(Error)
    case pdfTextExtractionFailed
    case pdfSummarizationFailed
    case pdfLoadFailed(Error?)

    var id: UUID { UUID() }

    var title: String {
        switch self {
        case .fileNotFound: return "File Not Found"
        case .fileReadError: return "File Read Error"
        case .directoryCreationFailed: return "Directory Creation Failed"
        case .exportFailed: return "Export Failed"
        case .general: return "General Error"
        case .unknown: return "Unknown Error"
        case .versionCreationError: return "Version Creation Error"
        case .versionLoadError: return "Version Load Error"
        case .databaseError: return "Database Error"
        case .invalidData: return "Invalid Data"
        case .chatServiceError: return "Chat Service Error"
        case .chatConnectionError: return "Chat Connection Error"
        case .chatResponseError: return "Chat Response Error"
        case .chatRequestEncodingError: return "Chat Request Encoding Error"
        case .pdfTextExtractionFailed: return "PDF Text Extraction Failed"
        case .pdfSummarizationFailed: return "PDF Summarization Failed"
        case .pdfLoadFailed: return "PDF Load Failed"
        }
    }

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .fileReadError(let path, let underlyingError):
            var message = "Failed to read file at path: \(path)."
            if let underlyingError {
                message += " System error: \(underlyingError.localizedDescription)"
            }
            return message
        case .directoryCreationFailed(let path, let underlyingError):
            var message = "Failed to create directory at path: \(path)."
            if let underlyingError {
                message += " System error: \(underlyingError.localizedDescription)"
            }
            return message
        case .exportFailed(let format, let underlyingError):
            var message = "Export to \(format) failed."
            if let underlyingError {
                message += " System error: \(underlyingError.localizedDescription)"
            }
            return message
        case .general(let message, let underlyingError):
            var fullMessage = message
            if let underlyingError {
                fullMessage += " System error: \(underlyingError.localizedDescription)"
            }
            return fullMessage
        case .unknown:
            return "An unknown error occurred."
        case .versionCreationError(let message):
            return "Failed to create document version: \(message)"
        case .versionLoadError(let message):
            return "Failed to load document version: \(message)"
        case .databaseError(let error):
            return "A database error occurred: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data encountered."
        case .chatServiceError(let message):
            return "Chat service error: \(message)"
        case .chatConnectionError(let message):
            return "Chat connection error: \(message)"
        case .chatResponseError(let message):
            return "Chat response error: \(message)"
        case .chatRequestEncodingError(let error):
            return "Chat request encoding error: \(error.localizedDescription)"
        case .pdfTextExtractionFailed:
            return "Failed to extract text from the PDF. The PDF might be image-based or corrupted."
        case .pdfSummarizationFailed:
            return "Failed to generate an offline summary for the PDF."
        case .pdfLoadFailed(let underlyingError):
            var message = "Failed to load PDF document."
            if let underlyingError {
                message += " System error: \(underlyingError.localizedDescription)"
            }
            return message
        }
    }

    var recoveryAction: String? {
        switch self {
        case .chatConnectionError, .chatServiceError:
            return "Try again"
        case .pdfTextExtractionFailed, .pdfSummarizationFailed, .pdfLoadFailed:
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Error Handler
@MainActor
class ErrorHandler: ObservableObject {
    @Published var currentError: (any AppError)? {
        didSet {
            isShowingError = currentError != nil
        }
    }
    @Published var isShowingError = false
    
    func handle(_ error: any AppError) {
        currentError = error
    }
    
    func dismiss() {
        currentError = nil
    }
}

// MARK: - ViewModifier for Error Handling
struct ErrorHandling: ViewModifier {
    @StateObject private var errorHandler = ErrorHandler()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(errorHandler)
            .alert(
                errorHandler.currentError?.title ?? "",
                isPresented: $errorHandler.isShowingError,
                presenting: errorHandler.currentError
            ) { error in
                Button("OK") {
                    errorHandler.dismiss()
                }
                if error.recoveryAction != nil {
                    Button("Try Again") {
                        errorHandler.dismiss()
                    }
                }
            } message: { error in
                VStack(alignment: .leading) {
                    Text(error.errorDescription ?? "")
                    if let recovery = error.recoveryAction {
                        Text(recovery)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorHandling())
    }
}
