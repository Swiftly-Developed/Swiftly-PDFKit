# SwiftlyPDFKit — Claude Context

## Project overview
A Swift DSL for generating PDFs using result builders, inspired by SwiftUI's declarative syntax. Targets macOS, iOS, and Linux (Vapor). Uses CoreGraphics directly — no dependency on the PDFKit framework.

## Package structure
```
Sources/
├── SwiftlyPDFKit/          # Core PDF generation library (cross-platform)
├── SwiftlyPDFKitUI/        # SwiftUI bridge — PDFPreviewView (macOS/iOS only)
├── SwiftlyPDFKitPreviews/  # Xcode canvas #Preview blocks (macOS/iOS only)
└── HelloWorldPDF/          # Example executable (invoice + DSL demo)
```

## Key DSL types

### Entry point
- `PDF { Page... }` — top-level document; `.render() -> Data`, `.write(to: URL)`
- `PDF(pages: [Page])` — convenience init from a pre-built array (used internally by `PDFPreviewView`)

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
- To draw text: baseline = `cursor - ascent`; after drawing: `cursor = baseline - descent - leading`
- Images: use `context.draw(cgImage, in: rect)` — no flip transform needed for PDF contexts

## CoreText rendering
- Build a `CFAttributedString` with a `CTParagraphStyle` for alignment.
- Set paragraph alignment safely to avoid pointer lifetime warnings:
  ```swift
  let paraStyle: CTParagraphStyle = withUnsafeBytes(of: ctAlignment) { ptr in
      var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: ptr.baseAddress!)
      return CTParagraphStyleCreate(&setting, 1)
  }
  ```
- `CTLineGetTypographicBounds` returns the line width as its return value (not via pointer).

## ContentBuilder result builder
- `buildBlock` takes `[any PDFContent]...` (arrays), not `any PDFContent...` directly.
- `buildExpression` wraps a single item: `(_ expression: any PDFContent) -> [any PDFContent]`.
- This combination is required for `if/else`, `for`, and optional support to work correctly.

## Adding a new PDFContent type
1. Create `Foo.swift` in `Sources/SwiftlyPDFKit/`
2. `public struct Foo: PDFContent`
3. Implement `public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat)`
4. Expose `PDFColor` overloads where CGColor is used, so callers don't need to import CoreGraphics

## Cross-platform notes
- **No CoreImage** — not available on Linux. QR codes use `swift-qrcode-generator` (pure Swift).
- **No AppKit/UIKit** — `NSAttributedString.Key.font` etc. are not available. Use CoreText CF attribute keys (`kCTFontAttributeName`, `kCTForegroundColorAttributeName`, `kCTParagraphStyleAttributeName`).
- `CFAttributedStringCreate` instead of `NSAttributedString` for attributed strings.
- `CGColor(gray:alpha:)` is fine everywhere; `CGColor.white` class var conflicts with `PDFColor.white` — always use `PDFColor.white` explicitly (not `.white` shorthand) when the overload accepts both types.

## SwiftUI preview support (SwiftlyPDFKitUI + SwiftlyPDFKitPreviews)

### PDFPreviewView
Defined in `Sources/SwiftlyPDFKitUI/PDFPreviewView.swift`. Wraps a `PDFView` (PDFKit) in a SwiftUI view.
- Import `SwiftlyPDFKitUI` to use it.
- Whole file is `#if canImport(SwiftUI) && canImport(PDFKit)` guarded — safe on Linux.
- `PDFKitBridgeView` is `internal`; uses `UIViewRepresentable` on iOS, `NSViewRepresentable` on macOS.

```swift
PDFPreviewView {
    Page(size: .a4) {
        Text("Hello").font(.helvetica, size: 24).bold()
    }
}
```

### #Preview blocks (SwiftlyPDFKitPreviews)
Defined in `Sources/SwiftlyPDFKitPreviews/Previews.swift`.
- Declared as a **dynamic library** product (`type: .dynamic`) — required for Xcode canvas support.
- Uses `@available(macOS 14, iOS 17, *)` on all `#Preview` blocks (traits API requirement).
- `@MainActor` required on any `var` that constructs `PDFPreviewView`.
- **To see bare PDF with no device chrome**: use `traits: .sizeThatFitsLayout` and switch run destination to **My Mac** in Xcode. With an iPhone/iPad simulator destination `.sizeThatFitsLayout` still shows a device bezel.
- **Bare fixed-size window**: `traits: .fixedLayout(width:height:)` on My Mac destination.
- **iPhone bezel**: `traits: .portrait` with an iPhone simulator destination.
- Canvas only works in **Selectable mode** (cursor icon at canvas bottom-left) for `.sizeThatFitsLayout`.

### Package products
| Product | Type | Platforms |
|---|---|---|
| `SwiftlyPDFKit` | static library | macOS, iOS, Linux |
| `SwiftlyPDFKitUI` | static library | macOS, iOS |
| `SwiftlyPDFKitPreviews` | **dynamic** library | macOS, iOS |

## Build & run
```bash
swift build
swift run HelloWorldPDF   # writes Invoice-Model-Demo.pdf + HelloWorld-DSL-Demo.pdf to cwd
```

## Git / GitHub
- Repo is local only — do **not** push to remote unless explicitly asked.
- GitHub account: VanAkenBen; `gh` CLI is authenticated (scopes: repo, workflow, project).

## Dependencies
- [`swift-qrcode-generator`](https://github.com/fwcd/swift-qrcode-generator) `~> 1.0` — pure Swift QR encoder
