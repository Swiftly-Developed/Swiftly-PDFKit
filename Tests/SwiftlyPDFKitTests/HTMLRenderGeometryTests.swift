import Foundation
import Testing
@testable import SwiftlyPDFKit

/// `QA-UNIT06-DOCUMENTS-40` … `-44` — the geometry of the HTML render path.
///
/// Regression guard for
/// `docs/fixes/2026-09-03-invoice-pdf-linux-smart-shrinking-offcenter.md`: the
/// apt `wkhtmltopdf 0.12.6` on the Heroku image is an unpatched-Qt build that
/// ignores `--disable-smart-shrinking`, so every emailed invoice rendered at
/// 0.768 scale, anchored top-left. The fix is three pure values — the exact-`pt`
/// argument vector, a version-probe predicate, a compensation zoom — plus two
/// emitted-string changes (`body { zoom: … }` and a 1pt page-box slack). All five
/// are host-independent, so they are pinned here, on the macOS `swift test` host,
/// where the Linux `Process` half can never run.
///
/// Pre-fix every case below is RED: `-40`/`-41`/`-42` and the `bodyZoom:` half of
/// `-43` do not even compile (the whole enum was `#if !canImport(CoreGraphics)`
/// and the overload did not exist), and `-44`'s `height:841.0pt` was `842.0pt`.
///
/// What this file does NOT prove: that the compensation is *sufficient* on the
/// real engine. That is the Docker leg in the fix record §6 (rasterise + measure
/// ink extents) — a manual oracle, deliberately not a `swift test`.
@Suite("HTML render geometry")
struct HTMLRenderGeometryTests {

    // MARK: Fixtures

    /// The smallest document that reaches every emitter this file asserts on:
    /// one page of the given paper carrying one `Text`.
    static func pdf(size: PageSize) -> PDF {
        PDF {
            Page(size: size) {
                Text("x")
            }
        }
    }

    /// The value following `flag` in `args`, or `nil` when the flag is absent or last.
    static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    /// The `@page { … }` rule body of a rendered document.
    static func atPageRule(in html: String) -> Substring? {
        guard let start = html.range(of: "@page {"),
              let end = html.range(of: "}", range: start.upperBound..<html.endIndex)
        else { return nil }
        return html[start.lowerBound..<end.upperBound]
    }

    // MARK: -40 — the argument vector

    @Test("QA-UNIT06-DOCUMENTS-40: the wkhtmltopdf paper size is passed in exact pt, numeric-only, with smart shrinking still disabled")
    func argumentVectorIsExactPointsAndNumericOnly() throws {
        let a4 = HTMLToPDFConverter.arguments(pageWidth: 595, pageHeight: 842)
        #expect(Self.value(after: "--page-width", in: a4) == "595.0pt")
        #expect(Self.value(after: "--page-height", in: a4) == "842.0pt")

        let letter = HTMLToPDFConverter.arguments(pageWidth: 612, pageHeight: 792)
        #expect(Self.value(after: "--page-width", in: letter) == "612.0pt")
        #expect(Self.value(after: "--page-height", in: letter) == "792.0pt")

        // The pre-fix vector rounded to integer millimetres ("210" / "297" for A4,
        // "216" / "279" for Letter — the latter 1.1pt shorter than its own page box).
        for args in [a4, letter] {
            #expect(args.contains("--disable-smart-shrinking"),
                    "patched-Qt builds honour the switch; it must keep being sent")
            for flag in ["--page-width", "--page-height"] {
                let token = try #require(Self.value(after: flag, in: args))
                // SECURITY.md: "page dimensions are numeric only" — an interpolated
                // CGFloat plus a fixed `pt` suffix, nothing caller-controlled.
                #expect(token.wholeMatch(of: /[0-9.]+pt/) != nil,
                        "\(flag) token \(token) is not a bare numeric pt value")
                #expect(!token.hasSuffix("mm"))
            }
            #expect(!args.contains("210") && !args.contains("297")
                    && !args.contains("216") && !args.contains("279"),
                    "an integer-millimetre paper token survived: \(args)")
        }

        // The remainder of the vector is byte-identical to the pre-fix one, in order.
        let tail = Array(a4.dropFirst(4))
        #expect(tail == [
            "--margin-top", "0", "--margin-bottom", "0", "--margin-left", "0", "--margin-right", "0",
            "--disable-smart-shrinking", "--dpi", "96", "--encoding", "utf-8", "--quiet", "-", "-",
        ])
    }

    // MARK: -41 — the version probe

    @Test("QA-UNIT06-DOCUMENTS-41: isPatchedQt recognises only an explicit '(with patched qt)' marker, case-insensitively")
    func patchedQtDetection() {
        // The apt build on ubuntu:noble prints exactly this — unpatched.
        #expect(HTMLToPDFConverter.isPatchedQt(versionOutput: "wkhtmltopdf 0.12.6\n") == false)
        // The official release binaries.
        #expect(HTMLToPDFConverter.isPatchedQt(versionOutput: "wkhtmltopdf 0.12.6.1 (with patched qt)\n") == true)
        // A build that says the opposite in the same grammatical slot.
        #expect(HTMLToPDFConverter.isPatchedQt(versionOutput: "wkhtmltopdf 0.12.6 (with unpatched qt)") == false)
        // Case-insensitive on the marker.
        #expect(HTMLToPDFConverter.isPatchedQt(versionOutput: "WKHTMLTOPDF 0.12.5 (WITH PATCHED QT)") == true)
        // Nothing at all (tool failed to answer) → not patched, the conservative side.
        #expect(HTMLToPDFConverter.isPatchedQt(versionOutput: "") == false)
    }

    // MARK: -42 — the compensation constant

    @Test("QA-UNIT06-DOCUMENTS-42: the compensation zoom stays inside the measured 1.305…2.08 band with ≥10 % margin to both edges")
    func compensationZoomInsideMeasuredBandWithMargin() {
        // Fix record §4 "Measured fix envelope": below 1.305 the page box stays
        // under-scaled; at ≥ 2.10 the engine stops shrinking and content overflows.
        let zoom = HTMLToPDFConverter.smartShrinkingCompensationZoom
        #expect(zoom > 1.31, "zoom \(zoom) is at or below the measured floor — the box stays under-scaled")
        #expect(zoom < 2.05, "zoom \(zoom) is at or above the measured cap — content overflows the paper")

        // Band membership alone does not pin the value: 2.0 and 1.33 are both INSIDE
        // the band (measured: a 2.0 mutation stayed green on the two lines above).
        // The chosen 1.6 is justified by MARGIN — the residual risk is a different
        // unpatched-Qt build with a different viewport ratio, and 1.6 keeps ≈20 % to
        // both edges. Require at least 10 % to each measured edge:
        //   floor 1.305 × 1.10 = 1.4355   cap 2.08 / 1.10 = 1.891
        // so a future "tidy it to 2.0" or "1.33 is the real ratio" reds here before it
        // ships. Do NOT widen these to make an edit pass — re-measure with the fix
        // record's Docker leg instead.
        #expect(zoom > 1.44, "zoom \(zoom) leaves < 10 % margin to the measured floor (1.305)")
        #expect(zoom < 1.89, "zoom \(zoom) leaves < 10 % margin to the measured cap (≈2.08)")
    }

    // MARK: -43 — the body zoom is opt-in and otherwise changes nothing

    @Test("QA-UNIT06-DOCUMENTS-43: the public renderHTML() emits no body zoom; renderHTML(bodyZoom:) adds exactly the zoom declaration")
    func bodyZoomIsOptInAndIsolated() throws {
        let pdf = Self.pdf(size: .a4)

        let plain = pdf.renderHTML()
        let bodyRuleStart = try #require(plain.range(of: "body {"))
        let bodyRuleEnd = try #require(plain.range(of: "}", range: bodyRuleStart.upperBound..<plain.endIndex))
        let bodyRule = plain[bodyRuleStart.lowerBound..<bodyRuleEnd.upperBound]
        #expect(!bodyRule.contains("zoom"), "public renderHTML() must not compensate: \(bodyRule)")
        #expect(!plain.contains("zoom:"))

        let zoomed = pdf.renderHTML(bodyZoom: 1.6)
        #expect(zoomed.contains("body { zoom: 1.6; "), "the zoom must be the first declaration of the body rule")
        #expect(zoomed.components(separatedBy: "zoom:").count == 2, "exactly one zoom declaration")

        // Removing that one substring must give back the public output byte-for-byte —
        // the overload may not touch the page boxes, the @page rule or anything else.
        let zoomRange = try #require(zoomed.range(of: "zoom: 1.6; "))
        var normalised = zoomed
        normalised.removeSubrange(zoomRange)
        #expect(normalised == plain)

        // And the forwarding contract: bodyZoom 1 is the public output.
        #expect(pdf.renderHTML(bodyZoom: 1) == plain)
    }

    // MARK: -44 — the page-box slack never leaks into the paper size

    @Test("QA-UNIT06-DOCUMENTS-44: the .page box is 1pt shorter than the paper while @page still names the full paper")
    func pageBoxSlackIsOnePointAndPaperIsFull() throws {
        #expect(Page.htmlPageBoxSlack == 1)

        let a4 = Self.pdf(size: .a4).renderHTML()
        #expect(a4.contains("width:595.0pt;height:841.0pt;"), "A4 page box must be paper height − 1pt")
        #expect(!a4.contains("height:842.0pt;"), "the full-height page box is the blank-trailing-page shape")
        let a4Rule = try #require(Self.atPageRule(in: a4))
        #expect(a4Rule.contains("size: 595.0pt 842.0pt;"), "@page must name the FULL paper: \(a4Rule)")
        #expect(!a4Rule.contains("841"), "the slack leaked into the paper size: \(a4Rule)")

        let letter = Self.pdf(size: .letter).renderHTML()
        #expect(letter.contains("width:612.0pt;height:791.0pt;"))
        #expect(!letter.contains("height:792.0pt;"))
        let letterRule = try #require(Self.atPageRule(in: letter))
        #expect(letterRule.contains("size: 612.0pt 792.0pt;"))
        #expect(!letterRule.contains("791"))

        // Every page of a multi-page document carries the slack, not just the first.
        let twoPage = PDF {
            Page(size: .a4) { Text("one") }
            Page(size: .a4) { Text("two") }
        }.renderHTML()
        #expect(twoPage.components(separatedBy: "height:841.0pt;").count == 3, "both page boxes carry the slack")
    }
}
