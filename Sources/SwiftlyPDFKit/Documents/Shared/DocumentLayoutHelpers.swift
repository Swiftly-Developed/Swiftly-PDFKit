import CoreGraphics

// Internal helpers shared by all non-invoice layout builders in this module.

// MARK: - shipToAddressBlock

/// A lightly-tinted banner strip showing a "Ship To" address.
/// Returns an array so it can be conditionally included with `if let`.
func shipToAddressBlock(address: String, theme: InvoiceTheme) -> [any PDFContent] {
    // Use a very light tint of the accent colour for the strip background.
    // CGColor components vary by colorspace: RGB has [r,g,b,a], grayscale has [w,a].
    // Convert to RGB regardless of source colorspace.
    let lightBg: PDFColor
    if let rgb = theme.accentColor.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent, options: nil),
       let c = rgb.components, c.count >= 3 {
        lightBg = PDFColor(red:   c[0] * 0.12 + 0.88,
                           green: c[1] * 0.12 + 0.88,
                           blue:  c[2] * 0.12 + 0.88,
                           alpha: 1)
    } else {
        lightBg = PDFColor(white: 0.92, alpha: 1)
    }

    let lines = address.components(separatedBy: "\n")
    let lineCount = max(lines.count, 1)
    let bannerHeight: CGFloat = 12 + CGFloat(lineCount) * 12 + 6  // padding + lines + padding

    return [
        FilledBox(color: lightBg, height: bannerHeight, padding: 8) {
            Columns(spacing: 12) {
                ColumnItem(width: .fixed(50)) {
                    Text("Ship To:")
                        .font(theme.bodyFont, size: 8)
                        .bold()
                }
                ColumnItem(width: .flex) {
                    for line in lines {
                        Text(line).font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                }
            }
        }
    ]
}

// MARK: - signatureBlock

/// A signature acknowledgement block: a label, then three fields (Signature / Date / Print Name).
func signatureBlock(label: String, theme: InvoiceTheme) -> [any PDFContent] {
    return [
        Spacer(height: 28),
        HRule(thickness: 0.5, color: theme.accentColor),
        Spacer(height: 8),
        Text("Acknowledgement of Receipt")
            .font(theme.titleFont, size: 10)
            .bold(),
        Spacer(height: 5),
        Text(label)
            .font(theme.bodyFont, size: 9),
        Spacer(height: 18),
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 3)
                Text("Signature").font(theme.bodyFont, size: 8)
            }
            ColumnItem(width: .fixed(130)) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 3)
                Text("Date received").font(theme.bodyFont, size: 8)
            }
            ColumnItem(width: .fixed(110)) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 3)
                Text("Print name").font(theme.bodyFont, size: 8)
            }
        }
    ]
}

// MARK: - acceptanceBlock

/// An acceptance / sign-off block used at the bottom of quote documents.
/// Pass `note: nil` to omit the block entirely (returns empty array).
func acceptanceBlock(note: String?, theme: InvoiceTheme) -> [any PDFContent] {
    guard let note = note else { return [] }
    return [
        Spacer(height: 24),
        HRule(thickness: 0.5, color: theme.accentColor),
        Spacer(height: 8),
        Text("Acceptance")
            .font(theme.titleFont, size: 11)
            .bold(),
        Spacer(height: 6),
        Text(note).font(theme.bodyFont, size: 9),
        Spacer(height: 18),
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 3)
                Text("Authorized signature").font(theme.bodyFont, size: 8)
            }
            ColumnItem(width: .fixed(120)) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 3)
                Text("Date").font(theme.bodyFont, size: 8)
            }
        }
    ]
}

// MARK: - carrierBlock

/// An accent-coloured banner showing carrier, tracking number, and estimated delivery.
func carrierBlock(
    carrier: String?,
    trackingNumber: String?,
    estimatedDelivery: String?,
    theme: InvoiceTheme
) -> [any PDFContent] {
    let carrierText: String = {
        var parts: [String] = []
        if let c = carrier { parts.append("Carrier: \(c)") }
        if let t = trackingNumber { parts.append("Tracking: \(t)") }
        return parts.joined(separator: "   ·   ")
    }()
    let deliveryText = estimatedDelivery.map { "Est. delivery: \($0)" } ?? ""

    return [
        FilledBox(color: theme.accentColor, height: 38, padding: 8) {
            Columns(spacing: 12) {
                ColumnItem(width: .flex) {
                    if !carrierText.isEmpty {
                        Text(carrierText)
                            .font(theme.bodyFont, size: 9)
                            .bold()
                            .foregroundColor(theme.tableHeaderTextColor)
                    }
                }
                if !deliveryText.isEmpty {
                    ColumnItem(width: .fixed(130)) {
                        Text(deliveryText)
                            .font(theme.bodyFont, size: 9)
                            .foregroundColor(theme.tableHeaderTextColor)
                    }
                }
            }
        }
    ]
}

