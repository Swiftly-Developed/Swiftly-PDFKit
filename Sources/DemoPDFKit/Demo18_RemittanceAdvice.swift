import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 18 · Remittance Advice · Standard theme

// A batch advice that is not yet submitted (watermark): two member payments
// settling an EUR invoice net of a cash discount, a USD invoice paid in EUR
// (the rate sub-row), an invoice short-paid with an adjustment and a credit
// note — each document cell stacking the payee's number, the type, our
// reference and the paying member. One EUR totals stack with an on-account
// remainder, a remittance text shortened to what the bank transmits, notes,
// and the queries line. The issuer is the shared demo supplier; its IBAN
// prints (the account the payment leaves from).
@MainActor private let remittanceLabels = RemittanceAdviceLabels.english
@MainActor private let remittancePaymentLabels = PaymentReceiptLabels.english

@MainActor private let remittanceFullText = "Payment of invoices INV-DE-77812 and INV-DE-77840 for September deliveries "
    + "under framework agreement FA-2026-03, net of the agreed cash discount and the short-delivery adjustment"

@MainActor private let remittanceDocument = RemittanceAdviceDocument(
    issuer: demoSupplier,
    payee: RemittanceAdvicePayee(
        party: InvoiceParty(
            name: "Bosch Industrial Supply GmbH",
            street: "Robert-Bosch-Platz 1",
            city: "70839 Gerlingen",
            country: "Germany",
            vatNumber: "DE811128135"
        ),
        registerNumber: "HRB 14000",
        supplierNumber: "V-00017",
        yourReferenceForUs: "CUST-88213",
        paidToAccount: "•••• 3000",
        paidToBIC: "DEUTDEFF"
    ),
    header: RemittanceAdviceHeader(
        batchReference: "MSG-20261028-001 / V-00017", adviceDate: "2026-10-30", generatedOn: "2026-10-28 15:10"
    ),
    paymentFacts: [
        RemittanceAdviceFact(caption: remittanceLabels.executionDateLabel, value: "2026-10-30"),
        RemittanceAdviceFact(
            caption: remittancePaymentLabels.paymentMethodLabel,
            value: remittancePaymentLabels.paymentMeansSEPACreditTransfer
        ),
        RemittanceAdviceFact(caption: remittanceLabels.amountPaidLabel, value: "4,312.50 EUR"),
        RemittanceAdviceFact(caption: remittanceLabels.ourBankAccountLabel, value: "•••• 9163"),
    ],
    memberPayments: [
        RemittanceAdviceMemberPayment(
            paymentNumber: "VPMT00041", endToEndId: "E2E-7f3a2c10-55b1-4e0b-9d2a-1c3e",
            paymentInfoId: "PMTINF-20261030-01", amount: 3_312.50, currencyCode: "EUR"
        ),
        RemittanceAdviceMemberPayment(
            paymentNumber: "VPMT00042", endToEndId: "E2E-0b9e44d2-7a6c-4f21-8e03-a4d1",
            paymentInfoId: "PMTINF-20261030-01", amount: 1_000, currencyCode: "EUR"
        ),
    ],
    details: [
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77812", theirDate: "2026-09-15", ourReference: "VBILL00031",
            documentCurrencyCode: "EUR", gross: 2_500, paidByOtherPayments: 0,
            applied: 2_450, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            discount: RemittanceAdviceAmount(value: 50, currencyCode: "EUR"), paidByPaymentNumber: "VPMT00041"
        ),
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77840", theirDate: "2026-09-22", ourReference: "VBILL00034",
            documentCurrencyCode: "USD", gross: 1_000, paidByOtherPayments: 0,
            applied: 862.50, appliedCurrencyCode: "EUR", appliedInDocumentCurrency: 1_000, exchangeRate: 1.15942,
            remaining: 0, isSettled: true, paidByPaymentNumber: "VPMT00041"
        ),
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77901", theirDate: "2026-10-02", ourReference: "VBILL00040",
            documentCurrencyCode: "EUR", gross: 1_200, paidByOtherPayments: 0,
            applied: 1_175, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            adjustment: RemittanceAdviceAmount(value: 25, currencyCode: "EUR"), adjustmentReason: "Short delivery",
            paidByPaymentNumber: "VPMT00042"
        ),
        RemittanceAdviceDetailRow(
            kind: .creditNote, theirNumber: "CN-DE-0907", theirDate: "2026-10-05", ourReference: "VCRN00007",
            documentCurrencyCode: "EUR", gross: 300, paidByOtherPayments: 0,
            applied: 300, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            paidByPaymentNumber: "VPMT00042"
        ),
    ],
    totals: [
        RemittanceAdviceTotals(
            currencyCode: "EUR", bills: 4_487.50, discount: 50, adjustments: 25, credits: 300,
            transferred: 4_312.50, onAccount: 125
        ),
    ],
    remittanceLines: [
        RemittanceAdviceTextLine(
            text: String(remittanceFullText.prefix(140)), asSent: true, truncated: true, paymentNumber: "VPMT00041"
        ),
        RemittanceAdviceTextLine(
            text: "RF18 5390 0754 7034", asSent: true, truncated: false, paymentNumber: "VPMT00042"
        ),
    ],
    watermark: .notYetSubmitted,
    notes: "Thank you for the September deliveries.",
    contactEmail: "accounts@swiftly-demo.example"
)

@MainActor private let remittancePdf = RemittanceAdviceLayout.build(
    remittanceDocument,
    theme: .standard
)

@available(macOS 14, iOS 17, *)
#Preview("18 · Remittance Advice", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(remittancePdf)
}
