import Foundation
#if canImport(CoreText)
import CoreText
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

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

    /// Resolve the PostScript font name for the requested bold/italic combination.
    func resolvedName(bold: Bool, italic: Bool) -> String {
        var resolved = name
        if bold || italic {
            let isBold = bold || name.contains("Bold")
            let isItalic = italic || name.contains("Oblique") || name.contains("Italic")
            if name.hasPrefix("Helvetica") {
                switch (isBold, isItalic) {
                case (true, true):  resolved = "Helvetica-BoldOblique"
                case (true, false): resolved = "Helvetica-Bold"
                case (false, true): resolved = "Helvetica-Oblique"
                default: break
                }
            } else if name.hasPrefix("Times") {
                switch (isBold, isItalic) {
                case (true, true):  resolved = "Times-BoldItalic"
                case (true, false): resolved = "Times-Bold"
                case (false, true): resolved = "Times-Italic"
                default: break
                }
            } else if name.hasPrefix("Courier") {
                switch (isBold, isItalic) {
                case (true, _): resolved = "Courier-Bold"
                default: break
                }
            }
        }
        return resolved
    }

    /// CSS font-family stack for use in HTML rendering.
    var cssFontFamily: String {
        if name.hasPrefix("Helvetica") { return "Helvetica, Arial, sans-serif" }
        if name.hasPrefix("Times")     { return "'Times New Roman', Times, serif" }
        if name.hasPrefix("Courier")   { return "'Courier New', Courier, monospace" }
        return name
    }

    #if canImport(CoreText)
    func ctFont(size: CGFloat, bold: Bool, italic: Bool) -> CTFont {
        CTFontCreateWithName(resolvedName(bold: bold, italic: italic) as CFString, size, nil)
    }
    #endif
}
