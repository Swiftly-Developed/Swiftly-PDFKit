# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
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

- **Path traversal** in `ImageContent(path:)` — file paths are passed directly to CoreGraphics
- **Memory exhaustion** — extremely large documents or data sets
- **Malformed input** — unexpected characters in text rendering

If you discover issues in these or other areas, please report them using the process above.
