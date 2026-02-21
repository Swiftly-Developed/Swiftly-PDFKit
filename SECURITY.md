# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.2.x   | Yes       |
| 0.1.x   | Yes       |

## Reporting a vulnerability

If you discover a security vulnerability in SwiftlyPDFKit, please report it responsibly.

**Do not open a public issue.** Instead, email **security@swiftly-developed.com** with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will acknowledge your report within 48 hours and aim to release a fix within 7 days for critical issues.

## Scope

SwiftlyPDFKit is a PDF generation library. Potential security concerns include:

- **Path traversal** in `ImageContent(path:)` — file paths are passed directly to CoreGraphics (Darwin) or read for base64 encoding (Linux)
- **Shell injection** (Linux) — `HTMLToPDFConverter` invokes `wkhtmltopdf` via `Foundation.Process`; page dimensions are numeric only, but untrusted HTML content could be a concern
- **Memory exhaustion** — extremely large documents or data sets
- **Malformed input** — unexpected characters in text rendering; HTML output uses `String.htmlEscaped` to mitigate injection

If you discover issues in these or other areas, please report them using the process above.
