# SwiftlyPDFKit — Claude Context

## Project overview
A Swift DSL for generating PDFs using result builders, inspired by SwiftUI's declarative syntax. Targets macOS, iOS, and Linux (Vapor). Uses CoreGraphics directly — no dependency on the PDFKit framework.

## Package structure
```
Sources/
├── SwiftlyPDFKit/
│   ├── Core/               # PDF primitives (cross-platform)
│   │   └── DocumentLayoutKit/  # Cross-family composition atoms (PRINT01)
│   └── Documents/
│       ├── Shared/         # DocumentSupplement structs + shared drawing helpers
│       ├── Invoice/        # Invoice data model, theme, layout builders
│       ├── Quote/          # Quote layout (QuoteLayoutType + QuoteLayoutBuilder)
│       ├── SalesOrder/     # Sales order layout
│       ├── Delivery/       # Delivery note layout
│       ├── PaymentReceipt/ # Payment receipt model, labels, layout (PRINT02)
│       ├── PurchaseOrder/  # Purchase order model, labels, layout (PRINT08)
│       └── RemittanceAdvice/ # Remittance advice model, labels, layout (PRINT03)
├── SwiftlyPDFKitUI/        # SwiftUI bridge — PDFPreviewView (macOS/iOS only)
├── DemoPDFKit/             # Dynamic library: 17 demos + Xcode #Preview blocks
└── GenerateDemos/          # Executable: renders all 17 demos to DemoPDFs/
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
- `PDF(layout:invoice:theme:labels:locale:pageSize:)` — builds an invoice PDF from an `InvoiceDocument` model
- `PDF(quoteLayout:invoice:supplement:theme:locale:pageSize:)` — quote / proposal
- `PDF(salesOrderLayout:invoice:supplement:theme:locale:pageSize:)` — sales order confirmation
- `PDF(deliveryLayout:invoice:supplement:theme:locale:pageSize:)` — delivery note / packing slip
- `PaymentReceiptLayout.build(_:theme:locale:pageSize:)` — payment receipt from a `PaymentReceiptDocument` (its own model, not `InvoiceDocument`)
- `PurchaseOrderLayout.build(_:theme:locale:pageSize:)` — purchase order from a `PurchaseOrderDocument` (its own model)
- `RemittanceAdviceLayout.build(_:theme:locale:pageSize:)` — remittance advice from a `RemittanceAdviceDocument` (its own model; single and batch form)

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

The invoice, quote, sales-order and delivery families share `InvoiceDocument` as their core data model (the payment receipt and the purchase order each have their own, below). Set `header.documentTitle` to the desired title (e.g. `"Quotation"`, `"Sales Order"`, `"Delivery Note"`).

- `InvoiceDocument(header:supplier:client:lines:totals:footer:)`
  - `totals` defaults to `InvoiceTotals(lines:)` — omit unless overriding (e.g. partial payment)
- `InvoiceTheme` / `DocumentTheme` (typealias) — colors, fonts, logo position, row heights
  - Built-in presets: `.standard`, `.gold`, `.corporate`
  - `logoPosition`: `.left` (default), `.right`, `.topCenter`

## Invoice layouts (`InvoiceLayoutType`)

<!-- SUPERSEDED 2026-09-09 by the PRINT01 Step 10 doc-steward, retiring a DOCUMENTS03 straggler.
     Prior text listed FIVE cases — `.classic`, `.classicWithSidebar`, `.minimal`, `.stacked`,
     `.summaryFirst`. DOCUMENTS03 replaced the enum with three production families; the four
     retired spellings do not compile against `Documents/Invoice/InvoiceLayout.swift` and had
     stood here as live API for weeks. Full prior text: docs/archive/DOCUMENTS03.md §10.
     Do not restore. `.minimal` / `.stacked` DO still exist — on `QuoteLayoutType` and
     `SalesOrderLayoutType`, which are different enums; see "New document layouts" below. -->

Three families via `PDF(layout:invoice:theme:pageSize:)` — the DOCUMENTS03 set. The enum is
`Documents/Invoice/InvoiceLayout.swift`; read the cases there, never from this list.
- `.modern` — the contemporary, accent-forward grammar; the only family carrying the full-bleed `TopAccentBar`. **Default**, and the tolerant-decode target for every retired spelling.
- `.classic` — two-column header (logo + supplier / client), meta block, table, totals
- `.receipt` — the condensed, receipt-style grammar; prunes the payment ladder when the document is paid

## New document layouts

### Quote (`QuoteLayoutType`)
Via `PDF(quoteLayout:invoice:supplement:theme:locale:pageSize:)`. Supplement: `QuoteSupplement(expiryDate:acceptanceNote:)`.
- `.classic` — two-column header, meta grid with "Quote No." / "Valid Until", priced line items, totals (no Amount Due row), acceptance signature block
- `.minimal` — same as classic with borderless table theme override

### Sales Order (`SalesOrderLayoutType`)
Via `PDF(salesOrderLayout:invoice:supplement:theme:locale:pageSize:)`. Supplement: `SalesOrderSupplement(poConfirmedDate:requestedDeliveryDate:)`.
- `.classic` — meta grid with "Order No." / "Req. Delivery" / "PO Confirmed", full pricing table, totals (no payment/QR)
- `.stacked` — delegates to `InvoiceLayoutBuilder.stackedLayout`

### Delivery Note (`DeliveryLayoutType`)
Via `PDF(deliveryLayout:invoice:supplement:theme:locale:pageSize:)`. Supplement: `DeliverySupplement(shipToAddress:signatureRequired:signatureLabel:)`.
- `.standard` — ship-to address strip (when `shipToAddress` set), delivery meta grid, simplified table (Description / Qty / Unit / Notes), **no pricing columns**, **no totals**, optional signature acknowledgement block at bottom

Delivery table Notes column: only included when `invoice.lines.contains { $0.detail != nil }`.

### Payment receipt (`PaymentReceiptLayout`, PRINT02)
Via `PaymentReceiptLayout.build(_:theme:locale:pageSize:)`. One layout (Modern grammar), so there is no layout-type enum.
- **Own model** — `PaymentReceiptDocument` (payer, header, ordered payment facts, netted allocation rows, totals, optional reversal, notes). A payment has no lines and no VAT; it is never mapped onto `InvoiceDocument`.
- **`PaymentReceiptLabels` is NOT a `LabelSet`** — exactly 60 stored captions (one per catalog key; a server twin checks the count by reflection), named `{last4}` / `{rate}` / `{reason}` tokens, plus `reversalReason(forCode:)` and `paymentMeansLabel(forCode:)`. The family-neutral captions travel separately as `document.common: CommonDocumentLabels`; the page line is `common.pageNumber(_:of:)`.
- **Zero kit edits** — the kit's page planner, footer and totals ladder are invoice-bound, so the receipt composes those jobs from primitives in the package-internal `PaymentDocumentBlocks` (allocation table with a repeated header, facts grid, totals stack, footer, pagination), factored for reuse by a later payment family — shared with the remittance advice, which calls it through additive overloads.
- Totals: received / allocated / **unallocated always** / one informational row per bank charge in its own currency. A reversal adds the `DocumentWatermark` on every page and, with a reason code, a notice line.

### Purchase order (`PurchaseOrderLayout`, PRINT08)
Via `PurchaseOrderLayout.build(_:theme:locale:pageSize:)`. One layout (Modern grammar), so there is no layout-type enum.
- **Own model** — `PurchaseOrderDocument`: the issuer is the **buyer** (our company), the counter-party a supplier (`PurchaseOrderDocumentVendor`), an optional deliver-to block (warehouse and/or free-text address), mapper-captioned metadata rows, kind-agnostic lines (stock / service / expense) whose item and description cells **stack** several wrapping lines (SKU over name; description, the line's own expected date and its note), a tax breakdown, totals and special instructions. Never mapped onto `InvoiceDocument`.
- **`PurchaseOrderLabels` is NOT a `LabelSet`** — exactly 38 stored captions (one per catalog key; a server twin checks the count by reflection), count-neutral `{token}` templates expanded by helpers (`paymentTermsDays(name:days:)`, `incoterm(rule:place:)`, `lineExpectedDelivery(date:)`, `closedShortLinesOmitted(count:)`, `cancelledNotice(date:)`). The totals captions (subtotal / discount / tax / total) and the draft watermark come from `document.common: CommonDocumentLabels`; the family adds only the shipping caption.
- **The issuer's bank line is always suppressed** — the layout strips `iban` / `bic` itself, whatever the caller passes.
- **Zero kit edits and no `PaymentDocumentBlocks` reuse** — the table, pager, tax breakdown, totals stack and footer are the family's own (`PurchaseOrderLayout+Table.swift`); totals values print the ISO code, never a symbol.
- `.draft` / `.cancelled(cancelledOn:)` put the `DocumentWatermark` (`DRAFT` / `CANCELLED`) on every page; a cancellation with a date adds a notice line.

### Remittance advice (`RemittanceAdviceLayout`, PRINT03)
Via `RemittanceAdviceLayout.build(_:theme:locale:pageSize:)`. One layout (Modern grammar), so there is no layout-type enum.
- **Own model** — `RemittanceAdviceDocument`: the issuer is **our** company (the payer), the counter-party the payee (`RemittanceAdvicePayee`, with its register / supplier number, our customer number with them and the masked paid-to account). Two forms: single (`memberPayments == nil`) and batch (a member-payment list, and per document the member that paid it). The mappers do every sum; the layout does no arithmetic. Never mapped onto `InvoiceDocument`.
- **`RemittanceAdviceLabels` is NOT a `LabelSet`** — exactly 39 stored captions, the **remittance-only** keys of the shared payment catalog (a server twin checks the count by reflection), one `{reason}` helper (`adjustmentReason(_:)`). The captions shared with the receipt (allocation columns, settled marker, empty row, rate template, reversal watermark / notice / reasons, notes, bank charges, remittance information) come from `document.payment: PaymentReceiptLabels`; the discount totals caption and the page line from `document.common`.
- **The issuer's bank line IS printed** — it is the account the payment leaves from.
- **Detail table = the receipt's six-column atom** (`PaymentDocumentBlocks`, through additive stacked-row overloads) with a stacked document cell (their number · type · our reference · paying member in a batch) and cash-discount / adjustment sub-rows; the payee's date in the date column. The batch member list reuses the same atom and paginates with its header repeated.
- One totals stack per currency (on account always printed); `.reversed(reasonCode:)` / `.notYetSubmitted` put the `DocumentWatermark` on every page and a notice after the totals.
- **Closing blocks flow unit by unit (§25 #48):** the totals stay on the last settled row's page whenever they fit; each remittance line (the caption with the first), the notice and the notes then take the rest of that page or start the next, never split. The batch reference has a full-width row of its own and the member list's payment cell spans the three blank columns beside it, so neither wraps a long id.

## Cross-family layout kit (`DocumentLayoutKit`, PRINT01)

`Sources/SwiftlyPDFKit/Core/DocumentLayoutKit/` — the public namespace a document
family composes a page from instead of copying a sibling builder.

- **Promoted atoms** (`DocumentLayoutKit.swift`): `Pagination` + `paginate(…)`,
  `hairlineTableStyle(…)`, `clear`, `mutedText`, the six typography constants
  (`modernTitleSize`, `modernHeadlineSize`, `modernSectionSize`,
  `classicTitleSize`, `receiptTitleSize`, `receiptThanksSize`) and `footer(…)`.
- **Composition blocks**, each returning `[any PDFContent]` built from existing
  primitives, so both render paths come for free:
  `supplierIdentityBlock(supplier:labels:theme:)`,
  `partyBlock(party:header:labels:theme:)`,
  `metadataGrid(rows:theme:columns:)`,
  `signatureBlock(labels:theme:heading:)`,
  `totalsBlock(totals:labels:formatter:theme:)`.
- **`registerNumber(fromVATID:)`** — BE enterprise number / FR SIREN fallback for
  `InvoiceSupplier.registrationNumber`; `nil` everywhere else.
- **`LabelSet`** (`Core/LabelSet.swift`) — one requirement, `pageNumber(_:of:)`;
  `InvoiceLabels` conforms via an empty extension. **`CommonDocumentLabels`**
  (`Core/CommonDocumentLabels.swift`) carries the 24 frozen captions the blocks
  render. The member list does not grow.
- **`DocumentWatermark`** (`Core/DocumentWatermark.swift`) — page-level, NOT under
  `DocumentLayoutKit/`, because `Page` special-cases it by type exactly as it does
  `TopAccentBar`. See "Adding a new PDFContent type" below.

`InvoiceLayoutKit` survives holding only the two invoice-*state* helpers
(`title(for:fmt:)`, `isOutstanding(_:)`).

## Shared document layout infrastructure

### DocumentSupplement (`Documents/Shared/DocumentSupplement.swift`)
Three `public struct … : Sendable` types, one per document type. All fields optional with sensible defaults.

### DocumentLayoutHelpers (`Documents/Shared/DocumentLayoutHelpers.swift`)
Internal free functions returning `[any PDFContent]`:
- `shipToAddressBlock(address:theme:)` — lightly-tinted `FilledBox` strip with ship-to address
  - **Important**: converts `theme.accentColor` to sRGB before reading RGB components — grayscale colorspaces (e.g. `.standard`'s black accent) have only 2 components and will crash if accessed as RGB directly
- `signatureBlock(label:theme:)` — rule + three fields (Signature / Date received / Print name)
- `acceptanceBlock(note:theme:)` — quote acceptance section; returns `[]` when `note` is nil

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

`lastPageBottomH` varies:
- Invoice: `totalsH + notesH + paymentH`
- Quote: `totalsH + notesH + acceptanceH`
- SalesOrder: `totalsH + notesH`
- Delivery: `notesH + sigH`

Footer is emitted on every page via a local `makeFooter()` closure.

## Number formatting (`DocumentFormatter`)
Every method formats through the formatter's `locale` — the document's resolved
recipient locale, never the process or device locale — with `FormatStyle`
(`NumberFormatter` and `String(format:)` are banned; see `docs/standards/AGENTS.md`
→ "Number Formatting"). Every family's `PDF(…)` init takes `locale:` (default
`en_US`, the package-standalone fallback) and hosts pass the recipient's.
- `amount(_:)` — 2 decimal places, grouped, no currency symbol (e.g. `1.234,50` nl-BE / `1,234.50` en-US).
- `quantity(_:)` — 0–2 decimal places, grouped (e.g. `2,5` / `3`).
- `percent(_:)` — input is a 0–100 rate (`21` = 21 %), 0–2 decimals (e.g. `5,5%` nl-BE / `5.5%` en-US).
- `money(_:)` — `.currency(code: currencyCode)`; `date(_:)` — abbreviated date.

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
4. **Implement `renderHTML(bounds:cursor:)` in the same change.** CoreGraphics
   (client preview) and hand-written HTML (Linux server attachment) are
   independent paths with no shared fallback — a primitive that implements only
   one renders a *different document* on the server than in the preview.
5. Expose `PDFColor` overloads where CGColor is used, so callers don't need to import CoreGraphics

### Page-level (full-bleed) primitives
A `PDFContent` is always drawn inside `Page`'s **margin-inset body bounds**, through
a shared top-down cursor — so it can never reach the page edge or sit across the
whole page. A full-bleed element is instead a **marker**: it conforms to
`PDFContent` so it can be written inline in a `Page { … }` builder, but both of its
own render methods are deliberately inert, and `Page` pulls it out by type and
draws it against the **page** rect. Two exist: `TopAccentBar` and
`DocumentWatermark`. Adding a third means a stored slot on `Page`, a term in the
`bodyContents` filter, and an arm in **both** `render(in:)` and `renderHTML()`,
written and reviewed together — including the paint order, which must match.

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
├── Demo08_ModernCorporate.swift  — .modern · Corporate theme                            #Preview "08 · Classic + Sidebar"
├── Demo09_ModernStandard.swift   — .modern · Standard theme · 5 lines · notes           #Preview "09 · Minimal"
├── Demo10_ModernBrandAccent.swift— .modern · custom teal theme                          #Preview "10 · Stacked"
├── Demo11_ReceiptPaid.swift      — .receipt · Gold theme · paid                         #Preview "11 · Summary First"
├── Demo12_Quote.swift          — .classic quote · Standard theme · acceptance block      #Preview "12 · Quote"
├── Demo13_SalesOrder.swift     — .classic sales order · Corporate · multi-page           #Preview "13 · Sales Order"
├── Demo14_Delivery.swift       — .standard delivery · ship-to + signature + Notes col    #Preview "14 · Delivery"
├── Demo16_PaymentReceipt.swift — payment receipt · reversed (watermark) · FX sub-row     #Preview "16 · Payment Receipt"
├── Demo17_PurchaseOrder.swift — purchase order · draft (watermark) · stacked description cells   #Preview "17 · Purchase Order"
└── Demo18_RemittanceAdvice.swift — remittance advice · batch · not yet submitted (watermark) · stacked document cells   #Preview "18 · Remittance Advice"
```

<!-- SUPERSEDED 2026-09-09 by the PRINT01 Step 10 doc-steward. Rows 08-11 previously named
     `Demo08_Sidebar` / `Demo09_Minimal` / `Demo10_Stacked` / `Demo11_SummaryFirst`, four files
     DOCUMENTS03 renamed; the layouts column named four retired enum cases. Do not restore. -->

⚠️ The four `#Preview` LABELS on rows 08-11 still read `Classic + Sidebar` / `Minimal` /
`Stacked` / `Summary First`. That is not a doc error — it is what the `#Preview` strings in
`Sources/DemoPDFKit/` literally say, and DOCUMENTS03 did not update them. The label is a
Canvas caption, not the layout; the layout is the `PDF(layout:)` argument in the same file.

#### Shared.swift fixtures
- `demoLogoPath`, `demoSupplier`, `demoClient`, `demoLines` (66 lines), `demoShortLines` (first 6), `demoFooter`, `demoQRPayload`
- `demoQuoteSupplement`, `demoSalesOrderSupplement`, `demoDeliverySupplement`
- `invoicePreview(_ pdf: PDF) -> some View` helper
- `demoSupplier` IBAN: `BE71 3630 8427 9163` (randomized); `demoQRPayload`: `"https://www.swiftly-workspace.com"` (URL, not EPC payment string)

## GenerateDemos tool

`Sources/GenerateDemos/main.swift` — a standalone macOS executable (no SwiftUI dependency) that replicates all 17 demo configurations from `DemoPDFKit` and writes them to `DemoPDFs/` at the package root.

```bash
# Generate all 17 demo PDFs
swift run GenerateDemos
```

- Output: `DemoPDFs/Demo01_Standard.pdf` … `DemoPDFs/Demo14_Delivery.pdf`, then `DemoPDFs/Demo16_PaymentReceipt.pdf`, `DemoPDFs/Demo17_PurchaseOrder.pdf` and `DemoPDFs/Demo18_RemittanceAdvice.pdf` (Demo01–Demo14, Demo16–Demo18)
- Does **not** import `SwiftUI` or `SwiftlyPDFKitUI` — uses `SwiftlyPDFKit` only
- All fixture data (supplier, client, lines, footer, supplements) is self-contained in `main.swift`; `demoSupplier` and `demoFooter` use IBAN `BE71 3630 8427 9163`
- `demoQRPayload` is `"https://www.swiftly-workspace.com"` (URL-style QR, not a payment EPC string)
- `Package.swift` declares it as `.executableTarget(name: "GenerateDemos", dependencies: ["SwiftlyPDFKit"])`

## Build
```bash
swift build
```

## Version
Current: **0.2.0** — Linux HTML-to-PDF backend.

## Repository files (OSS scaffolding)
```
LICENSE              — MIT
README.md            — badges, installation (from: "0.2.0"), features, API docs, demos
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
- `DemoPDFs/` contains 17 generated example PDFs (Demo01–Demo14, Demo16–Demo18)

## Git / GitHub
- Remote: `https://github.com/Swiftly-Developed/Swiftly-PDFKit.git`
- GitHub account: VanAkenBen; `gh` CLI is authenticated (scopes: repo, workflow, project).

## Dependencies
- [`swift-qrcode-generator`](https://github.com/fwcd/swift-qrcode-generator) `~> 1.0` — pure Swift QR encoder
