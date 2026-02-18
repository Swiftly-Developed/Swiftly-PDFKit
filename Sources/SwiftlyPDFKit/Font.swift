import CoreText
import CoreGraphics

// MARK: - Font

public struct PDFFont: Sendable {
    public let name: String

    public static let helvetica = PDFFont(name: "Helvetica")
    public static let helveticaBold = PDFFont(name: "Helvetica-Bold")
    public static let helveticaOblique = PDFFont(name: "Helvetica-Oblique")
    public static let helveticaBoldOblique = PDFFont(name: "Helvetica-BoldOblique")
    public static let times = PDFFont(name: "Times-Roman")
    public static let timesBold = PDFFont(name: "Times-Bold")
    public static let timesItalic = PDFFont(name: "Times-Italic")
    public static let courier = PDFFont(name: "Courier")
    public static let courierBold = PDFFont(name: "Courier-Bold")

    public init(name: String) {
        self.name = name
    }

    func ctFont(size: CGFloat, bold: Bool, italic: Bool) -> CTFont {
        // Derive bold/italic variant name from the base name when modifiers are requested
        var resolvedName = name
        if bold || italic {
            let isBold = bold || name.contains("Bold")
            let isItalic = italic || name.contains("Oblique") || name.contains("Italic")
            if name.hasPrefix("Helvetica") {
                switch (isBold, isItalic) {
                case (true, true):  resolvedName = "Helvetica-BoldOblique"
                case (true, false): resolvedName = "Helvetica-Bold"
                case (false, true): resolvedName = "Helvetica-Oblique"
                default: break
                }
            } else if name.hasPrefix("Times") {
                switch (isBold, isItalic) {
                case (true, true):  resolvedName = "Times-BoldItalic"
                case (true, false): resolvedName = "Times-Bold"
                case (false, true): resolvedName = "Times-Italic"
                default: break
                }
            } else if name.hasPrefix("Courier") {
                switch (isBold, isItalic) {
                case (true, _): resolvedName = "Courier-Bold"
                default: break
                }
            }
        }
        return CTFontCreateWithName(resolvedName as CFString, size, nil)
    }
}
