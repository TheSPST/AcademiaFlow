import SwiftUI
import AppKit

struct AnnotationColorPicker: View {
    @Binding var color: Color
    
    var body: some View {
        ColorPicker("Annotation Color", selection: $color)
    }
}