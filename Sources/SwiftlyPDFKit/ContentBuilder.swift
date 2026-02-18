import Foundation

// MARK: - ContentBuilder

/// Shared result builder for any block that produces [any PDFContent].
@resultBuilder
public struct ContentBuilder {
    public static func buildExpression(_ expression: any PDFContent) -> [any PDFContent] {
        [expression]
    }

    public static func buildBlock(_ components: [any PDFContent]...) -> [any PDFContent] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[any PDFContent]]) -> [any PDFContent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [any PDFContent]?) -> [any PDFContent] {
        component ?? []
    }

    public static func buildEither(first component: [any PDFContent]) -> [any PDFContent] {
        component
    }

    public static func buildEither(second component: [any PDFContent]) -> [any PDFContent] {
        component
    }
}
