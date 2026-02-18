# SwiftlyPDFKit — Claude Context

## Project overview
A Swift DSL for generating PDFs using result builders, inspired by SwiftUI's declarative syntax. Targets macOS, iOS, and Linux (Vapor). Uses CoreGraphics directly — no dependency on the PDFKit framework.

## Package structure
```
Sources/
├── SwiftlyPDFKit/     # The library
└── HelloWorldPDF/     # Example executable (invoice demo)
```

## Key DSL types

### Entry point
- `PDF { Page... }` — top-level document; `.render() -> Data`, `.write(to: URL)`

### Page
- `Page(size: .a4/.letter/.legal, margins: CGFloat) { content... }`
- `Footer(height:) { content... }` — pinned to page bottom; place inside Page

### Layout
- `Columns(spacing:) { ColumnItem(width: .flex/.fixed(n)) { content... } }` — horizontal layout
- `ContentBuilder` — shared `@resultBuilder` for all content blocks

### Text & typography
- `Text("string")` with modifiers:
  - `.font(_ face: PDFFont, size: CGFloat)` — use `.helvetica`, `.times`, `.courier`, etc.
  - `.bold()`, `.italic()`
  - `.foregroundColor(_ color: PDFColor)` or `CGColor`
  - `.alignment(.leading/.center/.trailing)`
- `PDFFont` — named font faces; resolves bold/italic variants automatically
- `PDFColor` — wraps CGColor; use `PDFColor(white:)`, `PDFColor(red:green:blue:)`, or statics like `.black`, `.gray`, `.white`

### Visual elements
- `Spacer(height: CGFloat)` — vertical gap
- `HRule(thickness:color:)` — horizontal rule; accepts `PDFColor` or `CGColor`
- `FilledBox(color:height:padding:) { content... }` — coloured background banner
- `ImageContent(path:maxWidth:maxHeight:alignment:)` — draws PNG/JPG from file path
- `QRCodeContent(_ string:size:alignment:)` — pure Swift QR, uses `swift-qrcode-generator` (cross-platform: macOS/iOS/Linux)

### Table
- `Table(data: [[String]], style: TableStyle, showHeader: Bool) { Column... }`
- `Column(_ header: String, width: .flex/.fixed(n), alignment:, headerAlignment:)`
- `TableStyle` — configures header bg, text colors, font sizes, row height, border, padding; has both `CGColor` and `PDFColor` initialisers

## Coordinate system
CoreGraphics PDFs have **origin at bottom-left**. The `cursor` variable tracks the current y-position starting from `bounds.maxY` (top of content area) and moves downward. Always pass `cursor` by `inout`.

## Adding a new PDFContent type
1. Create `Foo.swift` in `Sources/SwiftlyPDFKit/`
2. `public struct Foo: PDFContent`
3. Implement `public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat)`
4. Expose `PDFColor` overloads where CGColor is used, so callers don't need to import CoreGraphics

## Cross-platform notes
- **No CoreImage** — not available on Linux. QR codes use `swift-qrcode-generator` (pure Swift).
- **No AppKit/UIKit** — `NSAttributedString.Key.font` etc. are not available. Use CoreText CF attribute keys (`kCTFontAttributeName`, `kCTForegroundColorAttributeName`, `kCTParagraphStyleAttributeName`).
- `CFAttributedStringCreate` instead of `NSAttributedString` for attributed strings.

## Build & run
```bash
swift build
swift run HelloWorldPDF        # generates Invoice-20260114.pdf in cwd
```

## Dependencies
- [`swift-qrcode-generator`](https://github.com/fwcd/swift-qrcode-generator) `~> 1.0` — pure Swift QR encoder
