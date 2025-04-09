//
//  PDFKitView.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 09/04/25.
//
import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    @ObservedObject var viewModel: PDFViewModel
    
    func makeNSView(context: Context) -> TrackingPDFView {
        let pdfView = TrackingPDFView()
        pdfView.coordinator = context.coordinator
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Add click gesture recognizer
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        pdfView.addGestureRecognizer(clickGesture)
        
        viewModel.setPDFView(pdfView)
        viewModel.setupShortcuts()
        
        Task {
            await viewModel.loadPDF()
        }
        
        return pdfView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    func updateNSView(_ pdfView: TrackingPDFView, context: Context) {
        pdfView.scaleFactor = viewModel.zoomLevel
        
        if let document = pdfView.document,
           let page = document.page(at: viewModel.currentPage - 1) {
            pdfView.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).size.height)))
        }
    }
    
    class Coordinator: NSObject {
        let viewModel: PDFViewModel
        private var trackingArea: NSTrackingArea?
        
        init(viewModel: PDFViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        @MainActor
        func setupTracking(for view: NSView) {
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways]
            let trackingArea = NSTrackingArea(rect: view.bounds, options: options, owner: view, userInfo: nil)
            view.addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
        }
        
        @MainActor
        func updateTrackingArea(for view: NSView) {
            if let oldTrackingArea = trackingArea {
                view.removeTrackingArea(oldTrackingArea)
            }
            setupTracking(for: view)
        }
        
        @MainActor @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else {
                return
            }
            
            let location = gesture.location(in: pdfView)
            if let currentPage = pdfView.page(for: location, nearest: true) {
                let annotations = currentPage.annotations
                if let annotation = annotations.first(where: { $0.bounds.contains(location) }) {
                    viewModel.selectAnnotation(annotation)
                } else {
                    viewModel.handlePageClick()
                }
            }
        }
    }
}
extension PDFKitView.Coordinator: NSMenuDelegate {
    @MainActor
    func mouseEntered(with event: NSEvent) {
        updateAnnotationPreview(with: event)
    }
    
    @MainActor
    func mouseMoved(with event: NSEvent) {
        updateAnnotationPreview(with: event)
    }
    
    @MainActor
    func mouseExited(with event: NSEvent) {
        Task { @MainActor in
            viewModel.annotationPreviewActive = false
        }
    }
    
    @MainActor
    private func updateAnnotationPreview(with event: NSEvent) {
        guard let pdfView = event.window?.contentView?.hitTest(event.locationInWindow) as? PDFView else { return }
        let location = pdfView.convert(event.locationInWindow, from: nil)
        
        Task { @MainActor in
            if let currentPage = pdfView.page(for: location, nearest: true) {
                let annotations = currentPage.annotations
                if let _ = annotations.first(where: { $0.bounds.contains(location) }) {
                    viewModel.annotationPreviewActive = true
                } else {
                    viewModel.annotationPreviewActive = false
                }
            }
        }
    }
}
