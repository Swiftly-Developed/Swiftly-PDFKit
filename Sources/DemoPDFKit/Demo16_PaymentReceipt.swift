import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 16 · Payment Receipt · Standard theme

// The widest row shape: one settled document, one partial with a long
// tenant-configured number (it wraps in its column), one in a foreign
// currency with its rate sub-row and "—" for the two figures it cannot state
// in that currency (§25 #27); a positive unallocated remainder; a bank
// charge; notes; and a reversal with a known reason code (watermark + notice).
@MainActor private let paymentReceiptDocument = PaymentReceiptDocument(
    supplier: demoSupplier,
    payer: PaymentReceiptPayer(
        party: InvoiceParty(
            name: "Client BV",
            attention: "Jane Doe",
            street: "Client Road 42",
            city: "1000 Brussels",
            country: "Belgium",
            vatNumber: "BE 0987.654.321"
        ),
        registerNumber: "0987.654.321",
        customerReference: "C-042"
    ),
    header: PaymentReceiptHeader(receiptNumber: "RCPT-2026-0016", receiptDate: "2026-02-19"),
    paymentFacts: [
        PaymentReceiptFact(caption: "Payment date", value: "2026-02-18"),
        PaymentReceiptFact(caption: "Value date", value: "2026-02-18"),
        PaymentReceiptFact(caption: "Payment method", value: "SEPA credit transfer"),
        PaymentReceiptFact(caption: "Bank reference", value: "BNK-2026-88231"),
    ],
    allocations: [
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-001", documentDate: "2026-01-10",
            documentCurrencyCode: "EUR", documentTotal: 1_210, paidByOtherPayments: 0,
            appliedAmount: 1_210, remaining: 0, isSettled: true),
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-ANTWERP-HQ-000004", documentDate: "2026-01-14",
            documentCurrencyCode: "EUR", documentTotal: 2_420, paidByOtherPayments: 400,
            appliedAmount: 1_000, remaining: 1_020, isSettled: false),
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-007", documentDate: "2026-01-20",
            documentCurrencyCode: "USD", documentTotal: 650, paidByOtherPayments: nil,
            appliedAmount: 552.60, appliedInDocumentCurrency: 600, exchangeRate: 1.0858,
            remaining: nil, isSettled: false),
    ],
    totals: PaymentReceiptTotals(
        currencyCode: "EUR", received: 3_000, allocated: 2_762.60, unallocated: 237.40,
        charges: [PaymentReceiptCharge(amount: 2.50, currencyCode: "EUR")]
    ),
    reversal: PaymentReceiptReversal(reasonCode: "MD06"),
    notes: "The unallocated remainder is held on account against future invoices."
)

@MainActor private let paymentReceiptPdf = PaymentReceiptLayout.build(
    paymentReceiptDocument,
    theme: .standard
)

@available(macOS 14, iOS 17, *)
#Preview("16 · Payment Receipt", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(paymentReceiptPdf)
}
