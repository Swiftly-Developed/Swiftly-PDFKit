import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - ShipmentLayoutBuilder (internal)

enum ShipmentLayoutBuilder {

    // MARK: - Standard

    static func standardLayout(
        invoice: InvoiceDocument,
        supplement: ShipmentSupplement,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        // ── Height accounting ──────────────────────────────────────────────
        let rowH:         CGFloat = theme.lineItemRowHeight
        let headerHeight: CGFloat = theme.logoMaxHeight + 13 + 52
        let carrierH:     CGFloat = 38 + 12   // FilledBox height + spacer
        let shipToH:      CGFloat = supplement.shipToAddress != nil ? 46 : 0
        let metaHeight:   CGFloat = 70
        let page1Overhead: CGFloat = headerHeight + 12 + carrierH + shipToH + 20 + metaHeight + 20
        let tableHeaderH: CGFloat = rowH

        let notesH:  CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let sigH:    CGFloat = supplement.signatureRequired ? 28 + 8 + 10 + 18 + 26 : 0
        let lastPageBottomH: CGFloat = notesH + sigH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        // ── Pass 1 ────────────────────────────────────────────────────────
        var chunks: [[InvoiceLine]] = []
        var remaining = invoice.lines

        let p1Take = min(p1RowsMax, remaining.count)
        chunks.append(Array(remaining.prefix(p1Take)))
        remaining = Array(remaining.dropFirst(p1Take))

        while !remaining.isEmpty {
            let take = min(contRowsMax, remaining.count)
            chunks.append(Array(remaining.prefix(take)))
            remaining = Array(remaining.dropFirst(take))
        }

        // ── Pass 2 ────────────────────────────────────────────────────────
        if let last = chunks.last {
            let isFirst  = chunks.count == 1
            let overhead = isFirst ? page1Overhead : 0
            let lastUsed = overhead + tableHeaderH + CGFloat(last.count) * rowH
            if lastUsed + lastPageBottomH > bodyH {
                chunks.append([])
            }
        }

        // ── Shipment line items table (no pricing) ─────────────────────────
        let hasNotes = invoice.lines.contains { $0.detail != nil }

        func shipmentTable(rows: [InvoiceLine]) -> some PDFContent {
            let dataRows = rows.map { line -> [String] in
                var cells = [
                    line.description,
                    fmt.quantity(line.quantity),
                    line.unit ?? "",
                ]
                if hasNotes { cells.append(line.detail ?? "") }
                return cells
            }
            let style = TableStyle(
                headerBackground: theme.tableHeaderBackground,
                headerTextColor:  theme.tableHeaderTextColor,
                headerFontSize:   theme.tableHeaderFontSize,
                cellFontSize:     theme.tableCellFontSize,
                rowHeight:        rowH,
                alternateRowColor: theme.tableAlternateRowColor,
                borderColor:      theme.tableBorderColor,
                borderWidth:      0.5,
                cellPadding:      4,
                cellBold:         false
            )
            if hasNotes {
                return Table(data: dataRows, style: style, showHeader: true) {
                    Column("Description", width: .flex,       alignment: .leading)
                    Column("Qty",         width: .fixed(45),  alignment: .trailing)
                    Column("Unit",        width: .fixed(45),  alignment: .leading)
                    Column("Notes",       width: .fixed(130), alignment: .leading)
                }
            } else {
                return Table(data: dataRows, style: style, showHeader: true) {
                    Column("Description", width: .flex,      alignment: .leading)
                    Column("Qty",         width: .fixed(55), alignment: .trailing)
                    Column("Unit",        width: .fixed(55), alignment: .leading)
                }
            }
        }

        // ── Page builder ───────────────────────────────────────────────────
        func makeFooter() -> Footer? {
            guard let f = invoice.footer else { return nil }
            return Footer(height: f.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in f.lines {
                    Text(line).font(theme.bodyFont, size: 8).alignment(.center)
                }
            }
        }

        var pages: [Page] = []

        for (pageIdx, chunk) in chunks.enumerated() {
            let isFirst = pageIdx == 0
            let isLast  = pageIdx == chunks.count - 1

            let page = Page(size: pageSize, margins: margins) {
                if isFirst {
                    InvoiceLayoutBuilder.headerSection(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 12)
                    for item in carrierBlock(
                        carrier: supplement.carrier,
                        trackingNumber: supplement.trackingNumber,
                        estimatedDelivery: supplement.estimatedDelivery,
                        theme: theme
                    ) { item }
                    Spacer(height: 12)
                    if let addr = supplement.shipToAddress {
                        for item in shipToAddressBlock(address: addr, theme: theme) { item }
                        Spacer(height: 12)
                    }
                    shipmentMetaSection(invoice: invoice, supplement: supplement,
                                        theme: theme, fmt: fmt)
                    Spacer(height: 20)
                }

                shipmentTable(rows: chunk)

                if isLast {
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }
                    if supplement.signatureRequired {
                        for item in signatureBlock(label: supplement.signatureLabel, theme: theme) {
                            item
                        }
                    }
                }

                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                InvoiceLayoutBuilder.headerSection(invoice: invoice, theme: theme, fmt: fmt)
                Spacer(height: 12)
                for item in carrierBlock(
                    carrier: supplement.carrier,
                    trackingNumber: supplement.trackingNumber,
                    estimatedDelivery: supplement.estimatedDelivery,
                    theme: theme
                ) { item }
                Spacer(height: 12)
                if let addr = supplement.shipToAddress {
                    for item in shipToAddressBlock(address: addr, theme: theme) { item }
                    Spacer(height: 12)
                }
                shipmentMetaSection(invoice: invoice, supplement: supplement, theme: theme, fmt: fmt)
                Spacer(height: 20)
                shipmentTable(rows: [])
                if supplement.signatureRequired {
                    for item in signatureBlock(label: supplement.signatureLabel, theme: theme) {
                        item
                    }
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - Compact (always single page, no table)

    static func compactLayout(
        invoice: InvoiceDocument,
        supplement: ShipmentSupplement,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)
        let margins = theme.pageMargins

        func makeFooter() -> Footer? {
            guard let f = invoice.footer else { return nil }
            return Footer(height: f.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in f.lines {
                    Text(line).font(theme.bodyFont, size: 8).alignment(.center)
                }
            }
        }

        let page = Page(size: pageSize, margins: margins) {
            InvoiceLayoutBuilder.headerSection(invoice: invoice, theme: theme, fmt: fmt)
            Spacer(height: 12)
            for item in carrierBlock(
                carrier: supplement.carrier,
                trackingNumber: supplement.trackingNumber,
                estimatedDelivery: supplement.estimatedDelivery,
                theme: theme
            ) { item }
            Spacer(height: 12)
            if let addr = supplement.shipToAddress {
                for item in shipToAddressBlock(address: addr, theme: theme) { item }
                Spacer(height: 12)
            }
            shipmentMetaSection(invoice: invoice, supplement: supplement, theme: theme, fmt: fmt)
            Spacer(height: 20)
            // Plain-text item list (no Table)
            Text("Items shipped:")
                .font(theme.bodyFont, size: theme.bodyFontSize)
                .bold()
            Spacer(height: 6)
            for line in invoice.lines {
                Columns(spacing: 8) {
                    ColumnItem(width: .flex) {
                        Text("• \(line.description)").font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                    ColumnItem(width: .fixed(80)) {
                        Text("\(fmt.quantity(line.quantity)) \(line.unit ?? "")")
                            .font(theme.bodyFont, size: theme.bodyFontSize)
                            .alignment(.trailing)
                    }
                }
            }
            if let notes = invoice.header.notes {
                Spacer(height: 12)
                Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
            }
            if supplement.signatureRequired {
                for item in signatureBlock(label: supplement.signatureLabel, theme: theme) {
                    item
                }
            }
            if let f = makeFooter() { f }
        }

        return PDF(pages: [page])
    }

    // MARK: - Section helpers

    static func shipmentMetaSection(
        invoice: InvoiceDocument,
        supplement: ShipmentSupplement,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let h = invoice.header
        return Columns(spacing: 20) {
            ColumnItem(width: .fixed(260)) {
                Columns(spacing: 0) {
                    ColumnItem(width: .fixed(110)) {
                        Text(fmt.label("Shipment No."))
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if h.issueDate.isEmpty == false {
                            Text(fmt.label("Ship Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.clientNumber != nil {
                            Text(fmt.label("Account No."))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.poNumber != nil {
                            Text(fmt.label("Order Ref."))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                    }
                    ColumnItem(width: .flex) {
                        Text(": \(h.invoiceNumber)")
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if h.issueDate.isEmpty == false {
                            Text(": \(h.issueDate)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let cn = invoice.client.clientNumber {
                            Text(": \(cn)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let po = invoice.client.poNumber {
                            Text(": \(po)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                    }
                }
            }
            ColumnItem(width: .flex) {
                Text(h.documentTitle)
                    .font(theme.titleFont, size: theme.titleFontSize)
                    .bold()
                    .italic()
                    .alignment(.center)
            }
        }
    }
}
