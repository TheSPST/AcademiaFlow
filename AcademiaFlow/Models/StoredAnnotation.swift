import SwiftUI
import SwiftData
import PDFKit

@Model
final class StoredAnnotation {
    @Attribute(.unique) var id: String
    var pageIndex: Int
    var type: String
    var color: String
    var contents: String?
    @Transient var bounds: [Double] = []
    var createdAt: Date
    var pdf: PDF?
    
    init(pageIndex: Int, type: String, color: String, contents: String? = nil, bounds: [Double], pdf: PDF? = nil) {
        self.id = UUID().uuidString
        self.pageIndex = pageIndex
        self.type = type
        self.color = color
        self.contents = contents
        self.bounds = bounds
        self.createdAt = Date()
        self.pdf = pdf
    }
    
    var annotationType: String {
        switch type {
        case "highlight": return PDFAnnotationSubtype.highlight.rawValue
        case "underline": return PDFAnnotationSubtype.underline.rawValue
        case "strikethrough": return PDFAnnotationSubtype.strikeOut.rawValue
        case "note": return PDFAnnotationSubtype.text.rawValue
        default: return PDFAnnotationSubtype.highlight.rawValue
        }
    }
    
    var nsColor: NSColor {
        NSColor(hex: color) ?? .yellow
    }
    
    func toPDFAnnotation() -> PDFAnnotation {
        let rect = NSRect(x: bounds[safe: 0] ?? 0,
                          y: bounds[safe: 1] ?? 0,
                          width: bounds[safe: 2] ?? 0,
                          height: bounds[safe: 3] ?? 0)
        let annotation = PDFAnnotation(bounds: rect, forType: PDFAnnotationSubtype(rawValue: annotationType), withProperties: nil)
        annotation.color = nsColor
        annotation.contents = contents
        return annotation
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
extension NSColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        return nil
    }
    
    func toHex() -> String {
        // Convert to RGB color space first
        guard let rgbColor = usingColorSpace(.deviceRGB) else {
            return "#00000000"
        }
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<24 | (Int)(g*255)<<16 |
                      (Int)(b*255)<<8 | (Int)(a*255)
        return String(format: "#%08x", rgb)
    }
}
