import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - RemittanceAdviceLayout + table

/// The remittance advice's display rows, member rows, totals, closing blocks
/// and page-fit accounting. Split out of `RemittanceAdviceLayout.swift` only to
/// keep each file and type body inside the lint limits; it is the same enum.
extension RemittanceAdviceLayout {

    /// The cell printed for a figure the mapper could not state. A typographic
    /// placeholder, not a label: it has no catalog key.
    private static let unavailableCell = "—"

    /// A figure with its ISO 4217 code — never a symbol, because one advice can
    /// carry several currencies. The receipt's allocation-cell shape.
    static func money(_ value: Double, _ code: String, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(locale)) + " " + code
    }

    // MARK: Detail table

    /// The detail table's header: the stacked document cell (the payee's
    /// number, the type, our reference and — in a batch — the paying member)
    /// then the receipt's five column captions.
    static func detailHeader(
        isBatch: Bool, payment: PaymentReceiptLabels, labels: RemittanceAdviceLabels
    ) -> [[String]] {
        [
            [labels.yourReferenceColumn, labels.documentTypeColumn, labels.ourReferenceColumn]
                + (isBatch ? [labels.paidByPaymentColumn] : []),
            [payment.allocationColumnDocumentDate],
            [payment.allocationColumnDocumentTotal],
            [payment.allocationColumnOtherPayments],
            [payment.allocationColumnApplied],
            [payment.allocationColumnRemaining],
        ]
    }

    /// One display group per settled document; a group is never split.
    static func detailGroups(
        _ document: RemittanceAdviceDocument, isBatch: Bool, locale: Locale
    ) -> [[[[String]]]] {
        document.details.map {
            detailGroup($0, isBatch: isBatch, labels: document.labels, payment: document.payment, locale: locale)
        }
    }

    /// A document's main row, then — each only when it applies — the receipt's
    /// rate sub-row, the cash-discount sub-row and the adjustment sub-row.
    ///
    /// The document cell has a fixed line order with "—" for an absent value;
    /// the paying member is read in the batch form only, so a single-form row's
    /// `paidByPaymentNumber` never prints. The payee's date prints in the date
    /// column.
    static func detailGroup(
        _ row: RemittanceAdviceDetailRow,
        isBatch: Bool,
        labels: RemittanceAdviceLabels,
        payment: PaymentReceiptLabels,
        locale: Locale
    ) -> [[[String]]] {
        let code = row.documentCurrencyCode
        let typeCaption = row.kind == .creditNote ? labels.documentTypeCreditNote : labels.documentTypeInvoice
        var documentCell = [row.theirNumber ?? unavailableCell, typeCaption, row.ourReference ?? unavailableCell]
        if isBatch { documentCell.append(row.paidByPaymentNumber ?? unavailableCell) }
        if row.isReversed { documentCell.append(labels.reversedRowMarker) }
        let remaining = row.remaining.map {
            row.isSettled ? payment.allocationSettledMarker : money($0, code, locale: locale)
        } ?? unavailableCell
        var group: [[[String]]] = [[
            documentCell,
            [row.theirDate ?? ""],
            [row.gross.map { money($0, code, locale: locale) } ?? unavailableCell],
            [row.paidByOtherPayments.map { money($0, code, locale: locale) } ?? unavailableCell],
            [money(row.applied, row.appliedCurrencyCode, locale: locale)],
            [remaining],
        ]]
        if let inDocument = row.appliedInDocumentCurrency, let rate = row.exchangeRate {
            let rateString = rate.formatted(.number.precision(.fractionLength(0...6)).locale(locale))
            group.append(subRow(payment.exchangeRate(rateString), money(inDocument, code, locale: locale)))
        }
        if let discount = row.discount, discount.value != 0 {
            group.append(subRow(
                labels.discountColumn, money(discount.value, discount.currencyCode, locale: locale)))
        }
        if let adjustment = row.adjustment, adjustment.value != 0 {
            let caption = nonBlank(row.adjustmentReason).map { labels.adjustmentReason($0) }
                ?? labels.adjustmentColumn
            group.append(subRow(caption, money(adjustment.value, adjustment.currencyCode, locale: locale)))
        }
        return group
    }

    /// A sub-row: the caption in the document column, the figure in the
    /// applied column, every other cell blank.
    static func subRow(_ caption: String, _ figure: String) -> [[String]] {
        [[caption], [""], [""], [""], [figure], [""]]
    }

    // MARK: Member payments (batch form)

    /// The member list's header: payment number, end-to-end ID and payment
    /// information ID stacked, then the amount.
    static func memberPaymentHeader(labels: RemittanceAdviceLabels, payment: PaymentReceiptLabels) -> [[String]] {
        [
            [labels.paymentColumnLabel, payment.endToEndIdLabel, labels.paymentInfoIdLabel],
            [""], [""], [""], [labels.amountPaidLabel], [""],
        ]
    }

    /// One row per member payment; `[]` in the single form.
    static func memberPaymentRows(_ document: RemittanceAdviceDocument, locale: Locale) -> [[[String]]] {
        (document.memberPayments ?? []).map { member in
            var cell = [member.paymentNumber, member.endToEndId ?? unavailableCell,
                        member.paymentInfoId ?? unavailableCell]
            if member.isReversed { cell.append(document.labels.reversedRowMarker) }
            return [cell, [""], [""], [""], [money(member.amount, member.currencyCode, locale: locale)], [""]]
        }
    }

    // MARK: Totals

    /// One currency's totals: bills / discount / adjustments / credits, the
    /// emphasised amount transferred, **on account always** (a zero included)
    /// and one informational row per bank charge in its own currency.
    static func totalsRows(
        _ totals: RemittanceAdviceTotals,
        labels: RemittanceAdviceLabels,
        common: CommonDocumentLabels,
        payment: PaymentReceiptLabels,
        locale: Locale
    ) -> [PaymentDocumentBlocks.TotalsRow] {
        var rows: [PaymentDocumentBlocks.TotalsRow] = [
            .init(caption: labels.totalBillsLabel, value: money(totals.bills, totals.currencyCode, locale: locale)),
        ]
        if let discount = totals.discount, discount != 0 {
            rows.append(.init(caption: common.totalsDiscountLabel,
                              value: money(discount, totals.currencyCode, locale: locale)))
        }
        if let adjustments = totals.adjustments, adjustments != 0 {
            rows.append(.init(caption: labels.totalAdjustmentsLabel,
                              value: money(adjustments, totals.currencyCode, locale: locale)))
        }
        if let credits = totals.credits {
            rows.append(.init(caption: labels.totalCreditsLabel,
                              value: money(credits, totals.currencyCode, locale: locale)))
        }
        rows.append(.init(caption: labels.totalTransferredLabel,
                          value: money(totals.transferred, totals.currencyCode, locale: locale),
                          emphasised: true))
        rows.append(.init(caption: labels.totalOnAccountLabel, value: money(totals.onAccount, totals.currencyCode, locale: locale)))
        for charge in totals.charges {
            rows.append(.init(caption: payment.bankChargesLabel,
                              value: money(charge.value, charge.currencyCode, locale: locale)))
        }
        return rows
    }

    // MARK: Closing blocks

    /// One indivisible run of the closing blocks and its estimated height.
    struct ClosingUnit {
        let height: CGFloat
        let contents: [any PDFContent]
    }

    /// The gap above the remittance caption, the status notice and the notes
    /// (phase 07d: 12 → 10); `totalsUnit` has its own.
    static let closingGap: CGFloat = 10

    /// The closing blocks in print order: the totals (one stack per currency,
    /// together, always first), each remittance line (the caption rides with the
    /// first, a truncation notice with its own), the status notice, the notes.
    static func closingUnits(
        _ document: RemittanceAdviceDocument, theme: InvoiceTheme, locale: Locale, contentWidth: CGFloat
    ) -> [ClosingUnit] {
        let labels = document.labels, payment = document.payment
        var units = [totalsUnit(document, theme: theme, locale: locale)]
        let lines = document.remittanceLines
        let remittanceCaption = lines.allSatisfy { $0.asSent } ? labels.remittanceTextAsSentLabel : payment.remittanceInformationLabel
        let lineSize = theme.bodyFontSize - 1
        for (lineIndex, line) in lines.enumerated() {
            var contents: [any PDFContent] = []
            var height: CGFloat = 0
            if lineIndex == 0 {
                contents.append(Spacer(height: closingGap))
                contents.append(
                    Text(remittanceCaption)
                        .font(theme.bodyFont, size: 8)
                        .bold()
                        .color(DocumentLayoutKit.mutedText))
                height += closingGap + textHeight(remittanceCaption, width: contentWidth, size: 8)
            }
            let lineText = remittanceLineText(line)
            contents.append(
                Text(lineText)
                    .font(theme.bodyFont, size: lineSize))
            height += textHeight(lineText, width: contentWidth, size: lineSize)
            if line.truncated {
                contents.append(
                    Text(labels.remittanceTruncatedNotice)
                        .font(theme.bodyFont, size: 8)
                        .color(DocumentLayoutKit.mutedText))
                height += textHeight(labels.remittanceTruncatedNotice, width: contentWidth, size: 8)
            }
            units.append(ClosingUnit(height: height, contents: contents))
        }
        if let notice = statusNotice(document.watermark, labels: labels, payment: payment) {
            units.append(ClosingUnit(
                height: closingGap + textHeight(notice, width: contentWidth, size: theme.bodyFontSize),
                contents: [
                    Spacer(height: closingGap),
                    Text(notice)
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                        .bold(),
                ]))
        }
        if let notes = nonBlank(document.notes) {
            let notesH = notes.split(separator: "\n", omittingEmptySubsequences: false).reduce(CGFloat(0)) {
                $0 + textHeight(String($1), width: contentWidth, size: lineSize)
            }
            units.append(ClosingUnit(
                height: closingGap + textHeight(payment.notesLabel, width: contentWidth, size: 8) + notesH,
                contents: [
                    Spacer(height: closingGap),
                    Text(payment.notesLabel)
                        .font(theme.bodyFont, size: 8)
                        .bold()
                        .color(DocumentLayoutKit.mutedText),
                    Text(notes)
                        .font(theme.bodyFont, size: lineSize)
                        .color(DocumentLayoutKit.mutedText),
                ]))
        }
        return units
    }

    /// The gap between the last settled row and the totals (phase 07d: 14 → 10).
    static let totalsGap: CGFloat = 10

    /// The totals unit: one stack per currency, with the receipt's stack and the
    /// height of what it really draws (a caption cell 158 pt wide, a value cell
    /// 110 pt wide, a hairline above an emphasised row).
    static func totalsUnit(
        _ document: RemittanceAdviceDocument, theme: InvoiceTheme, locale: Locale
    ) -> ClosingUnit {
        var contents: [any PDFContent] = [Spacer(height: totalsGap)]
        var height: CGFloat = totalsGap
        for (index, totals) in document.totals.enumerated() {
            if index > 0 {
                contents.append(Spacer(height: 10))
                height += 10
            }
            let rows = totalsRows(
                totals, labels: document.labels, common: document.common, payment: document.payment, locale: locale)
            contents += PaymentDocumentBlocks.totalsStack(rows, theme: theme)
            for row in rows {
                height += max(
                    textHeight(row.caption, width: 158, size: theme.bodyFontSize),
                    textHeight(row.value, width: 110, size: theme.bodyFontSize))
                    + (row.emphasised ? 2 + 4.5 + 2 : 0)
            }
        }
        return ClosingUnit(height: height, contents: contents)
    }

    /// A remittance line, prefixed with its payment number in the batch form.
    static func remittanceLineText(_ line: RemittanceAdviceTextLine) -> String {
        (line.paymentNumber.map { $0 + " · " } ?? "") + line.text
    }

    // MARK: Page-fit accounting — no design authority

    /// A line of `size` on the taller of the two render paths: CoreText draws it
    /// in `size + 2` for the kit's faces, HTML in `size * 1.2`.
    static func lineHeight(_ size: CGFloat) -> CGFloat {
        max(size + 2, size * 1.2)
    }

    /// Estimated height of `text` wrapped into `width`, never less than a line.
    static func textHeight(_ text: String, width: CGFloat, size: CGFloat) -> CGFloat {
        CGFloat(max(1, PaymentDocumentBlocks.estimatedLineCount(text, width: width, fontSize: size)))
            * lineHeight(size)
    }

    /// Height of `DocumentLayoutKit.metadataGrid` for `rows`: each grid row is
    /// its tallest caption + value, plus the grid's 6 pt spacer.
    static func gridHeight(
        rows: [(caption: String, value: String)], columns: Int, theme: InvoiceTheme, contentWidth: CGFloat
    ) -> CGFloat {
        let width = (contentWidth - 12 * CGFloat(columns - 1)) / CGFloat(columns)
        return stride(from: 0, to: rows.count, by: columns).reduce(CGFloat(0)) { total, start in
            let tallest = rows[start..<min(start + columns, rows.count)].map {
                textHeight($0.caption, width: width, size: 8)
                    + textHeight($0.value, width: width, size: theme.bodyFontSize)
            }.max() ?? 0
            return total + tallest + 6
        }
    }

    /// Height of page 1's head blocks: masthead, header grid and the taller of
    /// the two party columns (never the member list — the member pass sizes it).
    static func headOverhead(
        _ document: RemittanceAdviceDocument, theme: InvoiceTheme, contentWidth: CGFloat
    ) -> CGFloat {
        let titleH = DocumentLayoutKit.modernTitleSize * 1.2
        let mastheadH = (document.issuer.logoPath == nil ? titleH : max(theme.logoMaxHeight, titleH)) + mastheadGap
        let metaH = gridHeight(rows: batchReferenceRow(document), columns: 1, theme: theme, contentWidth: contentWidth)
            + gridHeight(rows: headerRows(document), columns: 3, theme: theme, contentWidth: contentWidth)
            + headerGridGap
        let width = (contentWidth - 24) / 2
        return mastheadH + metaH + max(issuerHeight(document, theme: theme, width: width),
                                       payeeHeight(document, theme: theme, width: width)) + partiesGap
    }

    /// Height of `DocumentLayoutKit.supplierIdentityBlock` for the issuer.
    static func issuerHeight(_ document: RemittanceAdviceDocument, theme: InvoiceTheme, width: CGFloat) -> CGFloat {
        let issuer = document.issuer, common = document.common
        let address = [issuer.street, issuer.city, issuer.country].compactMap { $0 }
        let groups = [
            [issuer.vatNumber.map { "\(common.vatNumberLabel) \($0)" },
             DocumentLayoutKit.registrationNumber(for: issuer).map { "\(common.registrationNumberLabel) \($0)" }],
            [issuer.iban.map { "\(common.ibanLabel) \($0)" }, issuer.bic.map { "\(common.bicLabel) \($0)" }],
            [issuer.phone.map { "\(common.phoneLabel) \($0)" }, issuer.email.map { "\(common.emailLabel) \($0)" },
             issuer.website.map { "\(common.websiteLabel) \($0)" }],
        ].map { $0.compactMap { $0 } }.filter { !$0.isEmpty }
        return textHeight(issuer.name, width: width, size: theme.titleFontSize)
            + address.reduce(CGFloat(0)) { $0 + textHeight($1, width: width, size: theme.bodyFontSize) }
            + groups.reduce(CGFloat(0)) {
                $0 + 4 + textHeight($1.joined(separator: DocumentLayoutKit.separator), width: width, size: 8)
            }
    }

    /// Height of the payee's column: its party block, then its identifier lines.
    static func payeeHeight(_ document: RemittanceAdviceDocument, theme: InvoiceTheme, width: CGFloat) -> CGFloat {
        let party = document.payee.party
        let lines = [party.attention, party.street, party.city, party.country,
                     party.vatNumber.map { "\(document.common.vatNumberLabel) \($0)" }].compactMap { $0 }
        let extras = payeeExtras(document)
        return textHeight(document.labels.paidToLabel, width: width, size: 8) + 3
            + textHeight(party.name, width: width, size: theme.bodyFontSize)
            + lines.reduce(CGFloat(0)) { $0 + textHeight($1, width: width, size: theme.bodyFontSize) }
            + (extras.isEmpty ? 0 : 4)
            + extras.reduce(CGFloat(0)) { $0 + textHeight($1, width: width, size: 8) }
    }

    /// Height of the facts grid and its spacer; `0` when there are no facts.
    static func factsHeight(
        _ document: RemittanceAdviceDocument, theme: InvoiceTheme, contentWidth: CGFloat
    ) -> CGFloat {
        document.paymentFacts.isEmpty ? 0
            : gridHeight(
                rows: document.paymentFacts.map { (caption: $0.caption, value: $0.value) },
                columns: 2, theme: theme, contentWidth: contentWidth) + factsGap
    }

    /// Height of the table's empty state: its two spacers around one line.
    static func emptyStateHeight(theme: InvoiceTheme) -> CGFloat {
        6 + lineHeight(theme.bodyFontSize - 1) + 4
    }
}
