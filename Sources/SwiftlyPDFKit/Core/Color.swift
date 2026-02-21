import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PDFColor

/// A color for use in the PDF DSL. Stores RGBA components directly for
/// cross-platform compatibility; on Darwin a computed `cgColor` is available.
public struct PDFColor: Sendable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public static let black     = PDFColor(white: 0)
    public static let white     = PDFColor(white: 1)
    public static let gray      = PDFColor(white: 0.5)
    public static let lightGray = PDFColor(white: 0.75)
    public static let darkGray  = PDFColor(white: 0.25)
    public static let red       = PDFColor(red: 1, green: 0, blue: 0)
    public static let green     = PDFColor(red: 0, green: 0.6, blue: 0)
    public static let blue      = PDFColor(red: 0, green: 0.3, blue: 1)

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(white: CGFloat, alpha: CGFloat = 1) {
        self.red = white
        self.green = white
        self.blue = white
        self.alpha = alpha
    }

    /// Cross-platform RGBA component access.
    public var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        (red, green, blue, alpha)
    }

    /// CSS color string, e.g. `"rgb(255,0,0)"` or `"rgba(255,0,0,0.5)"`.
    var cssRGBA: String {
        let r = Int(red * 255), g = Int(green * 255), b = Int(blue * 255)
        if alpha < 1 {
            return "rgba(\(r),\(g),\(b),\(String(format: "%.2f", alpha)))"
        }
        return "rgb(\(r),\(g),\(b))"
    }

    // MARK: - Darwin CGColor interop

    #if canImport(CoreGraphics)
    /// Construct from an existing CGColor (Darwin only).
    public init(cgColor: CGColor) {
        // Convert to sRGB to safely extract components regardless of source colorspace.
        if let rgb = cgColor.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB)!,
                intent: .defaultIntent, options: nil),
           let c = rgb.components, c.count >= 3 {
            self.red = c[0]
            self.green = c[1]
            self.blue = c[2]
            self.alpha = c.count >= 4 ? c[3] : 1
        } else if let c = cgColor.components {
            // Grayscale fallback
            let w = c[0]
            self.red = w
            self.green = w
            self.blue = w
            self.alpha = c.count >= 2 ? c[1] : 1
        } else {
            self.red = 0; self.green = 0; self.blue = 0; self.alpha = 1
        }
    }

    /// Materialise a CGColor from the stored components (Darwin only).
    public var cgColor: CGColor {
        CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [red, green, blue, alpha]
        )!
    }
    #endif
}
