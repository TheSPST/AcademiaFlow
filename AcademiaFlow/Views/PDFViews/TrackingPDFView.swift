//
//  TrackingPDFView.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 09/04/25.
//

import SwiftUI
import PDFKit

class TrackingPDFView: PDFView {
    weak var coordinator: PDFKitView.Coordinator?
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        handleMouseMovement(event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        handleMouseMovement(event)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        Task { @MainActor in
            coordinator?.viewModel.annotationPreviewActive = false
        }
    }
    
    @MainActor
    private func handleMouseMovement(_ event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        
        Task { @MainActor in
            if let currentPage = self.page(for: location, nearest: true) {
                let annotations = currentPage.annotations
                if let _ = annotations.first(where: { $0.bounds.contains(location) }) {
                    coordinator?.viewModel.annotationPreviewActive = true
                } else {
                    coordinator?.viewModel.annotationPreviewActive = false
                }
            }
        }
    }
}
