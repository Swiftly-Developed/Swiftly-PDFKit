# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-21

### Added

- **Linux support**: HTML-to-PDF rendering backend for Linux (via `wkhtmltopdf`)
- `renderHTML()` method on all 12 DSL primitives (Text, Table, Columns, FilledBox, Footer, ImageContent, QRCodeContent, Spacer, HRule)
- `PDF.renderHTML()` public method for inspecting/debugging the generated HTML on any platform
- `HTMLToPDFConverter` (Linux only) — invokes `wkhtmltopdf` via Foundation `Process`
- `PDFColor.components` — cross-platform RGBA component access without `CGColor`
- `PDFColor.cssRGBA` — CSS color string output (e.g. `"rgb(255,0,0)"`)
- `PDFFont.cssFontFamily` — CSS font-family stack for HTML rendering
- `String.htmlEscaped` utility extension
- QR codes render as inline SVG in HTML output
- Images render as base64-encoded `<img>` data URIs in HTML output
- Built-in PNG/JPEG header reader for image dimensions on Linux (no ImageIO required)

### Changed

- `PDFColor` now stores RGBA components directly instead of wrapping `CGColor`; `cgColor` is a computed property on Darwin only
- `TableStyle` stores `PDFColor` internally instead of `CGColor`; the `CGColor` initializer is Darwin-only
- `FilledBox` and `HRule` store `PDFColor` internally; `CGColor` convenience initializers are Darwin-only
- `Text.textColor` changed from `CGColor` to `PDFColor`
- `ImageContent` stores file path alongside `CGImage` on Darwin, path-only on Linux
- All `import CoreGraphics` / `import CoreText` statements wrapped in `#if canImport(...)` guards
- `PDFContent` protocol: `draw(in:bounds:cursor:)` is Darwin-only; `renderHTML(bounds:cursor:)` is cross-platform
- Document layout code uses `PDFColor.components` instead of `CGColor.components` for accent color tinting

## [0.1.0] - 2026-02-21

### Added

- **Core DSL primitives**: `PDF`, `Page`, `Text`, `Spacer`, `HRule`, `Table`, `Columns`, `FilledBox`, `ImageContent`, `QRCodeContent`, `Footer`
- **Result builders**: `@ContentBuilder`, `@PageBuilder`, `@ColumnsBuilder`, `@ColumnBuilder` for declarative PDF composition
- **Styling**: `PDFColor` (named colors + custom RGB/grayscale), `PDFFont` (Helvetica, Times, Courier families + custom PostScript names), `TextAlignment`
- **Page sizes**: `.a4`, `.letter`, `.legal`, and custom `PageSize(width:height:)`
- **Table system**: flexible/fixed column widths, header styling, alternating row tint, customizable `TableStyle`
- **Invoice engine**: `InvoiceDocument` data model with automatic `InvoiceTotals` computation
- **5 invoice layouts**: `classic`, `classicWithSidebar`, `minimal`, `stacked`, `summaryFirst` — all with automatic multi-page pagination
- **3 built-in themes**: `standard`, `gold`, `corporate` — fully customizable via `InvoiceTheme`
- **Business documents**: Quote, Sales Order, Delivery Note, and Shipment layouts with type-specific supplements
- **QR code support**: pure-Swift QR generation via `swift-qrcode-generator` (no CoreImage dependency)
- **SwiftUI previews**: `PDFPreviewView` in `SwiftlyPDFKitUI` for live Xcode canvas rendering
- **Cross-platform**: macOS 12+, iOS 15+, Linux (CoreGraphics/CoreText only — no AppKit/UIKit)
- **15 demo configurations** with SwiftUI `#Preview` blocks and CLI batch generator

[0.2.0]: https://github.com/Swiftly-Developed/Swiftly-PDFKit/releases/tag/v0.2.0
[0.1.0]: https://github.com/Swiftly-Developed/Swiftly-PDFKit/releases/tag/v0.1.0
