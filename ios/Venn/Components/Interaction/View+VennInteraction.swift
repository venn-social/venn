import SwiftUI

extension View {
    /// Subtle depth change for repeated scroll content. Intended for cards
    /// inside `ScrollView`, not static panels or forms.
    func vennScrollDepth() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.74)
                .scaleEffect(phase.isIdentity ? 1 : 0.985)
        }
    }

    /// Shared sensory feedback for selection state changes.
    func vennSelectionFeedback<Value: Equatable>(trigger: Value) -> some View {
        sensoryFeedback(.selection, trigger: trigger)
    }

    /// Shared sensory feedback for tab changes.
    func vennTabFeedback<Value: Equatable>(trigger: Value) -> some View {
        sensoryFeedback(.press(.tab), trigger: trigger)
    }
}
