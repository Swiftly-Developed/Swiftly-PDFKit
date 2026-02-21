import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif

// MARK: - ImageContent

/// Draws an image from a file path or raw CGImage, scaled to fit within a given width
/// while preserving aspect ratio.
public struct ImageContent: PDFContent {
    #if canImport(CoreGraphics)
    let cgImage: CGImage
    #endif
    let filePath: String?
    let maxWidth: CGFloat
    let maxHeight: CGFloat?
    let alignment: TextAlignment
    /// Cached natural dimensions (width, height) so both backends can compute layout.
    private let naturalWidth: CGFloat
    private let naturalHeight: CGFloat

    #if canImport(CoreGraphics)
    public init(cgImage: CGImage, maxWidth: CGFloat, maxHeight: CGFloat? = nil, alignment: TextAlignment = .leading) {
        self.cgImage = cgImage
        self.filePath = nil
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment
        self.naturalWidth = CGFloat(cgImage.width)
        self.naturalHeight = CGFloat(cgImage.height)
    }
    #endif

    /// Loads an image from a file path. Returns nil if the file can't be read.
    public init?(path: String, maxWidth: CGFloat, maxHeight: CGFloat? = nil, alignment: TextAlignment = .leading) {
        self.filePath = path
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment

        #if canImport(ImageIO)
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return nil }
        self.cgImage = img
        self.naturalWidth = CGFloat(img.width)
        self.naturalHeight = CGFloat(img.height)
        #else
        // On Linux, try to read image dimensions from file header.
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let dims = ImageContent.readImageDimensions(path: path)
        self.naturalWidth = dims.width
        self.naturalHeight = dims.height
        #endif
    }

    /// Compute the draw dimensions respecting maxWidth and maxHeight.
    private var drawSize: (w: CGFloat, h: CGFloat) {
        guard naturalWidth > 0, naturalHeight > 0 else { return (0, 0) }
        var drawW = min(maxWidth, naturalWidth)
        var drawH = naturalHeight * (drawW / naturalWidth)
        if let maxH = maxHeight, drawH > maxH {
            drawH = maxH
            drawW = naturalWidth * (drawH / naturalHeight)
        }
        return (drawW, drawH)
    }

    // MARK: CoreGraphics Rendering

    #if canImport(CoreGraphics)
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        guard naturalWidth > 0, naturalHeight > 0 else { return }
        let (drawW, drawH) = drawSize

        let xOffset: CGFloat
        switch alignment {
        case .leading:  xOffset = bounds.minX
        case .center:   xOffset = bounds.minX + (bounds.width - drawW) / 2
        case .trailing: xOffset = bounds.maxX - drawW
        }

        let rect = CGRect(x: xOffset, y: cursor - drawH, width: drawW, height: drawH)
        context.draw(cgImage, in: rect)
        cursor -= drawH
    }
    #endif

    // MARK: HTML Rendering

    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String {
        let (drawW, drawH) = drawSize
        guard drawW > 0, drawH > 0 else { return "" }

        // Read file and base64-encode
        guard let path = filePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return "" }
        let base64 = data.base64EncodedString()
        let ext = (path as NSString).pathExtension.lowercased()
        let mime = (ext == "png") ? "image/png" : "image/jpeg"

        let alignCSS: String
        switch alignment {
        case .leading:  alignCSS = ""
        case .center:   alignCSS = "margin-left:auto;margin-right:auto;"
        case .trailing: alignCSS = "margin-left:auto;"
        }

        cursor -= drawH
        return """
        <img src="data:\(mime);base64,\(base64)" \
        style="display:block;width:\(drawW)pt;height:\(drawH)pt;\(alignCSS)">
        """
    }

    // MARK: Linux image dimension reader

    /// Reads width/height from PNG or JPEG file headers without ImageIO.
    private static func readImageDimensions(path: String) -> (width: CGFloat, height: CGFloat) {
        guard let fh = FileHandle(forReadingAtPath: path) else { return (100, 100) }
        defer { fh.closeFile() }
        let header = fh.readData(ofLength: 32)
        guard header.count >= 24 else { return (100, 100) }

        // PNG: bytes 16-19 = width, 20-23 = height (big-endian)
        if header[0] == 0x89 && header[1] == 0x50 {
            let w = header.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let h = header.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            return (CGFloat(w), CGFloat(h))
        }

        // JPEG: search for SOF0 marker (0xFF 0xC0)
        fh.seek(toFileOffset: 0)
        let jpegData = fh.readData(ofLength: 65536)
        for i in 0..<(jpegData.count - 9) {
            if jpegData[i] == 0xFF && jpegData[i + 1] == 0xC0 {
                let h = UInt16(jpegData[i + 5]) << 8 | UInt16(jpegData[i + 6])
                let w = UInt16(jpegData[i + 7]) << 8 | UInt16(jpegData[i + 8])
                return (CGFloat(w), CGFloat(h))
            }
        }

        return (100, 100) // fallback
    }
}
