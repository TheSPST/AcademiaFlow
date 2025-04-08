import SwiftUI
import PDFKit
import AppKit

struct PDFPreviewView: View {
    let url: URL
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        PDFKitView(url: url, isLoading: $isLoading, loadError: $loadError)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if let error = loadError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Failed to load PDF")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
    }
}

struct PDFKitView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: Error?
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Basic setup
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Load PDF
        Task { @MainActor in
            do {
                isLoading = true
                
                // Verify file exists
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw NSError(domain: "PDFViewError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "PDF file not found at path: \(url.path)"])
                }
                
                // Create and configure document
                guard let document = PDFDocument(url: url) else {
                    throw NSError(domain: "PDFViewError",
                                code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Could not create PDF document from file"])
                }
                
                // Set document and configure view
                pdfView.document = document
                pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
                pdfView.maxScaleFactor = 4.0
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                
                // Go to first page
                if let firstPage = document.page(at: 0) {
                    pdfView.go(to: PDFDestination(page: firstPage, at: NSPoint(x: 0, y: firstPage.bounds(for: .mediaBox).size.height)))
                }
                
                print("PDF loaded successfully from: \(url.path)")
                print("Number of pages: \(document.pageCount)")
                print("Scale factor: \(pdfView.scaleFactor)")
                
                isLoading = false
                
            } catch {
                print("PDF loading error: \(error.localizedDescription)")
                print("URL attempting to load: \(url)")
                loadError = error
                isLoading = false
            }
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Configure view bounds if needed
        pdfView.needsDisplay = true
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
        PDFPreviewView(url: url)
    } else {
        Text("No PDF available for preview")
    }
}
