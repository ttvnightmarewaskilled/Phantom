import UIKit

/// Call from the main thread (all UI callbacks are).
enum Haptics {
    static var isEnabled = true

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        run { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }

    static func selection() {
        guard isEnabled else { return }
        run { UISelectionFeedbackGenerator().selectionChanged() }
    }

    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error() { notify(.error) }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        run { UINotificationFeedbackGenerator().notificationOccurred(type) }
    }

    private static func run(_ work: @MainActor () -> Void) {
        MainActor.assumeIsolated(work)
    }
}
