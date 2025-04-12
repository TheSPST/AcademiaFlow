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
    @EnvironmentObject private var errorHandler: ErrorHandler
    
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
        
        // ADD: Magnification gesture recognizer
        let magnificationGesture = NSMagnificationGestureRecognizer(target: context.coordinator,
                                                                   action: #selector(Coordinator.handleMagnification(_:)))
        pdfView.addGestureRecognizer(magnificationGesture)
        
        // Improve scrolling behavior
        if let scrollView = pdfView.enclosingScrollView {
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.scrollerStyle = .legacy
            scrollView.horizontalScrollElasticity = NSScrollView.Elasticity.none
            scrollView.verticalScrollElasticity = NSScrollView.Elasticity.automatic
        }
        viewModel.setPDFView(pdfView)
        viewModel.setupShortcuts()
        Task {
            if let error = await viewModel.loadPDF() {
                errorHandler.handle(error)
            }
        }
        return pdfView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, errorHandler: errorHandler)
    }
    
    func updateNSView(_ pdfView: TrackingPDFView, context: Context) {
//        pdfView.scaleFactor = viewModel.zoomLevel
//        if let document = pdfView.document,
//           let page = document.page(at: viewModel.currentPage - 1) {
//            pdfView.go(to: PDFDestination(page: page, at: NSPoint(x: 0, y: page.bounds(for: .mediaBox).size.height)))
//        }
    }
    
    class Coordinator: NSObject {
        let viewModel: PDFViewModel
        let errorHandler: ErrorHandler
        private var trackingArea: NSTrackingArea?
        
        init(viewModel: PDFViewModel, errorHandler: ErrorHandler) {
            self.viewModel = viewModel
            self.errorHandler = errorHandler
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
        
        // Add magnification handling
        @MainActor @objc func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
            switch gesture.state {
            case .changed:
                viewModel.handlePinchGesture(scale: gesture.magnification + 1)
            case .ended:
                gesture.magnification = 0
            default:
                break
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
