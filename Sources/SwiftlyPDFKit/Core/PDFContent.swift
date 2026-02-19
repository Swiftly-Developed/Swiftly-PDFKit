import Foundation
import CoreGraphics
import CoreText
import CoreFoundation

// MARK: - TextAlignment

public enum TextAlignment: Sendable {
    case leading
    case center
    case trailing
}

// MARK: - PDFContent protocol

/// A piece of renderable content. `cursor` starts near the top of the content
/// area (high y in CG coordinates) and decreases as items are drawn.
public protocol PDFContent {
    func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat)
}

// MARK: - Text

public struct Text: PDFContent {
    let string: String
    var fontFace: PDFFont = .helvetica
    var fontSize: CGFloat = 16
    var isBold: Bool = false
    var isItalic: Bool = false
    var textColor: CGColor = CGColor(gray: 0, alpha: 1)
    var alignment: TextAlignment = .leading

    public init(_ string: String) {
        self.string = string
    }

    // MARK: Modifiers

    public func font(_ face: PDFFont, size: CGFloat) -> Text {
        var copy = self; copy.fontFace = face; copy.fontSize = size; return copy
    }

    public func bold() -> Text {
        var copy = self; copy.isBold = true; return copy
    }

    public func italic() -> Text {
        var copy = self; copy.isItalic = true; return copy
    }

    public func foregroundColor(_ color: CGColor) -> Text {
        var copy = self; copy.textColor = color; return copy
    }

    public func foregroundColor(_ color: PDFColor) -> Text {
        foregroundColor(color.cgColor)
    }

    public func fontSize(_ size: CGFloat) -> Text {
        var copy = self; copy.fontSize = size; return copy
    }

    public func alignment(_ a: TextAlignment) -> Text {
        var copy = self; copy.alignment = a; return copy
    }

    // MARK: Rendering

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        drawText(string, in: context, bounds: bounds, cursor: &cursor,
                 font: fontFace.ctFont(size: fontSize, bold: isBold, italic: isItalic),
                 color: textColor, alignment: alignment)
    }
}

// MARK: - Shared text drawing helper

/// Draws a string into `context`, updating `cursor`. Returns the new cursor value.
@discardableResult
func drawText(
    _ string: String,
    in context: CGContext,
    bounds: CGRect,
    cursor: inout CGFloat,
    font: CTFont,
    color: CGColor,
    alignment: TextAlignment = .leading
) -> CGFloat {
    let ctAlignment: CTTextAlignment = {
        switch alignment {
        case .leading:  return .left
        case .center:   return .center
        case .trailing: return .right
        }
    }()

    let paraStyle: CTParagraphStyle = withUnsafeBytes(of: ctAlignment) { ptr in
        var setting = CTParagraphStyleSetting(
            spec: .alignment,
            valueSize: MemoryLayout<CTTextAlignment>.size,
            value: ptr.baseAddress!
        )
        return CTParagraphStyleCreate(&setting, 1)
    }

    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color,
        kCTParagraphStyleAttributeName: paraStyle,
    ]
    let attributed = CFAttributedStringCreate(nil, string as CFString, attributes as CFDictionary)!
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)

    let frameRect = CGRect(x: bounds.minX, y: bounds.minY,
                           width: bounds.width, height: cursor - bounds.minY)
    let path = CGPath(rect: frameRect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)

    let lines = CTFrameGetLines(frame) as! [CTLine]
    guard !lines.isEmpty else { return cursor }

    for line in lines {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        let baseline = cursor - ascent

        // For alignment, compute pen position
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let x: CGFloat
        switch alignment {
        case .leading:  x = bounds.minX
        case .center:   x = bounds.minX + (bounds.width - lineWidth) / 2
        case .trailing: x = bounds.maxX - lineWidth
        }

        context.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(line, context)
        cursor = baseline - descent - max(leading, 2)
    }
    return cursor
}

// MARK: - Spacer

public struct Spacer: PDFContent {
    let height: CGFloat

    public init(height: CGFloat = 12) {
        self.height = height
    }

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        cursor -= height
    }
}

// MARK: - HRule

public struct HRule: PDFContent {
    let thickness: CGFloat
    let color: CGColor

    public init(thickness: CGFloat = 0.5, color: CGColor = CGColor(gray: 0, alpha: 1)) {
        self.thickness = thickness
        self.color = color
    }

    public init(thickness: CGFloat = 0.5, color: PDFColor) {
        self.thickness = thickness
        self.color = color.cgColor
    }

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        context.setLineWidth(thickness)
        context.setStrokeColor(color)
        context.move(to: CGPoint(x: bounds.minX, y: cursor))
        context.addLine(to: CGPoint(x: bounds.maxX, y: cursor))
        context.strokePath()
        cursor -= thickness + 4
    }
}
