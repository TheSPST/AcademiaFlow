import SwiftUI
import PDFKit
import AppKit

struct AnnotationEditor: View {
    let annotation: PDFAnnotation
    let onUpdate: (NSColor?, String?) -> Void
    let onDone: () -> Void
    @State private var contents: String
    @State private var color: Color
    
    init(annotation: PDFAnnotation, onUpdate: @escaping (NSColor?, String?) -> Void, onDone: @escaping () -> Void) {
        self.annotation = annotation
        self.onUpdate = onUpdate
        self.onDone = onDone
        self._contents = State(initialValue: annotation.contents ?? "")
        self._color = State(initialValue: Color(annotation.color))
    }
    
    var body: some View {
        HStack {
            ColorPicker("Color", selection: $color)
                .onChange(of: color) { _, newValue in
                    onUpdate(NSColor(newValue), nil)
                }
            
            if annotation.type == PDFAnnotationSubtype.text.rawValue {
                TextField("Note", text: $contents)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: contents) { _, newValue in
                        onUpdate(nil, newValue)
                    }
            }
            
            Button("Done", action: onDone)
        }
        .padding(.horizontal)
        .transition(.move(edge: .top))
    }
}