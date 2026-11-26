import Foundation

// MARK: - DocumentLayoutKit + register-number derivation

extension DocumentLayoutKit {

    /// Derives a commercial-register number from a VAT identification number,
    /// for the jurisdictions where the law makes the two one number.
    ///
    /// This is a **fallback**. `InvoiceSupplier.registrationNumber` is the
    /// recorded value and is always honoured first; this is what the supplier
    /// identity block falls back to when that is `nil`.
    ///
    /// The derivation is deliberately narrow — only where the register number
    /// and the VAT identifier are the same number by statute:
    ///
    /// - **BE** — `BE` + 10 digits: the enterprise number, conventionally
    ///   grouped `NNNN.NNN.NNN`.
    /// - **FR** — `FR` + 2 check characters + 9 digits: the SIREN, i.e. those
    ///   nine digits.
    /// - **Everything else** — `nil`. The block omits the row rather than
    ///   guessing; a wrong register number on a statutory letterhead is worse
    ///   than an absent one.
    ///
    /// Input is normalised for spaces, dots and hyphens before matching, and the
    /// country prefix is matched case-insensitively.
    public static func registerNumber(fromVATID vatID: String?) -> String? {
        guard let vatID else { return nil }

        let normalised = vatID
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard normalised.count > 2 else { return nil }
        let prefix = String(normalised.prefix(2))
        let body = String(normalised.dropFirst(2))

        switch prefix {
        case "BE":
            // BE + exactly ten digits. Anything else is not an enterprise number.
            guard body.count == 10, body.allSatisfy(\.isNumber) else { return nil }
            let first = body.prefix(4)
            let middle = body.dropFirst(4).prefix(3)
            let last = body.suffix(3)
            return "\(first).\(middle).\(last)"

        case "FR":
            // FR + two check characters (digits or upper-case letters) + the
            // nine-digit SIREN.
            guard body.count == 11 else { return nil }
            let check = body.prefix(2)
            let siren = String(body.dropFirst(2))
            guard check.allSatisfy({ $0.isNumber || $0.isUppercase }),
                  siren.allSatisfy(\.isNumber)
            else { return nil }
            return siren

        default:
            return nil
        }
    }
}
