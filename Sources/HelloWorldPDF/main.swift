import Foundation
import SwiftlyPDFKit

// MARK: - Shared styles

let gold = PDFColor(red: 0.60, green: 0.49, blue: 0.31)
let transparent = PDFColor(white: 1, alpha: 0)

let logoPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()           // Sources/HelloWorldPDF
    .deletingLastPathComponent()           // Sources
    .deletingLastPathComponent()           // package root
    .appendingPathComponent("icon_512x512.png")
    .path

// MARK: - Invoice line items (page 1)

let invoiceLines: [[String]] = [
    ["Boekhouding en fiscaliteit",                              "109,20"],
    ["Administratie & Boekhoudkundige verwerking documenten",  " 60,66"],
]

// MARK: - Totals table data (page 1, bottom)

let totalsData: [[String]] = [
    ["169,86", "0,00", "0,00", "169,86", "35,67", "EUR", "205,53"],
]

// MARK: - Detail lines (page 3)

let detailLines: [[String]] = [
    ["boekjaar 2026",
     "Administratie, verwerking facturen en financieel",
     "31-12-2025", "6,07"],
    ["Opvolging dossier - Instellingen - Taken",
     "Administratie, verwerking facturen en financieel",
     "06-01-2026", "24,26"],
    ["input aankoop- en verkoopfcaturen 4Q25",
     "Administratie, verwerking facturen en financieel",
     "13-01-2026", "12,13"],
    ["afwerking en verzending btw 4q25",
     "Fiscaliteit en boekhouding",
     "17-01-2026", "36,40"],
    ["mail",
     "Administratie, verwerking facturen en financieel",
     "19-01-2026", "12,13"],
    ["Aanpassing Loon Matthew en opvolging ontslag + verkoop aandelen",
     "Fiscaliteit en boekhouding",
     "03-02-2026", "72,80"],
    ["Banken 4Q25",
     "Administratie, verwerking facturen en financieel",
     "05-02-2026", "6,07"],
]

// MARK: - Logo column helper

func logoColumn() -> ColumnItem {
    ColumnItem(width: .fixed(160)) {
        if let img = ImageContent(path: logoPath, maxWidth: 120, maxHeight: 70) {
            img
        } else {
            Text("TFC").font(.helvetica, size: 28).bold().foregroundColor(gold)
        }
        Spacer(height: 6)
        HRule(thickness: 0.5, color: gold)
        Spacer(height: 8)
        Text("TAX & FINANCE CONSULTANTS")
            .font(.helvetica, size: 9)
            .foregroundColor(gold)
    }
}

// MARK: - Reusable styles

let lineItemStyle = TableStyle(
    headerBackground: transparent,
    headerTextColor: .black,
    headerFontSize: 10,
    cellFontSize: 10,
    rowHeight: 20,
    borderColor: PDFColor(white: 0.4),
    borderWidth: 0.5,
    cellPadding: 4
)

let totalsStyle = TableStyle(
    headerBackground: PDFColor(white: 0.85),
    headerTextColor: .black,
    headerFontSize: 9,
    cellFontSize: 9,
    rowHeight: 18,
    borderColor: PDFColor(white: 0.5),
    borderWidth: 0.5,
    cellPadding: 4
)

let detailStyle = TableStyle(
    headerBackground: transparent,
    headerTextColor: .black,
    headerFontSize: 10,
    cellFontSize: 9,
    rowHeight: 18,
    borderColor: PDFColor(white: 0.4),
    borderWidth: 0.5,
    cellPadding: 4
)

// MARK: - PDF

let pdf = PDF {

    // ── PAGE 1: Main invoice ─────────────────────────────────────────────────
    Page(size: .a4, margins: 40) {

        // Header: logo left, client address right
        Columns(spacing: 20) {
            logoColumn()

            ColumnItem(width: .flex) {
                Spacer(height: 20)
                Text("Swiftly Workspace BV")
                    .font(.helvetica, size: 10).bold()
                Spacer(height: 4)
                Text("Spaces").font(.helvetica, size: 10)
                Text("Borsbeeksebrug 34").font(.helvetica, size: 10)
                Text("2600 Berchem (Antwerpen)").font(.helvetica, size: 10)
            }
        }

        Spacer(height: 24)

        // Invoice metadata left, BTW + document type right
        Columns(spacing: 20) {
            ColumnItem(width: .fixed(240)) {
                Columns(spacing: 0) {
                    ColumnItem(width: .fixed(80)) {
                        Text("Factuur Nr").font(.helvetica, size: 10).bold()
                        Text("Onder. Nr").font(.helvetica, size: 10).bold()
                        Text("Klantnr.").font(.helvetica, size: 10).bold()
                        Text("Datum").font(.helvetica, size: 10).bold()
                        Text("Vervaldag").font(.helvetica, size: 10).bold()
                    }
                    ColumnItem(width: .flex) {
                        Text(":20260114").font(.helvetica, size: 10).bold()
                        Text(":BE 1012.954.172").font(.helvetica, size: 10).bold()
                        Text(":645").font(.helvetica, size: 10).bold()
                        Text(":10-02-2026").font(.helvetica, size: 10).bold()
                        Text(":18-02-2026").font(.helvetica, size: 10).bold()
                    }
                }
            }

            ColumnItem(width: .flex) {
                Columns(spacing: 4) {
                    ColumnItem(width: .fixed(60)) {
                        Text("BTW nr. :").font(.helvetica, size: 10).bold()
                    }
                    ColumnItem(width: .flex) {
                        Text("NB").font(.helvetica, size: 10)
                    }
                }
                Spacer(height: 16)
                Text("Factuur")
                    .font(.times, size: 14)
                    .bold()
                    .italic()
                    .alignment(.center)
            }
        }

        Spacer(height: 20)

        // Line items
        Table(data: invoiceLines, style: lineItemStyle) {
            Column("Omschrijving", width: .flex,      alignment: .leading)
            Column("Totaal excl.", width: .fixed(90), alignment: .trailing, headerAlignment: .trailing)
        }

        Spacer(height: 24)

        // QR code + payment message
        Columns(spacing: 16) {
            ColumnItem(width: .flex) {
                Text("U kunt nu ook betalen met behulp van volgende QR-code!")
                    .font(.helvetica, size: 9).bold()
                Spacer(height: 2)
                Text("(Indien betalen met de QR-code niet lukt dient u de betaling manueel te verrichten)")
                    .font(.helvetica, size: 9).bold()
                Spacer(height: 4)
                Text("Voor algemene voorwaarde zie volgende pagina.")
                    .font(.helvetica, size: 9)
            }
            ColumnItem(width: .fixed(70)) {
                QRCodeContent(
                    "BCD\n002\n1\nSCT\nGEBABEBB\nT.F. Consult\nBE64001845507852\nEUR205.53\n\n+++005/0114/21942+++",
                    size: 65,
                    alignment: .trailing
                )
            }
        }

        Spacer(height: 12)

        // Payment reference banner
        FilledBox(color: PDFColor(white: 0.15), height: 22) {
            Text("Gelieve bij betaling te vermelden: +++005/0114/21942+++")
                .font(.helvetica, size: 9).bold()
                .foregroundColor(PDFColor.white)
                .alignment(.center)
        }

        Spacer(height: 2)

        // Totals summary table
        Table(data: totalsData, style: totalsStyle) {
            Column("Totaal excl.", width: .flex,      alignment: .trailing, headerAlignment: .center)
            Column("Vrijgesteld",  width: .fixed(60), alignment: .trailing, headerAlignment: .center)
            Column("Basis 0%",     width: .fixed(55), alignment: .trailing, headerAlignment: .center)
            Column("Basis 21%",    width: .fixed(65), alignment: .trailing, headerAlignment: .center)
            Column("BTW",          width: .fixed(45), alignment: .trailing, headerAlignment: .center)
            Column("€",            width: .fixed(30), alignment: .center,   headerAlignment: .center)
            Column("Te betalen",   width: .fixed(70), alignment: .trailing, headerAlignment: .center)
        }

        Footer(height: 72) {
            HRule(thickness: 0.5, color: PDFColor(white: 0.3))
            Spacer(height: 6)
            Text("T.F. Consult").font(.helvetica, size: 8).bold().alignment(.center)
            Text("- Tel:  +(32) 35 35 10 04  -  info@tfconsult.be").font(.helvetica, size: 8).alignment(.center)
            Text("De Noterstraat 29  -  2800 Mechelen").font(.helvetica, size: 8).alignment(.center)
            Text("IBAN BE64 0018 4550 7852  -  BIC: GEBABEBB").font(.helvetica, size: 8).alignment(.center)
            Text("IBAN BE32 1431 1173 4102  -  BIC: GEBABEBB").font(.helvetica, size: 8).alignment(.center)
            Text("R.P.R. Antwerpen, afdeling Mechelen  -  BTW nr. BE 0700.958.325").font(.helvetica, size: 8).alignment(.center)
            Text("www.tfconsult.be").font(.helvetica, size: 8).alignment(.center)
        }
    }

    // ── PAGE 2: General terms ────────────────────────────────────────────────
    Page(size: .a4, margins: 40) {
        Text("ALGEMENE VOORWAARDEN")
            .font(.helvetica, size: 11).bold()
            .alignment(.center)
        Spacer(height: 2)
        HRule(thickness: 0.5)
        Spacer(height: 14)

        Text("- Alle facturen zijn betaalbaar binnen de 8 dagen na factuurdatum door overschrijving. Elk onbetaald bedrag zal van rechtswege en zonder ingebrekestelling verhoogd worden met een intrest van 1% per maand, te rekenen vanaf de vervaldag met een minimum van 100,00 eur en verhoogd met de eventuele  administratie- en rechtsplegingkosten.")
            .font(.helvetica, size: 10)
        Spacer(height: 8)
        Text("- Elke betwisting over deze factuur moet schriftelijk binnen een termijn van 7 dagen kenbaar gemaakt worden aan de verzender.")
            .font(.helvetica, size: 10)
        Spacer(height: 8)
        Text("- Enkel deze voorwaarden beheersen de contractuele relatie tussen dienstverrichter en haar cliënt, behoudens anders luidende en schriftelijke gemaakte afspraken.")
            .font(.helvetica, size: 10)
        Spacer(height: 8)
        Text("- Enkel het Belgisch recht en de rechtbanken van Mechelen zijn bevoegd.")
            .font(.helvetica, size: 10)
    }

    // ── PAGE 3: Detail attachment ────────────────────────────────────────────
    Page(size: .a4, margins: 40) {
        Columns(spacing: 20) {
            logoColumn()

            ColumnItem(width: .flex) {
                Spacer(height: 16)
                Text("Factuurnummer: 20260114 voor Swiftly Workspace")
                    .font(.helvetica, size: 11).bold()
                    .alignment(.center)
            }
        }

        Spacer(height: 16)

        Table(data: detailLines, style: detailStyle) {
            Column("Omschrijving",   width: .flex,        alignment: .leading)
            Column("Type prestatie", width: .fixed(200),  alignment: .leading)
            Column("Datum",          width: .fixed(70),   alignment: .leading)
            Column("Getar",          width: .fixed(45),   alignment: .trailing, headerAlignment: .trailing)
        }

        Footer(height: 30) {
            HRule(thickness: 0.5, color: PDFColor(white: 0.4))
            Spacer(height: 4)
            Text("- Bijlagen facturatie -").font(.helvetica, size: 9).alignment(.center)
        }
    }
}

// MARK: - Render

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Invoice-20260114.pdf")

do {
    try pdf.write(to: outputURL)
    print("PDF written to: \(outputURL.path)")
} catch {
    print("Failed to write PDF: \(error)")
}
