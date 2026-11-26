import Foundation

// MARK: - LabelSet

/// The umbrella every document family's label struct conforms to.
///
/// The requirement set is deliberately **one member**. A label set's job is to
/// carry a family's own wording, and the only string the *shared* composition
/// atoms in ``DocumentLayoutKit`` read from an arbitrary family is the expanded
/// page-number line the footer renders. Widening this protocol would force the
/// widening onto ``InvoiceLabels``, which is public and has consumers outside
/// this package — so every requirement here must be one those consumers already
/// satisfy.
///
/// The common captions are **not** carried here. They live on
/// ``CommonDocumentLabels``, which conforms to this protocol.
public protocol LabelSet: Sendable {
    /// The expanded page-number line a document footer renders.
    func pageNumber(_ page: Int, of pages: Int) -> String
}
