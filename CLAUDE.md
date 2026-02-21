# SwiftlyPDFKit — Claude Context

## Project overview
A Swift DSL for generating PDFs using result builders, inspired by SwiftUI's declarative syntax. Targets macOS, iOS, and Linux (Vapor). Uses CoreGraphics directly — no dependency on the PDFKit framework.

## Package structure
```
Sources/
├── SwiftlyPDFKit/
│   ├── Core/               # PDF primitives (cross-platform)
│   └── Documents/
│       ├── Shared/         # DocumentSupplement structs + shared drawing helpers
│       ├── Invoice/        # Invoice data model, theme, layout builders
│       ├── Quote/          # Quote layout (QuoteLayoutType + QuoteLayoutBuilder)
│       ├── SalesOrder/     # Sales order layout
│       ├── Delivery/       # Delivery note layout
│       └── Shipment/       # Shipment confirmation layout
├── SwiftlyPDFKitUI/        # SwiftUI bridge — PDFPreviewView (macOS/iOS only)
├── DemoPDFKit/             # Dynamic library: 15 demos + Xcode #Preview blocks
└── GenerateDemos/          # Executable: renders all 15 demos to DemoPDFs/
DemoPDFs/                   # Generated PDF output (gitignored or committed as needed)
```

## Package products
| Product | Type | Platforms |
|---|---|---|
| `SwiftlyPDFKit` | static library | macOS, iOS, Linux |
| `SwiftlyPDFKitUI` | static library | macOS, iOS |
| `DemoPDFKit` | **dynamic** library | macOS, iOS |
| `GenerateDemos` | **executable** | macOS |

SPM scans `Sources/SwiftlyPDFKit/` recursively — no `Package.swift` changes needed when adding subdirectories.

## Key DSL types

### Entry point
- `PDF { Page... }` — top-level document; `.render() -> Data`, `.write(to: URL)`
- `PDF(pages: [Page])` — convenience init from a pre-built array (used internally by `PDFPreviewView`)
- `PDF(layout:invoice:theme:pageSize:)` — builds an invoice PDF from an `InvoiceDocument` model
- `PDF(quoteLayout:invoice:supplement:theme:pageSize:)` — quote / proposal
- `PDF(salesOrderLayout:invoice:supplement:theme:pageSize:)` — sales order confirmation
- `PDF(deliveryLayout:invoice:supplement:theme:pageSize:)` — delivery note / packing slip
- `PDF(shipmentLayout:invoice:supplement:theme:pageSize:)` — shipment confirmation / dispatch advice

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

## Document model (shared across all document types)

All document types reuse `InvoiceDocument` as their core data model. Set `header.documentTitle` to the desired title (e.g. `"Quotation"`, `"Sales Order"`, `"Delivery Note"`).

- `InvoiceDocument(header:supplier:client:lines:totals:footer:)`
  - `totals` defaults to `InvoiceTotals(lines:)` — omit unless overriding (e.g. partial payment)
- `InvoiceTheme` / `DocumentTheme` (typealias) — colors, fonts, logo position, row heights
  - Built-in presets: `.standard`, `.gold`, `.corporate`
  - `logoPosition`: `.left` (default), `.right`, `.topCenter`

## Invoice layouts (`InvoiceLayoutType`)
Five fully-implemented layouts via `PDF(layout:invoice:theme:pageSize:)`:
- `.classic` — two-column header (logo + supplier / client), meta block, table, totals
- `.classicWithSidebar` — classic with a 14pt accent `FilledBox` bar on the full left edge of every page
- `.minimal` — borderless table, no header background, plain-text totals via `Columns` rows, airy 22pt row height
- `.stacked` — full-width accent banner title, supplier centred, client below HRule, light-tint meta strip; compact repeat header on continuation pages
- `.summaryFirst` — page 1 shows header + meta + totals + payment only; line items start on page 2

## New document layouts

### Quote (`QuoteLayoutType`)
Via `PDF(quoteLayout:invoice:supplement:theme:pageSize:)`. Supplement: `QuoteSupplement(expiryDate:acceptanceNote:)`.
- `.classic` — two-column header, meta grid with "Quote No." / "Valid Until", priced line items, totals (no Amount Due row), acceptance signature block
- `.minimal` — same as classic with borderless table theme override

### Sales Order (`SalesOrderLayoutType`)
Via `PDF(salesOrderLayout:invoice:supplement:theme:pageSize:)`. Supplement: `SalesOrderSupplement(poConfirmedDate:requestedDeliveryDate:)`.
- `.classic` — meta grid with "Order No." / "Req. Delivery" / "PO Confirmed", full pricing table, totals (no payment/QR)
- `.stacked` — delegates to `InvoiceLayoutBuilder.stackedLayout`

### Delivery Note (`DeliveryLayoutType`)
Via `PDF(deliveryLayout:invoice:supplement:theme:pageSize:)`. Supplement: `DeliverySupplement(shipToAddress:signatureRequired:signatureLabel:)`.
- `.standard` — ship-to address strip (when `shipToAddress` set), delivery meta grid, simplified table (Description / Qty / Unit / Notes), **no pricing columns**, **no totals**, optional signature acknowledgement block at bottom

Delivery table Notes column: only included when `invoice.lines.contains { $0.detail != nil }`.

### Shipment Confirmation (`ShipmentLayoutType`)
Via `PDF(shipmentLayout:invoice:supplement:theme:pageSize:)`. Supplement: `ShipmentSupplement(carrier:trackingNumber:shipToAddress:estimatedDelivery:signatureRequired:signatureLabel:)`.
- `.standard` — accent carrier banner (carrier + tracking + est. delivery), ship-to strip, shipment meta grid, simplified table (same columns as delivery), optional signature block
- `.compact` — single page, no table — plain `Text` rows for each line item (suitable for single-package confirmations)

## Shared document layout infrastructure

### DocumentSupplement (`Documents/Shared/DocumentSupplement.swift`)
Four `public struct … : Sendable` types, one per document type. All fields optional with sensible defaults.

### DocumentLayoutHelpers (`Documents/Shared/DocumentLayoutHelpers.swift`)
Internal free functions returning `[any PDFContent]`:
- `shipToAddressBlock(address:theme:)` — lightly-tinted `FilledBox` strip with ship-to address
  - **Important**: converts `theme.accentColor` to sRGB before reading RGB components — grayscale colorspaces (e.g. `.standard`'s black accent) have only 2 components and will crash if accessed as RGB directly
- `signatureBlock(label:theme:)` — rule + three fields (Signature / Date received / Print name)
- `acceptanceBlock(note:theme:)` — quote acceptance section; returns `[]` when `note` is nil
- `carrierBlock(carrier:trackingNumber:estimatedDelivery:theme:)` — accent `FilledBox` banner

### InvoiceLayoutBuilder shared helpers
All section builders in `InvoiceLayoutBuilder` are `internal static func` (not `private`) so sibling layout builders in the same module can call them:
- `headerSection`, `metaSection`, `lineItemsTable`, `lineItemsTableForRows`, `totalsTable`, `paymentSection`, `logoOrFallback`, `supplierBlock`, `clientBlock`, `stackedMetaBanner`

## Multi-page layout algorithm (two-pass)
Used by all layout builders with tables:
1. **Pass 1** — split `invoice.lines` into chunks: page 1 takes `floor((bodyH - page1Overhead - tableHeaderH) / rowH)` rows; continuation pages take `floor((bodyH - tableHeaderH) / rowH)` rows.
2. **Pass 2** — compute `lastChunkUsed + lastPageBottomH`; if it exceeds `bodyH`, append an empty `[]` chunk → dedicated bottom-content-only page.

`page1Overhead` varies per document type:
- Invoice/Quote/SalesOrder: `logoMaxHeight + 13 + 52 + 20 + metaHeight + 20`
- Delivery: adds `shipToH` (~46 pt when `shipToAddress` is set)
- Shipment: adds `carrierH` (50 pt) + `shipToH`

`lastPageBottomH` varies:
- Invoice: `totalsH + notesH + paymentH`
- Quote: `totalsH + notesH + acceptanceH`
- SalesOrder: `totalsH + notesH`
- Delivery/Shipment: `notesH + sigH`

Footer is emitted on every page via a local `makeFooter()` closure.

## Number formatting (`InvoiceFormatter`)
- `amount(_:)` — 2 decimal places, thousands grouped (e.g. `1,200.00`). Shared `static let` `NumberFormatter`.
- `quantity(_:)` — 0–2 decimal places, thousands grouped. Trailing zeros trimmed.
- `percent(_:)` — plain `String(format:)` with `%%`; no grouping (values are always small).

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
1. Create `Foo.swift` in `Sources/SwiftlyPDFKit/Core/`
2. `public struct Foo: PDFContent`
3. Implement `public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat)`
4. Expose `PDFColor` overloads where CGColor is used, so callers don't need to import CoreGraphics

## Adding a new document type
1. Create `Sources/SwiftlyPDFKit/Documents/MyType/` directory
2. Add `MyTypeSupplement` struct to `Documents/Shared/DocumentSupplement.swift`
3. Create `MyTypeLayout.swift` — public enum `MyTypeLayoutType` + `PDF(myTypeLayout:…)` extension
4. Create `MyTypeLayoutBuilder.swift` — internal enum with layout static funcs; call `InvoiceLayoutBuilder.*` helpers freely (same module)
5. Add demo `DemoNN_MyType.swift` to `Sources/DemoPDFKit/`

## Cross-platform notes
- **No CoreImage** — not available on Linux. QR codes use `swift-qrcode-generator` (pure Swift).
- **No AppKit/UIKit** — `NSAttributedString.Key.font` etc. are not available. Use CoreText CF attribute keys (`kCTFontAttributeName`, `kCTForegroundColorAttributeName`, `kCTParagraphStyleAttributeName`).
- `CFAttributedStringCreate` instead of `NSAttributedString` for attributed strings.
- `CGColor(gray:alpha:)` is fine everywhere; `CGColor.white` class var conflicts with `PDFColor.white` — always use `PDFColor.white` explicitly (not `.white` shorthand) when the overload accepts both types.
- **CGColor colorspace caution**: grayscale `CGColor` (e.g. `CGColor(gray:alpha:)`) has only 2 components `[gray, alpha]`, not 4. Never assume RGB layout. Convert to sRGB with `cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent:options:)` before accessing `[r,g,b]` indices.

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
├── Shared.swift                — logo path, shared fixtures, supplement fixtures, invoicePreview()
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
├── Demo11_SummaryFirst.swift   — .summaryFirst · Gold theme · full demoLines             #Preview "11 · Summary First"
├── Demo12_Quote.swift          — .classic quote · Standard theme · acceptance block      #Preview "12 · Quote"
├── Demo13_SalesOrder.swift     — .classic sales order · Corporate · multi-page           #Preview "13 · Sales Order"
├── Demo14_Delivery.swift       — .standard delivery · ship-to + signature + Notes col    #Preview "14 · Delivery"
└── Demo15_Shipment.swift       — .standard shipment · Corporate · carrier banner         #Preview "15 · Shipment"
```

#### Shared.swift fixtures
- `demoLogoPath`, `demoSupplier`, `demoClient`, `demoLines` (66 lines), `demoShortLines` (first 6), `demoFooter`, `demoQRPayload`
- `demoQuoteSupplement`, `demoSalesOrderSupplement`, `demoDeliverySupplement`, `demoShipmentSupplement`
- `invoicePreview(_ pdf: PDF) -> some View` helper
- `demoSupplier` IBAN: `BE71 3630 8427 9163` (randomized); `demoQRPayload`: `"https://www.swiftly-workspace.com"` (URL, not EPC payment string)

## GenerateDemos tool

`Sources/GenerateDemos/main.swift` — a standalone macOS executable (no SwiftUI dependency) that replicates all 15 demo configurations from `DemoPDFKit` and writes them to `DemoPDFs/` at the package root.

```bash
# Generate all 15 demo PDFs
swift run GenerateDemos
```

- Output: `DemoPDFs/Demo01_Standard.pdf` … `DemoPDFs/Demo15_Shipment.pdf`
- Does **not** import `SwiftUI` or `SwiftlyPDFKitUI` — uses `SwiftlyPDFKit` only
- All fixture data (supplier, client, lines, footer, supplements) is self-contained in `main.swift`; `demoSupplier` and `demoFooter` use IBAN `BE71 3630 8427 9163`
- `demoQRPayload` is `"https://www.swiftly-workspace.com"` (URL-style QR, not a payment EPC string)
- `Package.swift` declares it as `.executableTarget(name: "GenerateDemos", dependencies: ["SwiftlyPDFKit"])`

## Build
```bash
swift build
```

## Version
Current: **0.1.0** — initial public release.

## Repository files (OSS scaffolding)
```
LICENSE              — MIT
README.md            — badges, installation (from: "0.1.0"), features, API docs, demos
CHANGELOG.md         — Keep a Changelog format, semver
CONTRIBUTING.md      — contribution guidelines, code style, cross-platform rules
SECURITY.md          — vulnerability reporting process
.github/
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   └── feature_request.md
└── PULL_REQUEST_TEMPLATE.md
```

- `.gitignore` excludes `*.pdf` globally but allows `!DemoPDFs/*.pdf` — demo output is committed
- `DemoPDFs/` contains 15 generated example PDFs (Demo01–Demo15)

## Git / GitHub
- Remote: `https://github.com/Swiftly-Developed/Swiftly-PDFKit.git`
- GitHub account: VanAkenBen; `gh` CLI is authenticated (scopes: repo, workflow, project).

## Dependencies
- [`swift-qrcode-generator`](https://github.com/fwcd/swift-qrcode-generator) `~> 1.0` — pure Swift QR encoder
