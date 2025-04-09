import XCTest
@testable import AcademiaFlow

@MainActor
final class ErrorHandlingTests: XCTestCase {
    var errorHandler: ErrorHandler!
    
    override func setUp() async throws {
        errorHandler = ErrorHandler()
    }
    
    override func tearDown() async throws {
        errorHandler = nil
    }
    
    // MARK: - ErrorHandler Tests
    func testErrorHandlerInitialState() {
        XCTAssertNil(errorHandler.currentError, "ErrorHandler should initialize with no error")
        XCTAssertFalse(errorHandler.isShowingError, "ErrorHandler should initialize with isShowingError as false")
    }
    
    func testErrorHandling() {
        // Test DocumentError
        let documentError = DocumentError.saveFailure(NSError(domain: "test", code: -1))
        errorHandler.handle(documentError)
        
        XCTAssertNotNil(errorHandler.currentError, "currentError should not be nil after handling error")
        XCTAssertTrue(errorHandler.isShowingError, "isShowingError should be true after handling error")
        XCTAssertEqual(errorHandler.currentError?.title, "Save Error", "Error title should match")
        
        errorHandler.dismiss()
        XCTAssertNil(errorHandler.currentError, "currentError should be nil after dismissal")
        XCTAssertFalse(errorHandler.isShowingError, "isShowingError should be false after dismissal")
    }
    
    // MARK: - Document Error Tests
    func testDocumentErrorCases() {
        let testError = NSError(domain: "test", code: -1)
        
        // Test all DocumentError cases
        let saveError = DocumentError.saveFailure(testError)
        XCTAssertEqual(saveError.title, "Save Error")
        XCTAssertNotNil(saveError.errorDescription)
        XCTAssertNotNil(saveError.recoveryAction)
        
        let loadError = DocumentError.loadFailure(testError)
        XCTAssertEqual(loadError.title, "Load Error")
        XCTAssertNotNil(loadError.errorDescription)
        XCTAssertNotNil(loadError.recoveryAction)
        
        let versionError = DocumentError.versionCreationFailed(testError)
        XCTAssertEqual(versionError.title, "Version Error")
        XCTAssertNotNil(versionError.errorDescription)
        XCTAssertNotNil(versionError.recoveryAction)
    }
    
    // MARK: - PDF Error Tests
    func testPDFErrorCases() {
        let testError = NSError(domain: "test", code: -1)
        
        // Test all PDFError cases
        let fileNotFoundError = PDFError.fileNotFound
        XCTAssertEqual(fileNotFoundError.title, "File Not Found")
        XCTAssertNotNil(fileNotFoundError.errorDescription)
        XCTAssertNotNil(fileNotFoundError.recoveryAction)
        
        let invalidDocError = PDFError.invalidDocument
        XCTAssertEqual(invalidDocError.title, "Invalid PDF")
        XCTAssertNotNil(invalidDocError.errorDescription)
        XCTAssertNotNil(invalidDocError.recoveryAction)
        
        let annotationError = PDFError.annotationFailed(testError)
        XCTAssertEqual(annotationError.title, "Annotation Error")
        XCTAssertNotNil(annotationError.errorDescription)
        XCTAssertNotNil(annotationError.recoveryAction)
    }
    
    // MARK: - Reference Error Tests
    func testReferenceErrorCases() {
        let testError = NSError(domain: "test", code: -1)
        
        // Test all ReferenceError cases
        let importError = ReferenceError.importFailed(testError)
        XCTAssertEqual(importError.title, "Import Error")
        XCTAssertNotNil(importError.errorDescription)
        XCTAssertNotNil(importError.recoveryAction)
        
        let doiError = ReferenceError.invalidDOI
        XCTAssertEqual(doiError.title, "Invalid DOI")
        XCTAssertNotNil(doiError.errorDescription)
        XCTAssertNotNil(doiError.recoveryAction)
        
        let metadataError = ReferenceError.metadataFetchFailed(testError)
        XCTAssertEqual(metadataError.title, "Metadata Error")
        XCTAssertNotNil(metadataError.errorDescription)
        XCTAssertNotNil(metadataError.recoveryAction)
    }
    
    // MARK: - Error View Modifier Tests
    func testErrorHandlingViewModifier() async {
        let errorHandler = ErrorHandler()
        let documentError = DocumentError.saveFailure(NSError(domain: "test", code: -1))
        
        // Test error handling through view modifier
        let expectation = XCTestExpectation(description: "Error should be handled")
        
        await MainActor.run {
            errorHandler.handle(documentError)
            XCTAssertNotNil(errorHandler.currentError)
            XCTAssertTrue(errorHandler.isShowingError)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Multiple Error Handling Tests
    func testMultipleErrorHandling() {
        // Test handling multiple errors in sequence
        let error1 = DocumentError.saveFailure(NSError(domain: "test", code: 1))
        let error2 = PDFError.fileNotFound
        let error3 = ReferenceError.invalidDOI
        
        errorHandler.handle(error1)
        XCTAssertEqual(errorHandler.currentError?.title, "Save Error")
        
        errorHandler.handle(error2)
        XCTAssertEqual(errorHandler.currentError?.title, "File Not Found")
        
        errorHandler.handle(error3)
        XCTAssertEqual(errorHandler.currentError?.title, "Invalid DOI")
        
        errorHandler.dismiss()
        XCTAssertNil(errorHandler.currentError)
        XCTAssertFalse(errorHandler.isShowingError)
    }
    
    // MARK: - Error Recovery Tests
    func testErrorRecoveryActions() {
        let errors: [any AppError] = [
            DocumentError.saveFailure(NSError(domain: "test", code: -1)),
            PDFError.fileNotFound,
            ReferenceError.invalidDOI
        ]
        
        for error in errors {
            errorHandler.handle(error)
            XCTAssertNotNil(errorHandler.currentError?.recoveryAction, "All errors should have recovery actions")
            errorHandler.dismiss()
        }
    }
}

// MARK: - Test Helpers
extension ErrorHandlingTests {
    func assertError(_ error: any AppError, hasTitle title: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(error.title, title, "Error title mismatch", file: file, line: line)
        XCTAssertNotNil(error.errorDescription, "Error should have description", file: file, line: line)
        XCTAssertNotNil(error.recoveryAction, "Error should have recovery action", file: file, line: line)
    }
}