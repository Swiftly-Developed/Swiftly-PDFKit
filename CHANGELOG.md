# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/Swiftly-Developed/Swiftly-PDFKit/releases/tag/v0.1.0
