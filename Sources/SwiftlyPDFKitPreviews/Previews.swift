import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// ─────────────────────────────────────────────
// Add or edit #Preview blocks here to see your
// PDF rendered live in the Xcode canvas.
// ─────────────────────────────────────────────

@MainActor private var sampleContent: some View {
    PDFPreviewView {
        Page(size: .a4) {
            Text("Hello, World!")
                .font(.helvetica, size: 36)
                .bold()
                .alignment(.center)
            Spacer(height: 16)
            Text("Built with SwiftlyPDFKit")
                .font(.helvetica, size: 14)
                .alignment(.center)
        }
    }
}

// iPhone — renders inside a simulated device bezel
@available(macOS 14, iOS 17, *)
#Preview("Hello World – iPhone", traits: .portrait) {
    NavigationStack {
        sampleContent
            .navigationTitle("PDF Preview")
    }
}

// Bare component — no window, no device chrome, sized to fit content
@available(macOS 14, iOS 17, *)
#Preview("Hello World – Component", traits: .sizeThatFitsLayout) {
    sampleContent
}


// Bare component — no window, no device chrome, sized to fit content
@available(macOS 14, iOS 17, *)
#Preview("Hello World – Component", traits: .fixedLayout(width: 525, height: 742)) {
    sampleContent
}
