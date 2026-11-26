import Foundation

// MARK: - PurchaseOrderDocument

/// Everything the purchase-order family renders: one order the issuing company
/// places with a supplier.
///
/// Its own model rather than a reuse of the invoice model: the issuer is the
/// **buyer**, the counter-party is a supplier, a line may be a stock item, a
/// service or an expense, and the tax figures are indicative.
///
/// Mappers hand the package **resolved display values**: dates arrive as
/// formatted strings (the mapper owns the timezone rule), the optional header
/// rows arrive as an ordered, already-captioned list, and every filtering
/// decision (closed-short lines, a line's expected date that equals the
/// header's, a zero-tax breakdown) is the mapper's. Money, quantities and rates
/// stay numbers and are formatted by the layout in the document's locale.
public struct PurchaseOrderDocument: Sendable {
    /// The issuing (buying) company — the letterhead, its `logoPath` included.
    /// Its bank details are never printed, whatever the caller passes.
    public var issuer: InvoiceSupplier
    /// The supplier the order is placed with.
    public var vendor: PurchaseOrderDocumentVendor
    /// Where the goods go; `nil` omits the block.
    public var deliverTo: PurchaseOrderDocumentDeliverTo?
    /// Order number and dates.
    public var header: PurchaseOrderDocumentHeader
    /// The optional header rows (requested by, supplier reference, expected
    /// delivery, payment terms, delivery terms, currency), ordered and already
    /// captioned. Absent rows are simply not in the list.
    public var metadataRows: [PurchaseOrderDocumentMetadataRow]
    /// The printed lines, already ordered; closed-short lines already removed.
    public var lines: [PurchaseOrderDocumentLine]
    /// How many closed-short lines were left off; `0` prints no count line.
    public var closedShortOmittedCount: Int
    /// One row per tax rate; `[]` omits the breakdown.
    public var taxRows: [PurchaseOrderDocumentTaxRow]
    /// The totals stack.
    public var totals: PurchaseOrderDocumentTotals
    /// The order's supplier-facing instructions; never its internal notes.
    public var specialInstructions: String?
    /// The draft / cancelled marking.
    public var watermark: PurchaseOrderDocumentWatermark
    /// The purchase-order-specific captions.
    public var labels: PurchaseOrderLabels
    /// The family-neutral captions the shared blocks, totals and footer read.
    public var common: CommonDocumentLabels

    public init(
        issuer: InvoiceSupplier,
        vendor: PurchaseOrderDocumentVendor,
        deliverTo: PurchaseOrderDocumentDeliverTo? = nil,
        header: PurchaseOrderDocumentHeader,
        metadataRows: [PurchaseOrderDocumentMetadataRow] = [],
        lines: [PurchaseOrderDocumentLine] = [],
        closedShortOmittedCount: Int = 0,
        taxRows: [PurchaseOrderDocumentTaxRow] = [],
        totals: PurchaseOrderDocumentTotals,
        specialInstructions: String? = nil,
        watermark: PurchaseOrderDocumentWatermark = .none,
        labels: PurchaseOrderLabels = .english,
        common: CommonDocumentLabels = .english
    ) {
        self.issuer = issuer
        self.vendor = vendor
        self.deliverTo = deliverTo
        self.header = header
        self.metadataRows = metadataRows
        self.lines = lines
        self.closedShortOmittedCount = closedShortOmittedCount
        self.taxRows = taxRows
        self.totals = totals
        self.specialInstructions = specialInstructions
        self.watermark = watermark
        self.labels = labels
        self.common = common
    }
}

// MARK: - PurchaseOrderDocumentVendor

/// The supplier, with the two identifiers an order prints beside it.
public struct PurchaseOrderDocumentVendor: Sendable {
    /// Postal / legal block.
    public var party: InvoiceParty
    /// The supplier's commercial-register number, when known.
    public var registerNumber: String?
    /// The issuer's own number for this supplier.
    public var vendorNumber: String?

    public init(party: InvoiceParty, registerNumber: String? = nil, vendorNumber: String? = nil) {
        self.party = party
        self.registerNumber = registerNumber
        self.vendorNumber = vendorNumber
    }
}

// MARK: - PurchaseOrderDocumentDeliverTo

/// The receiving location: a warehouse, a free-text delivery address, or both.
/// The block is omitted when neither is present.
public struct PurchaseOrderDocumentDeliverTo: Sendable {
    /// The warehouse's name and address lines.
    public var warehouse: InvoiceParty?
    /// The warehouse's code, printed under the warehouse block.
    public var warehouseCode: String?
    /// A free-text delivery address, printed verbatim.
    public var deliveryAddress: String?

    public init(warehouse: InvoiceParty? = nil, warehouseCode: String? = nil, deliveryAddress: String? = nil) {
        self.warehouse = warehouse
        self.warehouseCode = warehouseCode
        self.deliveryAddress = deliveryAddress
    }
}

// MARK: - PurchaseOrderDocumentHeader

/// Order identity, already formatted.
public struct PurchaseOrderDocumentHeader: Sendable {
    /// `nil` while the order is a draft: the draft placeholder prints instead.
    public var orderNumber: String?
    public var orderDate: String
    /// The revision number, when the host prints one.
    public var revision: Int?
    /// The generation timestamp, when the host prints one.
    public var generatedOn: String?

    public init(orderNumber: String? = nil, orderDate: String, revision: Int? = nil, generatedOn: String? = nil) {
        self.orderNumber = orderNumber
        self.orderDate = orderDate
        self.revision = revision
        self.generatedOn = generatedOn
    }
}

// MARK: - PurchaseOrderDocumentMetadataRow

/// One captioned header row (e.g. "Payment terms" · "Net 30 (30-day term)").
public struct PurchaseOrderDocumentMetadataRow: Sendable {
    public var caption: String
    public var value: String

    public init(caption: String, value: String) {
        self.caption = caption
        self.value = value
    }
}

// MARK: - PurchaseOrderDocumentLine

/// One order line, of any kind.
///
/// A stock line carries `itemSKU` / `itemName`; a service or expense line
/// leaves both `nil` and carries only its `description`. Rates are 0–100
/// percentages; a `nil` (or zero) discount and a `nil` tax rate print an empty
/// cell. `expectedDelivery` is set by the mapper only when it differs from the
/// order's own date; `note` is the line's supplier-facing note.
public struct PurchaseOrderDocumentLine: Sendable {
    public var itemSKU: String?
    public var itemName: String?
    public var description: String?
    public var quantity: Double
    public var unitOfMeasure: String?
    public var unitCost: Double
    public var discountPercent: Double?
    public var taxRatePercent: Double?
    public var lineTotal: Double
    public var expectedDelivery: String?
    public var note: String?

    public init(
        itemSKU: String? = nil,
        itemName: String? = nil,
        description: String? = nil,
        quantity: Double,
        unitOfMeasure: String? = nil,
        unitCost: Double,
        discountPercent: Double? = nil,
        taxRatePercent: Double? = nil,
        lineTotal: Double,
        expectedDelivery: String? = nil,
        note: String? = nil
    ) {
        self.itemSKU = itemSKU
        self.itemName = itemName
        self.description = description
        self.quantity = quantity
        self.unitOfMeasure = unitOfMeasure
        self.unitCost = unitCost
        self.discountPercent = discountPercent
        self.taxRatePercent = taxRatePercent
        self.lineTotal = lineTotal
        self.expectedDelivery = expectedDelivery
        self.note = note
    }
}

// MARK: - PurchaseOrderDocumentTaxRow

/// Everything taxed at one rate. `name` (e.g. a tax code's display name)
/// replaces the formatted rate in the rate cell when set.
public struct PurchaseOrderDocumentTaxRow: Sendable {
    public var name: String?
    public var ratePercent: Double
    public var taxableBase: Double
    public var taxAmount: Double

    public init(name: String? = nil, ratePercent: Double, taxableBase: Double, taxAmount: Double) {
        self.name = name
        self.ratePercent = ratePercent
        self.taxableBase = taxableBase
        self.taxAmount = taxAmount
    }
}

// MARK: - PurchaseOrderDocumentTotals

/// The totals stack, in the order's currency. A `nil` or zero discount and
/// shipping print no row; the tax row always prints, a zero included.
public struct PurchaseOrderDocumentTotals: Sendable {
    /// ISO 4217 code, printed after every totals value.
    public var currencyCode: String
    public var subtotal: Double
    public var discount: Double?
    public var shipping: Double?
    public var tax: Double
    public var total: Double

    public init(
        currencyCode: String,
        subtotal: Double,
        discount: Double? = nil,
        shipping: Double? = nil,
        tax: Double,
        total: Double
    ) {
        self.currencyCode = currencyCode
        self.subtotal = subtotal
        self.discount = discount
        self.shipping = shipping
        self.tax = tax
        self.total = total
    }
}

// MARK: - PurchaseOrderDocumentWatermark

/// The full-bleed marking on every page: none, the common draft word, or the
/// cancelled word (with a notice line when the cancellation date is known).
public enum PurchaseOrderDocumentWatermark: Sendable, Equatable {
    case none
    case draft
    case cancelled(cancelledOn: String?)
}
