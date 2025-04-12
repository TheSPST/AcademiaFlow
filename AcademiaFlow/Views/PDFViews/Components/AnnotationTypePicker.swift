import SwiftUI

struct AnnotationTypePicker: View {
    @Binding var selection: PDFViewModel.AnnotationType
    
    var body: some View {
        Picker("Annotation Type", selection: $selection) {
            Image(systemName: "highlighter")
                .tag(PDFViewModel.AnnotationType.highlight)
            Image(systemName: "underline")
                .tag(PDFViewModel.AnnotationType.underline)
            Image(systemName: "strikethrough")
                .tag(PDFViewModel.AnnotationType.strikethrough)
            Image(systemName: "note.text")
                .tag(PDFViewModel.AnnotationType.note)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}