# SwiftlyPDFKit — Claude Context

## Project overview
A Swift DSL for generating PDFs using result builders, inspired by SwiftUI's declarative syntax. Targets macOS, iOS, and Linux (Vapor). Uses CoreGraphics directly — no dependency on the PDFKit framework.

## Package structure
```
Sources/
├── SwiftlyPDFKit/      # Core PDF generation library (cross-platform)
├── SwiftlyPDFKitUI/    # SwiftUI bridge — PDFPreviewView (macOS/iOS only)
└── DemoPDFKit/         # Dynamic library: 11 invoice demos + Xcode #Preview blocks
```

## Package products
| Product | Type | Platforms |
|---|---|---|
| `SwiftlyPDFKit` | static library | macOS, iOS, Linux |
| `SwiftlyPDFKitUI` | static library | macOS, iOS |
| `DemoPDFKit` | **dynamic** library | macOS, iOS |

## Key DSL types

### Entry point
- `PDF { Page... }` — top-level document; `.render() -> Data`, `.write(to: URL)`
- `PDF(pages: [Page])` — convenience init from a pre-built array (used internally by `PDFPreviewView`)
- `PDF(layout:invoice:theme:pageSize:)` — builds an invoice page from an `InvoiceDocument` model

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

## Invoice model
- `InvoiceDocument(header:supplier:client:lines:totals:footer:)` — full data model
  - `totals` defaults to `InvoiceTotals(lines:)` — omit unless overriding (e.g. partial payment / deposit)
- `InvoiceTheme` — colors, fonts, logo position, row heights; built-in presets: `.standard`, `.gold`, `.corporate`
  - `logoPosition`: `.left` (default), `.right`, `.topCenter`
- `InvoiceLayoutType`: five fully-implemented layouts:
  - `.classic` — two-column header (logo + supplier / client), meta block, table, totals
  - `.classicWithSidebar` — classic with a 14pt accent `FilledBox` bar on the full left edge of every page
  - `.minimal` — borderless table, no header background, plain-text totals via `Columns` rows, airy 22pt row height
  - `.stacked` — full-width accent banner title, supplier centred, client below HRule, light-tint meta strip; compact repeat header on continuation pages
  - `.summaryFirst` — page 1 shows header + meta + totals + payment only; line items start on page 2

## Multi-page invoice layout
`classicLayout` (and `classicWithSidebarLayout`, `minimalLayout`, `stackedLayout`) automatically split invoices:
- **Two-pass algorithm**: Pass 1 fills pages with as many rows as fit (ignoring bottom content). Pass 2 checks whether totals+notes+payment fit after the last row chunk; if not, an empty overflow page is appended.
- **Page 1** overhead is estimated from `logoMaxHeight + 13 + 52` (logo col) + spacers + meta block (~80 pt).
- **Continuation pages** start fresh at the top with only the table header row repeated.
- **Last page** renders totals, optional notes, and optional payment/QR section.
- **Footer** (`InvoiceFooter`) is emitted on every page via a local `makeFooter()` closure.
- The empty-chunk overflow page emits just the bottom content — no rows, no table header.

`summaryFirstLayout` uses a different structure:
- **Page 1** always contains only header + meta + totals + notes + payment (no line items).
- **Pages 2+** contain only line items, paginated using `contRowsMax` rows per page.

## Number formatting (`InvoiceFormatter`)
- `amount(_:)` — 2 decimal places, thousands grouped (e.g. `1,200.00`, `43,752.00`). Uses a shared `NumberFormatter` with `.decimal` style and `usesGroupingSeparator = true`.
- `quantity(_:)` — 0–2 decimal places, thousands grouped. Trailing zeros trimmed.
- `percent(_:)` — plain `String(format:)` with `%%`; no grouping (values are always small).
- Both formatters are `static let` on `InvoiceFormatter` — created once, reused across all render calls.

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

## SwiftUI preview support

### PDFPreviewView (SwiftlyPDFKitUI)
Defined in `Sources/SwiftlyPDFKitUI/PDFPreviewView.swift`. Wraps a `PDFView` (PDFKit) in a SwiftUI view.
- Import `SwiftlyPDFKitUI` to use it.
- Whole file is `#if canImport(SwiftUI) && canImport(PDFKit)` guarded — safe on Linux.
- `PDFKitBridgeView` is `internal`; uses `UIViewRepresentable` on iOS, `NSViewRepresentable` on macOS.
- Two initialisers:
  ```swift
  // DSL page builder
  PDFPreviewView {
      Page(size: .a4) { Text("Hello").font(.helvetica, size: 24).bold() }
  }

  // Pre-built PDF (e.g. from PDF(layout:invoice:))
  PDFPreviewView(pdf)
  ```

### #Preview blocks (DemoPDFKit)
`#Preview` blocks live **inside `Sources/DemoPDFKit/`** alongside the demo data — no separate Previews target.
- `DemoPDFKit` is declared as a **dynamic library** product (`type: .dynamic`) — required for Xcode canvas.
- Uses `@available(macOS 14, iOS 17, *)` on all `#Preview` blocks (traits API requirement).
- All module-level globals (`invoice`, `pdf`, `theme`, `lines`, etc.) must be `@MainActor` — Swift 6 strict
  concurrency requires this because `PDF`, `Page`, and `[any PDFContent]` are not `Sendable`.
- Use `traits: .fixedLayout(width:height:)` matching the page size (595×842 A4, 612×792 Letter).

#### DemoPDFKit file layout
```
Sources/DemoPDFKit/
├── Shared.swift                — logo path, shared fixtures (supplier/client/lines/footer/QR), invoicePreview()
├── Demo01_Standard.swift       — .classic · Standard theme · logo left · QR              #Preview "01 · Standard"
├── Demo02_Gold.swift           — .classic · Gold theme · logo left · no QR               #Preview "02 · Gold"
├── Demo03_Corporate.swift      — .classic · Corporate theme · QR + notes + service date  #Preview "03 · Corporate"
├── Demo04_Purple.swift         — .classic · Purple serif · logo right · licence lines    #Preview "04 · Purple · Logo Right"
├── Demo05_Green.swift          — .classic · Green eco · logo top-center · no footer      #Preview "05 · Green · Top Center"
├── Demo06_PartialPayment.swift — .classic · Standard · deposit / partial payment         #Preview "06 · Partial Payment"
├── Demo07_Mono.swift           — .classic · Courier mono · Letter size · zero VAT        #Preview "07 · Mono · Letter"
├── Demo08_Sidebar.swift        — .classicWithSidebar · Corporate theme · blue sidebar    #Preview "08 · Classic + Sidebar"
├── Demo09_Minimal.swift        — .minimal · Standard theme · 5 lines · notes             #Preview "09 · Minimal"
├── Demo10_Stacked.swift        — .stacked · custom teal theme                            #Preview "10 · Stacked"
└── Demo11_SummaryFirst.swift   — .summaryFirst · Gold theme · full demoLines             #Preview "11 · Summary First"
```

## Build
```bash
swift build
```

## Git / GitHub
- Remote: `https://github.com/Swiftly-Developed/Swiftly-PDFKit.git`
- GitHub account: VanAkenBen; `gh` CLI is authenticated (scopes: repo, workflow, project).

## Dependencies
- [`swift-qrcode-generator`](https://github.com/fwcd/swift-qrcode-generator) `~> 1.0` — pure Swift QR encoder
