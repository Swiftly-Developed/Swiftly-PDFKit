import CoreGraphics
import Foundation
import QRCodeGenerator

// MARK: - QRCodeContent

/// Renders a QR code for the given string at the given size.
public struct QRCodeContent: PDFContent {
    let content: String
    let size: CGFloat
    let alignment: TextAlignment

    public init(_ content: String, size: CGFloat = 80, alignment: TextAlignment = .leading) {
        self.content = content
        self.size = size
        self.alignment = alignment
    }

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        guard let qr = try? QRCode.encode(text: content, ecl: .medium) else { return }

        let moduleCount = CGFloat(qr.size)
        let moduleSize = size / moduleCount

        let xOffset: CGFloat
        switch alignment {
        case .leading:  xOffset = bounds.minX
        case .center:   xOffset = bounds.minX + (bounds.width - size) / 2
        case .trailing: xOffset = bounds.maxX - size
        }

        let originY = cursor - size

        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for row in 0..<qr.size {
            for col in 0..<qr.size {
                if qr.getModule(x: col, y: row) {
                    // QR y=0 is top; CG y=0 is bottom — flip vertically
                    let rect = CGRect(
                        x: xOffset + CGFloat(col) * moduleSize,
                        y: originY + CGFloat(qr.size - 1 - row) * moduleSize,
                        width: moduleSize,
                        height: moduleSize
                    )
                    context.fill(rect)
                }
            }
        }

        cursor -= size
    }
}
