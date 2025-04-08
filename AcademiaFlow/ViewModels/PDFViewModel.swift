import SwiftUI
import PDFKit

@MainActor
class PDFViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var loadError: Error?
    @Published var selectedPage: PDFPage?
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var zoomLevel: CGFloat = 1.0
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var currentSearchResult = 0
    @Published var totalSearchResults = 0
    
    private var searchResults: [PDFSelection] = []
    private weak var pdfView: PDFView?
    private let pdf: PDF
    
    init(pdf: PDF) {
        self.pdf = pdf
    }
    
    func setPDFView(_ view: PDFView) {
        self.pdfView = view
    }
    
    func loadPDF() async {
        do {
            isLoading = true
            
            guard FileManager.default.fileExists(atPath: pdf.fileURL.path) else {
                throw PDFError.fileNotFound
            }
            
            guard let document = PDFDocument(url: pdf.fileURL) else {
                throw PDFError.invalidDocument
            }
            
            pdfView?.document = document
            totalPages = document.pageCount
            
            setupInitialView()
            isLoading = false
            
        } catch {
            loadError = error
            isLoading = false
        }
    }
    
    private func setupInitialView() {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              let firstPage = document.page(at: 0) else { return }
        
        pdfView.autoScales = true
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = 0.25
        pdfView.go(to: PDFDestination(page: firstPage, at: NSPoint(x: 0, y: firstPage.bounds(for: .mediaBox).size.height)))
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        self.zoomLevel = pdfView.scaleFactor
    }
    
    func performSearch() {
        guard let pdfView = pdfView,
              let document = pdfView.document else { return }
        
        searchResults.removeAll()
        currentSearchResult = 0
        totalSearchResults = 0
        
        if searchText.isEmpty {
            isSearching = false
            return
        }
        
        isSearching = true
        
        if let selection = document.findString(searchText, withOptions: .caseInsensitive).first {
            searchResults = [selection]
            
            var lastSelection = selection
            while let nextSelection = document.findString(searchText, fromSelection: lastSelection, withOptions: .caseInsensitive) {
                searchResults.append(nextSelection)
                lastSelection = nextSelection
            }
            
            totalSearchResults = searchResults.count
            if !searchResults.isEmpty {
                currentSearchResult = 1
                highlightCurrentSelection()
            }
        }
    }
    
    private func highlightCurrentSelection() {
        guard currentSearchResult > 0,
              currentSearchResult <= searchResults.count,
              let pdfView = pdfView else { return }
        
        let selection = searchResults[currentSearchResult - 1]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.scrollSelectionToVisible(nil)
        
        if let page = selection.pages.first {
            currentPage = pdfView.document?.index(for: page) ?? 0 + 1
        }
    }
    
    func nextSearchResult() {
        if currentSearchResult < totalSearchResults {
            currentSearchResult += 1
        } else {
            currentSearchResult = 1
        }
        highlightCurrentSelection()
    }
    
    func previousSearchResult() {
        if currentSearchResult > 1 {
            currentSearchResult -= 1
        } else {
            currentSearchResult = totalSearchResults
        }
        highlightCurrentSelection()
    }
    
    func handlePageClick() {
        guard let pdfView = pdfView,
              let currentPage = pdfView.currentPage else { return }
        
        selectedPage = currentPage
        if let pageNum = currentPage.pageRef?.pageNumber {
            self.currentPage = pageNum
        }
    }
    
    // MARK: - Zoom Controls
    
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.25, 4.0)
        pdfView?.scaleFactor = zoomLevel
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.25, 0.25)
        pdfView?.scaleFactor = zoomLevel
    }
    
    func resetZoom() {
        zoomLevel = 1.0
        pdfView?.scaleFactor = zoomLevel
    }
    
    func fitToWidth() {
        guard let pdfView = pdfView else { return }
        zoomLevel = pdfView.scaleFactorForSizeToFit
        pdfView.scaleFactor = zoomLevel
    }
    
    // MARK: - Page Navigation
    
    func goToNextPage() {
        if currentPage < totalPages {
            currentPage += 1
            navigateToPage(currentPage - 1)
        }
    }
    
    func goToPreviousPage() {
        if currentPage > 1 {
            currentPage -= 1
            navigateToPage(currentPage - 1)
        }
    }
    
    private func navigateToPage(_ pageIndex: Int) {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              let page = document.page(at: pageIndex) else { return }
        
        pdfView.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).size.height)))
    }
}

enum PDFError: LocalizedError {
    case fileNotFound
    case invalidDocument
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PDF file not found"
        case .invalidDocument:
            return "Could not create PDF document from file"
        }
    }
}
