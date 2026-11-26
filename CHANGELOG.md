# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`DocumentLayoutKit`** — a public, family-neutral layout kit under `Core/DocumentLayoutKit/`, so a document family is assembled from shared parts instead of copied from a sibling builder:
  - The cross-family atoms promoted out of the internal invoice kit: `Pagination` + `paginate(…)`, `hairlineTableStyle(…)`, `clear`, `mutedText`, the six typography constants and `footer(…)`.
  - Six composition blocks returning `[any PDFContent]` — `supplierIdentityBlock`, `partyBlock`, `metadataGrid`, `signatureBlock`, `totalsBlock` — plus `registerNumber(fromVATID:)`, a BE / FR fallback for a supplier without an explicit commercial-register number.
- **`LabelSet`** — a one-requirement protocol every family's label struct conforms to; `InvoiceLabels` conforms additively via an empty extension. **`CommonDocumentLabels`** carries the 24 frozen captions the composition blocks render.
- **`DocumentWatermark`** — a page-level, full-bleed rotated overlay, implemented in *both* of `Page`'s render paths (CoreGraphics and HTML).

### Changed

- **`InvoiceFormatter` is now `DocumentFormatter`** and lives in `Documents/Shared/`. It is no longer invoice-scoped, and it is now `public`. A `typealias InvoiceFormatter = DocumentFormatter` keeps the old spelling compiling.
- `InvoiceLayoutKit` is reduced to the two genuinely invoice-*state* helpers (`title(for:fmt:)`, `isOutstanding(_:)`).

### Removed

- **The shipment confirmation / dispatch advice document family**, end to end: `ShipmentLayoutType`, its `PDF` factory initialiser, `ShipmentLayoutBuilder`, `ShipmentSupplement`, the `carrierBlock` drawing helper it was the only caller of, demo 15 and its committed artifact. The demo set is now 14.

### Fixed

- **Linux `wkhtmltopdf` output rendered at ≈77 % scale, anchored top-left** (`docs/fixes/2026-09-03-invoice-pdf-linux-smart-shrinking-offcenter.md`):
  - `HTMLToPDFConverter` now passes the paper size in exact points (`--page-width 595pt`) instead of integer-rounded millimetres, so the `MediaBox` matches the CoreGraphics output exactly (Letter was 1.1pt shorter than its page box).
  - The converter probes `wkhtmltopdf --version` once per process; an unpatched-Qt build (which ignores `--disable-smart-shrinking`) gets a compensating CSS `body { zoom }` (`smartShrinkingCompensationZoom`, 1.6) via the new internal `PDF.renderHTML(bodyZoom:)`. The public `renderHTML()` output is unchanged.
  - `Page.renderHTML()` shaves 1pt (`Page.htmlPageBoxSlack`) off each `.page` box so a sub-pixel rounding no longer spills a blank trailing page.
  - The pure parts of `HTMLToPDFConverter` (`arguments(pageWidth:pageHeight:)`, `isPatchedQt(versionOutput:)`, the zoom constant) now compile on every platform so they can be unit-tested on macOS; the `Process`-spawning half stays Linux-only.

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
