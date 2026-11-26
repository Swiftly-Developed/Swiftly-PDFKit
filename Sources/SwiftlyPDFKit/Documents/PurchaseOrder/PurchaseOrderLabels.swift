import Foundation

// MARK: - PurchaseOrderLabels

/// Every rendered string the purchase-order family emits that is *not* data.
///
/// Deliberately **not** a `LabelSet`: the family-neutral captions it also
/// needs (page numbering, continuation marker, issuer identity captions, the
/// draft watermark and the totals captions) are carried beside it on
/// ``PurchaseOrderDocument/common`` as a ``CommonDocumentLabels`` value, so
/// this type holds only what is specific to a purchase order. The subtotal,
/// discount, tax and total captions are therefore deliberately **absent** here:
/// the totals stack reads them from the common family.
///
/// The stored members are load-bearing in count and order: one per key of the
/// purchase order's PDF string catalog, member = key with its first character
/// lower-cased. A server-side byte-twin is checked against this shape by
/// reflection, so a member is never added, removed or renamed without the
/// catalog and the twin moving in the same change. The helpers below are
/// functions, not stored members, so reflection does not see them.
///
/// Templated members use named `{token}` placeholders (`{name}`, `{days}`,
/// `{rule}`, `{place}`, `{date}`, `{count}`), never positional format
/// specifiers, so translations can reorder them freely. None is a plural: each
/// template reads correctly for every count.
public struct PurchaseOrderLabels: Sendable {

    // MARK: Masthead and header grid

    /// Document title.
    public var purchaseOrderTitle: String
    /// Caption of the order number in the header grid.
    public var purchaseOrderNumberLabel: String
    /// Printed in place of the order number while the order is a draft.
    public var draftNumberPlaceholder: String
    /// Caption of the order date in the header grid.
    public var orderDateLabel: String
    /// Caption of the revision number in the header grid.
    public var revisionLabel: String

    // MARK: Metadata rows (captioned by the mapper)

    /// Caption of the requester.
    public var requestedByLabel: String
    /// Caption of the supplier's own reference (their quotation number).
    public var vendorReferenceLabel: String
    /// Caption of the order's expected delivery date.
    public var expectedDeliveryDateLabel: String
    /// Caption of the payment terms.
    public var paymentTermsLabel: String
    /// Payment-terms value template. Supports `{name}` and `{days}`; expand through ``paymentTermsDays(name:days:)``.
    public var paymentTermsDaysFormat: String
    /// Caption of the delivery terms (Incoterm).
    public var incotermLabel: String
    /// Incoterm value template. Supports `{rule}` and `{place}`; expand through ``incoterm(rule:place:)``.
    public var incotermFormat: String
    /// Caption of the order currency.
    public var currencyLabel: String

    // MARK: Parties

    /// Caption above the issuing (buying) company.
    public var buyerHeader: String
    /// Caption above the supplier's party block.
    public var vendorHeader: String
    /// Caption of the issuer's own number for the supplier.
    public var vendorNumberLabel: String
    /// Caption above the delivery address.
    public var deliverToHeader: String
    /// Caption of the receiving warehouse's code.
    public var warehouseLabel: String

    // MARK: Lines table

    /// Header of the item column (SKU and name).
    public var linesColumnItem: String
    /// Header of the description column.
    public var linesColumnDescription: String
    /// Header of the quantity column.
    public var linesColumnQuantity: String
    /// Header of the unit-cost column.
    public var linesColumnUnitCost: String
    /// Header of the line-discount column.
    public var linesColumnDiscount: String
    /// Header of the tax-rate column.
    public var linesColumnTaxRate: String
    /// Header of the line-total column.
    public var linesColumnLineTotal: String
    /// The explicit empty state of the lines table.
    public var linesEmptyRow: String
    /// A line's own expected-delivery sub-line. Supports `{date}`; expand through ``lineExpectedDelivery(date:)``.
    public var lineExpectedDeliveryFormat: String
    /// The count of closed-short lines left off the document. Supports `{count}`; expand through ``closedShortLinesOmitted(count:)``.
    public var closedShortLinesOmittedFormat: String

    // MARK: Tax breakdown

    /// Caption above the tax breakdown.
    public var taxBreakdownHeader: String
    /// Header of the breakdown's rate column.
    public var taxColumnRate: String
    /// Header of the breakdown's taxable-base column.
    public var taxColumnBase: String
    /// Header of the breakdown's tax-amount column.
    public var taxColumnAmount: String

    // MARK: Totals, instructions, cancellation, footer

    /// Caption of the shipping totals row (the other totals captions are the common family's).
    public var shippingLabel: String
    /// Caption above the special instructions.
    public var specialInstructionsHeader: String
    /// Full-bleed watermark text on a cancelled order.
    public var cancelledWatermark: String
    /// Cancellation notice template. Supports `{date}`; expand through ``cancelledNotice(date:)``.
    public var cancelledNoticeFormat: String
    /// First footer line on every page.
    public var confirmationRequestFooter: String
    /// Second footer line on every page.
    public var indicativeTaxFooter: String

    // MARK: - English default

    /// The built-in English label set — the package-standalone default.
    public static let english = PurchaseOrderLabels()

    // MARK: - Init

    /// Memberwise initialiser. Every parameter defaults to its English value, so
    /// `PurchaseOrderLabels()` equals ``PurchaseOrderLabels/english`` and a host
    /// overrides only the entries it localizes.
    public init(
        purchaseOrderTitle: String = "Purchase order",
        purchaseOrderNumberLabel: String = "Order no.",
        draftNumberPlaceholder: String = "Draft",
        orderDateLabel: String = "Order date",
        revisionLabel: String = "Revision",
        requestedByLabel: String = "Requested by",
        vendorReferenceLabel: String = "Your reference",
        expectedDeliveryDateLabel: String = "Expected delivery",
        paymentTermsLabel: String = "Payment terms",
        paymentTermsDaysFormat: String = "{name} ({days}-day term)",
        incotermLabel: String = "Delivery terms",
        incotermFormat: String = "{rule} {place}",
        currencyLabel: String = "Currency",
        buyerHeader: String = "Ordered by",
        vendorHeader: String = "Supplier",
        vendorNumberLabel: String = "Supplier no.",
        deliverToHeader: String = "Deliver to",
        warehouseLabel: String = "Warehouse",
        linesColumnItem: String = "Item",
        linesColumnDescription: String = "Description",
        linesColumnQuantity: String = "Qty",
        linesColumnUnitCost: String = "Unit price",
        linesColumnDiscount: String = "Discount",
        linesColumnTaxRate: String = "VAT %",
        linesColumnLineTotal: String = "Amount",
        linesEmptyRow: String = "No lines on this order",
        lineExpectedDeliveryFormat: String = "Expected {date}",
        closedShortLinesOmittedFormat: String = "Closed lines not shown: {count}",
        taxBreakdownHeader: String = "VAT summary",
        taxColumnRate: String = "Rate",
        taxColumnBase: String = "Taxable amount",
        taxColumnAmount: String = "VAT",
        shippingLabel: String = "Shipping",
        specialInstructionsHeader: String = "Instructions",
        cancelledWatermark: String = "CANCELLED",
        cancelledNoticeFormat: String = "This order was cancelled on {date}.",
        confirmationRequestFooter: String = "Please confirm this order and quote the order number on your confirmation, delivery documents and invoice.",
        indicativeTaxFooter: String = "Tax amounts are indicative. VAT is settled on your invoice."
    ) {
        self.purchaseOrderTitle = purchaseOrderTitle
        self.purchaseOrderNumberLabel = purchaseOrderNumberLabel
        self.draftNumberPlaceholder = draftNumberPlaceholder
        self.orderDateLabel = orderDateLabel
        self.revisionLabel = revisionLabel
        self.requestedByLabel = requestedByLabel
        self.vendorReferenceLabel = vendorReferenceLabel
        self.expectedDeliveryDateLabel = expectedDeliveryDateLabel
        self.paymentTermsLabel = paymentTermsLabel
        self.paymentTermsDaysFormat = paymentTermsDaysFormat
        self.incotermLabel = incotermLabel
        self.incotermFormat = incotermFormat
        self.currencyLabel = currencyLabel
        self.buyerHeader = buyerHeader
        self.vendorHeader = vendorHeader
        self.vendorNumberLabel = vendorNumberLabel
        self.deliverToHeader = deliverToHeader
        self.warehouseLabel = warehouseLabel
        self.linesColumnItem = linesColumnItem
        self.linesColumnDescription = linesColumnDescription
        self.linesColumnQuantity = linesColumnQuantity
        self.linesColumnUnitCost = linesColumnUnitCost
        self.linesColumnDiscount = linesColumnDiscount
        self.linesColumnTaxRate = linesColumnTaxRate
        self.linesColumnLineTotal = linesColumnLineTotal
        self.linesEmptyRow = linesEmptyRow
        self.lineExpectedDeliveryFormat = lineExpectedDeliveryFormat
        self.closedShortLinesOmittedFormat = closedShortLinesOmittedFormat
        self.taxBreakdownHeader = taxBreakdownHeader
        self.taxColumnRate = taxColumnRate
        self.taxColumnBase = taxColumnBase
        self.taxColumnAmount = taxColumnAmount
        self.shippingLabel = shippingLabel
        self.specialInstructionsHeader = specialInstructionsHeader
        self.cancelledWatermark = cancelledWatermark
        self.cancelledNoticeFormat = cancelledNoticeFormat
        self.confirmationRequestFooter = confirmationRequestFooter
        self.indicativeTaxFooter = indicativeTaxFooter
    }

    // MARK: - Template expansion

    /// Expands ``paymentTermsDaysFormat`` with the terms' name and an
    /// already-formatted day count.
    public func paymentTermsDays(name: String, days: String) -> String {
        paymentTermsDaysFormat
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{days}", with: days)
    }

    /// Expands ``incotermFormat`` with the Incoterm rule and its named place.
    /// The result is trimmed, so an empty place leaves no trailing space.
    public func incoterm(rule: String, place: String) -> String {
        incotermFormat
            .replacingOccurrences(of: "{rule}", with: rule)
            .replacingOccurrences(of: "{place}", with: place)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Expands ``lineExpectedDeliveryFormat`` with an already-formatted date.
    public func lineExpectedDelivery(date: String) -> String {
        lineExpectedDeliveryFormat.replacingOccurrences(of: "{date}", with: date)
    }

    /// Expands ``closedShortLinesOmittedFormat`` with an already-formatted count.
    public func closedShortLinesOmitted(count: String) -> String {
        closedShortLinesOmittedFormat.replacingOccurrences(of: "{count}", with: count)
    }

    /// Expands ``cancelledNoticeFormat`` with an already-formatted date.
    public func cancelledNotice(date: String) -> String {
        cancelledNoticeFormat.replacingOccurrences(of: "{date}", with: date)
    }
}
