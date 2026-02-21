# SwiftlyPDFKit

[![](https://img.shields.io/badge/Swift-6.0+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![](https://img.shields.io/badge/Platforms-macOS_12+_|_iOS_15+_|_Linux-blue)](#requirements)
[![](https://img.shields.io/badge/SPM-compatible-4FC08D)](#installation)
[![](https://img.shields.io/badge/version-0.2.0-orange)](https://github.com/Swiftly-Developed/Swiftly-PDFKit/releases/tag/v0.2.0)
[![](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A pure-Swift PDF generation library with a declarative DSL. Build pixel-perfect PDFs using a SwiftUI-inspired syntax — from simple one-page documents to multi-page invoices with automatic pagination.

---

## Features

- **Declarative DSL** &mdash; Result-builder syntax for pages, text, tables, columns, and more
- **Cross-platform** &mdash; CoreGraphics on Apple platforms, HTML-to-PDF on Linux; no AppKit or UIKit dependency
- **Invoice engine** &mdash; 5 built-in layouts with automatic multi-page pagination
- **Business documents** &mdash; Quotes, sales orders, delivery notes, and shipment documents
- **Themeable** &mdash; 3 built-in themes + fully customizable colors, fonts, and spacing
- **QR codes** &mdash; SEPA/EPC QR and arbitrary payloads via pure-Swift generation
- **SwiftUI previews** &mdash; Live Xcode canvas previews with `PDFPreviewView`

---

## Installation

Add SwiftlyPDFKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/Swiftly-PDFKit.git", from: "0.2.0"),
]
```

Then add the target dependency:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftlyPDFKit"]
),
```

For SwiftUI preview support, also add `SwiftlyPDFKitUI`:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftlyPDFKit", "SwiftlyPDFKitUI"]
),
```

---

## Quick start

### Simple PDF with the DSL

```swift
import SwiftlyPDFKit

let pdf = PDF {
    Page(size: .a4) {
        Text("Hello, world!")
            .font(.helvetica, size: 24)
            .bold()

        Spacer(height: 20)

        Text("Generated with SwiftlyPDFKit")
            .fontSize(12)
            .foregroundColor(PDFColor.gray)
    }
}

let data = try pdf.render()
try pdf.write(to: URL(fileURLWithPath: "/tmp/hello.pdf"))
```

### Invoice in 3 lines

```swift
import SwiftlyPDFKit

let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-001",
        issueDate: "2026-03-01",
        dueDate: "2026-03-15",
        currency: "EUR"
    ),
    supplier: InvoiceSupplier(name: "Acme Corp"),
    client: InvoiceClient(name: "Client BV"),
    lines: [
        InvoiceLine(description: "Consulting", quantity: 8, unit: "hrs",
                    unitPrice: 150, vatRate: 21),
        InvoiceLine(description: "Design review", quantity: 3, unit: "hrs",
                    unitPrice: 120, vatRate: 21, discountPercent: 10),
    ]
)

let pdf = PDF(layout: .classic, invoice: invoice, theme: .standard)
try pdf.write(to: URL(fileURLWithPath: "/tmp/invoice.pdf"))
```

---

## Core primitives

SwiftlyPDFKit provides 12 building blocks that compose via result builders:

### PDF & Page

```swift
// DSL builder
let pdf = PDF {
    Page(size: .a4, margins: 40) {
        // ... content ...
    }
    Page(size: .letter) {
        // ... more content ...
    }
}

// Render to Data or write to disk
let data = try pdf.render()
try pdf.write(to: url)
```

**Page sizes**: `.a4` (595 x 842), `.letter` (612 x 792), `.legal` (612 x 1008), or custom `PageSize(width:height:)`.

### Text

```swift
Text("Title")
    .font(.times, size: 24)
    .bold()
    .italic()
    .foregroundColor(PDFColor.blue)
    .alignment(.center)
```

**Modifier chain**: `.font(_:size:)`, `.bold()`, `.italic()`, `.fontSize(_:)`, `.foregroundColor(_:)`, `.alignment(_:)`

### Table

```swift
Table(data: rows, style: .default, showHeader: true) {
    Column("Description", width: .flex)
    Column("Qty", width: .fixed(60), alignment: .trailing)
    Column("Price", width: .fixed(80), alignment: .trailing)
}
```

Column widths are `.flex` (fills remaining space proportionally) or `.fixed(points)`. Each column supports independent text alignment and a separate header alignment.

**TableStyle** controls header colors, font sizes, row height, alternating row tint, border width, cell padding, and more.

### Columns (horizontal layout)

```swift
Columns(spacing: 10) {
    ColumnItem(width: .flex) {
        Text("Left column")
    }
    ColumnItem(width: .fixed(200)) {
        Text("Right column (200pt)")
    }
}
```

Each column renders independently with its own cursor. The overall cursor advances by the height of the tallest column.

### Other elements

| Element | Description |
|---------|-------------|
| `Spacer(height:)` | Vertical whitespace (default 12pt) |
| `HRule(thickness:color:)` | Horizontal divider line |
| `FilledBox(color:height:padding:) { ... }` | Colored background behind nested content |
| `ImageContent(path:maxWidth:maxHeight:alignment:)` | PNG/JPEG with aspect-ratio preservation |
| `QRCodeContent("payload", size: 80)` | QR code rendered as a crisp vector image |
| `Footer(height:) { ... }` | Content pinned to the bottom of every page |

### Colors and fonts

```swift
// Named colors
PDFColor.black, .white, .gray, .lightGray, .darkGray, .red, .green, .blue

// Custom colors
PDFColor(red: 0.2, green: 0.4, blue: 0.8)
PDFColor(white: 0.9)

// Built-in fonts
PDFFont.helvetica, .helveticaBold, .helveticaOblique, .helveticaBoldOblique
PDFFont.times, .timesBold, .timesItalic
PDFFont.courier, .courierBold

// Custom PostScript font name
PDFFont(name: "Menlo-Regular")
```

---

## Invoice engine

The invoice system uses a single data model (`InvoiceDocument`) that feeds into different visual layouts.

### Data model

```
InvoiceDocument
 +-- header: InvoiceHeader        // number, dates, currency, payment terms, QR, notes
 +-- supplier: InvoiceSupplier    // name, address, VAT, IBAN, logo path
 +-- client: InvoiceClient        // name, address, VAT, PO number
 +-- lines: [InvoiceLine]         // description, qty, unit, price, VAT rate, discount
 +-- totals: InvoiceTotals        // auto-computed from lines, or override manually
 +-- footer: InvoiceFooter?       // text lines pinned to page bottom
```

`InvoiceTotals` is derived automatically from lines. Override it for edge cases like global discounts or partial payments:

```swift
let totals = InvoiceTotals(
    subtotalExcl: 1200,
    totalVat: 252,
    totalIncl: 1452,
    amountPaid: 500   // deposit already paid
)
let invoice = InvoiceDocument(header: ..., supplier: ..., client: ...,
                              lines: lines, totals: totals)
```

### Layouts

| Layout | Description |
|--------|-------------|
| `.classic` | Two-column header, metadata grid, line-items table, totals, QR + payment banner |
| `.classicWithSidebar` | Classic layout with a full-height accent-colored bar on the left edge |
| `.minimal` | Borderless tables, generous whitespace, plain-text totals |
| `.stacked` | Full-width title banner, vertically stacked supplier and client blocks |
| `.summaryFirst` | Page 1 shows totals and payment only; line items start on page 2 |

```swift
let pdf = PDF(layout: .minimal, invoice: invoice, theme: .corporate, pageSize: .a4)
```

All layouts handle **automatic multi-page pagination**: line items overflow gracefully across pages, and totals/payment sections are guaranteed their own space (bumping to a new page if needed).

### Themes

Three built-in presets:

| Theme | Style |
|-------|-------|
| `.standard` | Clean black-and-white with subtle gray accents |
| `.gold` | Warm gold-tinted accent color |
| `.corporate` | Bold blue headers with light-blue alternating rows |

Customize any theme property:

```swift
var theme = InvoiceTheme.standard
theme.accentColor = PDFColor(red: 0.2, green: 0.6, blue: 0.4)
theme.bodyFont = .times
theme.logoPosition = .right
theme.lineItemRowHeight = 24
```

**Theme properties**: `accentColor`, `tableHeaderBackground`, `tableHeaderTextColor`, `tableAlternateRowColor`, `ruleColor`, `paymentBannerColor`, `paymentBannerTextColor`, `tableBorderColor`, `bodyFont`, `titleFont`, `bodyFontSize`, `titleFontSize`, `tableHeaderFontSize`, `tableCellFontSize`, `pageMargins`, `logoPosition` (`.left` / `.right` / `.topCenter`), `logoMaxWidth`, `logoMaxHeight`, `lineItemRowHeight`, `totalsRowHeight`.

---

## Business documents

Beyond invoices, SwiftlyPDFKit supports four additional document types. All share the `InvoiceDocument` data model and add a type-specific supplement for extra fields.

### Quotation

```swift
let supplement = QuoteSupplement(
    expiryDate: "2026-04-01",
    acceptanceNote: "Please sign and return to confirm."
)
let pdf = PDF(quoteLayout: .classic, invoice: invoice, supplement: supplement,
              theme: .standard, pageSize: .a4)
```

Layouts: `.classic`, `.minimal`

### Sales order

```swift
let supplement = SalesOrderSupplement(
    poConfirmedDate: "2026-03-01",
    requestedDeliveryDate: "2026-03-15"
)
let pdf = PDF(salesOrderLayout: .classic, invoice: invoice, supplement: supplement,
              theme: .corporate, pageSize: .a4)
```

Layouts: `.classic`, `.stacked`

### Delivery note

```swift
let supplement = DeliverySupplement(
    shipToAddress: "Warehouse 3\nIndustrial Park\n2000 Antwerp",
    signatureRequired: true,
    signatureLabel: "Received in good order by:"
)
let pdf = PDF(deliveryLayout: .standard, invoice: invoice, supplement: supplement,
              theme: .standard, pageSize: .a4)
```

Layouts: `.standard`

### Shipment document

```swift
let supplement = ShipmentSupplement(
    carrier: "DHL Express",
    trackingNumber: "JJD000390007843164734",
    shipToAddress: "Warehouse 3\nIndustrial Park\n2000 Antwerp",
    estimatedDelivery: "2026-03-18",
    signatureRequired: true
)
let pdf = PDF(shipmentLayout: .standard, invoice: invoice, supplement: supplement,
              theme: .corporate, pageSize: .a4)
```

Layouts: `.standard`, `.compact`

> **Tip**: Set `header.documentTitle` to customize the title shown on the document (e.g. "Quotation", "Sales Order Confirmation", "Delivery Note", "Packing Slip").

---

## SwiftUI previews

`SwiftlyPDFKitUI` provides `PDFPreviewView` for live Xcode canvas previews:

```swift
import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

#Preview("Invoice", traits: .fixedLayout(width: 595, height: 842)) {
    PDFPreviewView {
        Page(size: .a4) {
            Text("Preview content").font(.helvetica, size: 16)
        }
    }
}
```

Or preview a pre-built PDF:

```swift
let pdf = PDF(layout: .classic, invoice: invoice, theme: .standard)

#Preview("Classic Invoice", traits: .fixedLayout(width: 595, height: 842)) {
    PDFPreviewView(pdf)
}
```

---

## Demos

The project includes 15 demo configurations covering every layout, theme, and document type. Each demo has a SwiftUI `#Preview` for the Xcode canvas and a corresponding CLI generator.

| # | Name | Type | Layout | Theme |
|---|------|------|--------|-------|
| 01 | Standard | Invoice | classic | standard |
| 02 | Gold | Invoice | classic | gold |
| 03 | Corporate | Invoice | classic | corporate |
| 04 | Purple | Invoice | classic | custom (Times, logo right) |
| 05 | Green | Invoice | classic | custom (logo top-center) |
| 06 | Partial Payment | Invoice | classic | standard |
| 07 | Mono | Invoice | classic | custom (Courier, Letter) |
| 08 | Sidebar | Invoice | classicWithSidebar | corporate |
| 09 | Minimal | Invoice | minimal | standard |
| 10 | Stacked | Invoice | stacked | custom (teal) |
| 11 | Summary First | Invoice | summaryFirst | gold |
| 12 | Quote | Quote | classic | standard |
| 13 | Sales Order | Sales Order | classic | corporate |
| 14 | Delivery | Delivery | standard | standard |
| 15 | Shipment | Shipment | standard | corporate |

### Generate demo PDFs

```bash
swift run GenerateDemos
```

Outputs 15 PDF files to `DemoPDFs/` at the package root.

---

## Project structure

```
Sources/
  SwiftlyPDFKit/
    Core/
      PDF.swift               # Entry point, rendering
      Page.swift              # Page, PageSize
      PDFContent.swift        # PDFContent protocol, Text, Spacer, HRule
      ContentBuilder.swift    # @ContentBuilder result builder
      Color.swift             # PDFColor
      Font.swift              # PDFFont
      Table.swift             # Table, Column, TableStyle
      Columns.swift           # Columns, ColumnItem
      FilledBox.swift         # Colored background container
      ImageContent.swift      # Image rendering
      QRCodeContent.swift     # QR code generation
      Footer.swift            # Page footer
      HTMLToPDFConverter.swift # Linux HTML-to-PDF via wkhtmltopdf
      HTMLUtilities.swift      # HTML escaping helpers
    Documents/
      Invoice/
        Invoice.swift         # Data model (Supplier, Client, Header, Line, etc.)
        InvoiceTheme.swift    # Theme presets and customization
        InvoiceLayout.swift   # 5 layout implementations
      Shared/
        DocumentSupplement.swift    # Quote/SalesOrder/Delivery/Shipment supplements
        DocumentLayoutHelpers.swift # Shared drawing helpers
      Quote/                  # Quote layout + builder
      SalesOrder/             # Sales order layout + builder
      Delivery/               # Delivery note layout + builder
      Shipment/               # Shipment document layout + builder
  SwiftlyPDFKitUI/
    PDFPreviewView.swift      # SwiftUI wrapper (iOS + macOS)
  DemoPDFKit/                 # 15 demo files + shared fixtures
  GenerateDemos/
    main.swift                # CLI tool for batch PDF generation
```

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| [swift-qrcode-generator](https://github.com/fwcd/swift-qrcode-generator) | ~> 1.0 | Pure-Swift QR code encoder (cross-platform) |

**Apple platforms**: CoreGraphics, CoreText (macOS/iOS), PDFKit (SwiftUI previews only).
**Linux**: `wkhtmltopdf` system binary for HTML-to-PDF conversion (install with `apt-get install wkhtmltopdf`).

---

## Requirements

- **Swift 6.0+**
- **macOS 12+** or **iOS 15+** for Apple platforms
- **Linux**: Swift 6.0+ toolchain and `wkhtmltopdf` (`apt-get install wkhtmltopdf`)

---

## License

MIT
