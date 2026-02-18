import CoreGraphics
import Foundation

#if canImport(ImageIO)
import ImageIO
#endif

// MARK: - ImageContent

/// Draws an image from a file path or raw CGImage, scaled to fit within a given width
/// while preserving aspect ratio.
public struct ImageContent: PDFContent {
    let cgImage: CGImage
    let maxWidth: CGFloat
    let maxHeight: CGFloat?
    let alignment: TextAlignment

    public init(cgImage: CGImage, maxWidth: CGFloat, maxHeight: CGFloat? = nil, alignment: TextAlignment = .leading) {
        self.cgImage = cgImage
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment
    }

    /// Loads an image from a file path. Returns nil if the file can't be read.
    public init?(path: String, maxWidth: CGFloat, maxHeight: CGFloat? = nil, alignment: TextAlignment = .leading) {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return nil }
        self.cgImage = img
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment
    }

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        let naturalW = CGFloat(cgImage.width)
        let naturalH = CGFloat(cgImage.height)
        guard naturalW > 0, naturalH > 0 else { return }

        var drawW = min(maxWidth, naturalW)
        var drawH = naturalH * (drawW / naturalW)
        if let maxH = maxHeight, drawH > maxH {
            drawH = maxH
            drawW = naturalW * (drawH / naturalH)
        }

        let xOffset: CGFloat
        switch alignment {
        case .leading:  xOffset = bounds.minX
        case .center:   xOffset = bounds.minX + (bounds.width - drawW) / 2
        case .trailing: xOffset = bounds.maxX - drawW
        }

        let rect = CGRect(x: xOffset, y: cursor - drawH, width: drawW, height: drawH)

        // CG draws images with origin at bottom-left, so no flip needed for PDF context
        context.draw(cgImage, in: rect)
        cursor -= drawH
    }
}
