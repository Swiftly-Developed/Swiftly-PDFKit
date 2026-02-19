// MARK: - QuoteSupplement

/// Extra fields specific to quote / proposal documents.
public struct QuoteSupplement: Sendable {
    /// "Valid until" date string shown in the meta grid (e.g. "2026-03-31").
    public var expiryDate: String?
    /// Free-text note shown above the acceptance signature block.
    /// When nil the acceptance block is omitted.
    public var acceptanceNote: String?

    public init(expiryDate: String? = nil, acceptanceNote: String? = nil) {
        self.expiryDate = expiryDate
        self.acceptanceNote = acceptanceNote
    }
}

// MARK: - SalesOrderSupplement

/// Extra fields specific to sales order confirmation documents.
public struct SalesOrderSupplement: Sendable {
    /// Date the customer's PO was confirmed / accepted (e.g. "2026-02-18").
    public var poConfirmedDate: String?
    /// Requested delivery date communicated by the customer (e.g. "2026-03-15").
    public var requestedDeliveryDate: String?

    public init(poConfirmedDate: String? = nil, requestedDeliveryDate: String? = nil) {
        self.poConfirmedDate = poConfirmedDate
        self.requestedDeliveryDate = requestedDeliveryDate
    }
}

// MARK: - DeliverySupplement

/// Extra fields specific to delivery note documents.
public struct DeliverySupplement: Sendable {
    /// Full multiline ship-to address (newline-separated).
    /// When nil the billing address on `InvoiceClient` is used.
    public var shipToAddress: String?
    /// When true a signature acknowledgement block is rendered at the bottom of the last page.
    public var signatureRequired: Bool
    /// Label shown above the signature line.
    public var signatureLabel: String

    public init(
        shipToAddress: String? = nil,
        signatureRequired: Bool = false,
        signatureLabel: String = "Received in good order by:"
    ) {
        self.shipToAddress = shipToAddress
        self.signatureRequired = signatureRequired
        self.signatureLabel = signatureLabel
    }
}

// MARK: - ShipmentSupplement

/// Extra fields specific to shipment confirmation / dispatch advice documents.
public struct ShipmentSupplement: Sendable {
    /// Carrier name (e.g. "DHL Express").
    public var carrier: String?
    /// Carrier tracking number or reference.
    public var trackingNumber: String?
    /// Full multiline ship-to address (newline-separated).
    public var shipToAddress: String?
    /// Estimated delivery date string (e.g. "2026-02-25").
    public var estimatedDelivery: String?
    /// When true a signature confirmation block is rendered on the last page.
    public var signatureRequired: Bool
    /// Label shown above the signature line.
    public var signatureLabel: String

    public init(
        carrier: String? = nil,
        trackingNumber: String? = nil,
        shipToAddress: String? = nil,
        estimatedDelivery: String? = nil,
        signatureRequired: Bool = false,
        signatureLabel: String = "Signature on delivery:"
    ) {
        self.carrier = carrier
        self.trackingNumber = trackingNumber
        self.shipToAddress = shipToAddress
        self.estimatedDelivery = estimatedDelivery
        self.signatureRequired = signatureRequired
        self.signatureLabel = signatureLabel
    }
}
