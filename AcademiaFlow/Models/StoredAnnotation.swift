import SwiftUI
import SwiftData
import PDFKit

// Sendable snapshot struct
struct StoredAnnotationSnapshot: Sendable {
    let id: String
    let pageIndex: Int
    let type: String
    let color: String
    let contents: String?
    let bounds: [Double]
    let createdAt: Date
    let lastModified: Date
    let category: String?
    let tags: [String]
    let isHidden: Bool
}

@Model
final class StoredAnnotation {
    @Attribute(.unique) var id: String
    var pageIndex: Int
    var type: String
    var color: String
    var contents: String?
    var boundsX: Double
    var boundsY: Double
    var boundsWidth: Double
    var boundsHeight: Double
    var createdAt: Date
    var pdf: PDF?
    
    // CHANGE: Make new properties optional or provide default values
    var category: String?
    var lastModified: Date?  // Make optional
    var isHidden: Bool = false // Default value
    var tags: [String] = []   // Default empty array
    
    // Add computed property for bounds array
    var bounds: [Double] {
        [boundsX, boundsY, boundsWidth, boundsHeight]
    }
    
    // Update init to handle optional lastModified
    init(pageIndex: Int, type: String, color: String, contents: String? = nil, bounds: [Double], pdf: PDF? = nil, category: String? = nil, tags: [String] = []) {
        self.id = UUID().uuidString
        self.pageIndex = pageIndex
        self.type = type
        self.color = color
        self.contents = contents
        self.boundsX = bounds[safe: 0] ?? 0
        self.boundsY = bounds[safe: 1] ?? 0
        self.boundsWidth = bounds[safe: 2] ?? 0
        self.boundsHeight = bounds[safe: 3] ?? 0
        self.createdAt = Date()
        self.lastModified = Date()  // Set initial value
        self.pdf = pdf
        self.category = category
        self.tags = tags
        self.isHidden = false
    }
    
    // Add convenience initializer for creating from snapshot
    convenience init(from snapshot: StoredAnnotationSnapshot, pdf: PDF? = nil) {
        self.init(
            pageIndex: snapshot.pageIndex,
            type: snapshot.type,
            color: snapshot.color,
            contents: snapshot.contents,
            bounds: snapshot.bounds,
            pdf: pdf,
            category: snapshot.category,
            tags: snapshot.tags
        )
        self.id = snapshot.id
        self.createdAt = snapshot.createdAt
        self.lastModified = snapshot.lastModified
        self.isHidden = snapshot.isHidden
    }
    
    var snapshot: StoredAnnotationSnapshot {
        StoredAnnotationSnapshot(
            id: id,
            pageIndex: pageIndex,
            type: type,
            color: color,
            contents: contents,
            bounds: bounds,
            createdAt: createdAt,
            lastModified: lastModified ?? createdAt,  // Use createdAt as fallback
            category: category,
            tags: tags,
            isHidden: isHidden
        )
    }
    
    // Rest of the implementation remains the same...
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
        let rect = NSRect(x: boundsX,
                          y: boundsY,
                          width: boundsWidth,
                          height: boundsHeight)
        
        let annotation = PDFAnnotation(bounds: rect,
                                       forType: PDFAnnotationSubtype(rawValue: annotationType),
                                       withProperties: nil)
        
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
