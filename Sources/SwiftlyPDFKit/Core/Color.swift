import CoreGraphics

// MARK: - PDFColor

/// A color for use in the PDF DSL. Wraps CGColor with convenient constructors
/// so callers don't need to import CoreGraphics directly.
public struct PDFColor: Sendable {
    public let cgColor: CGColor

    public static let black   = PDFColor(cgColor: CGColor(gray: 0,    alpha: 1))
    public static let white   = PDFColor(cgColor: CGColor(gray: 1,    alpha: 1))
    public static let gray    = PDFColor(cgColor: CGColor(gray: 0.5,  alpha: 1))
    public static let lightGray = PDFColor(cgColor: CGColor(gray: 0.75, alpha: 1))
    public static let darkGray  = PDFColor(cgColor: CGColor(gray: 0.25, alpha: 1))
    public static let red     = PDFColor(red: 1, green: 0, blue: 0)
    public static let green   = PDFColor(red: 0, green: 0.6, blue: 0)
    public static let blue    = PDFColor(red: 0, green: 0.3, blue: 1)

    public init(cgColor: CGColor) {
        self.cgColor = cgColor
    }

    public init(white: CGFloat, alpha: CGFloat = 1) {
        self.cgColor = CGColor(gray: white, alpha: alpha)
    }

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.cgColor = CGColor(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [red, green, blue, alpha]
        )!
    }
}
