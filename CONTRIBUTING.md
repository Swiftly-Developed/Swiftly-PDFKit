# Contributing to SwiftlyPDFKit

Thank you for considering contributing to SwiftlyPDFKit! This document outlines the process for contributing to this project.

## How to contribute

### Reporting bugs

If you find a bug, please [open an issue](https://github.com/Swiftly-Developed/Swiftly-PDFKit/issues/new?template=bug_report.md) with:

- A clear description of the problem
- Steps to reproduce (minimal code example preferred)
- Expected vs actual behavior
- Swift version, platform, and OS version

### Suggesting features

Feature requests are welcome. Please [open an issue](https://github.com/Swiftly-Developed/Swiftly-PDFKit/issues/new?template=feature_request.md) describing:

- The use case or problem you're trying to solve
- Your proposed solution (if any)
- Whether you'd be willing to implement it

### Submitting pull requests

1. Fork the repository
2. Create a feature branch from `main` (`git checkout -b feature/my-feature`)
3. Make your changes
4. Ensure the project builds on all supported platforms:
   ```bash
   swift build
   ```
5. Commit with a clear message following [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat(Core): add underline modifier to Text
   fix(InvoiceLayout): correct pagination for single-line invoices
   docs: update README with new API examples
   ```
6. Push to your fork and open a pull request against `main`

## Development setup

```bash
git clone https://github.com/Swiftly-Developed/Swiftly-PDFKit.git
cd Swiftly-PDFKit
swift build
```

To generate demo PDFs:

```bash
swift run GenerateDemos
```

To preview layouts in Xcode, open `Package.swift` and use the SwiftUI canvas with any file in `Sources/DemoPDFKit/`.

## Code style

- Follow existing patterns in the codebase
- Use Swift 6 strict concurrency where applicable
- Keep the public API minimal — prefer `internal` unless the type needs to be user-facing
- No AppKit/UIKit imports — the core library must remain cross-platform (macOS, iOS, Linux)
- Use CoreText (`kCTFontAttributeName`, etc.) instead of `NSAttributedString.Key`

## Cross-platform guidelines

SwiftlyPDFKit targets macOS, iOS, and Linux. When contributing:

- **No CoreImage** — not available on Linux. Use `swift-qrcode-generator` for QR codes.
- **No AppKit/UIKit** — use CoreGraphics and CoreText only in the core library.
- `SwiftlyPDFKitUI` may use platform-specific frameworks (PDFKit, SwiftUI) behind `#if canImport(...)` guards.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
