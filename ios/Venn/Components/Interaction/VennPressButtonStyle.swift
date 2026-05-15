import SwiftUI

/// Native-feeling press treatment for tappable controls.
///
/// Use this instead of ad hoc `.scaleEffect` / haptic code in individual
/// feature views. The visual press state and sensory feedback stay aligned
/// across buttons, chips, rows, and future toolbar controls.
struct VennPressButtonStyle: ButtonStyle {
    enum Feedback {
        case none
        case selection
        case press
        case tab

        var sensoryFeedback: SensoryFeedback? {
            switch self {
            case .none:
                nil
            case .selection:
                .selection
            case .press:
                .press(.button)
            case .tab:
                .press(.tab)
            }
        }
    }

    var feedback: Feedback = .press

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.interactiveSpring(duration: 0.16, extraBounce: 0.04), value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, isPressed in
                isPressed ? feedback.sensoryFeedback : nil
            }
    }
}

extension ButtonStyle where Self == VennPressButtonStyle {
    static var vennPress: VennPressButtonStyle {
        VennPressButtonStyle()
    }

    static var vennSelection: VennPressButtonStyle {
        VennPressButtonStyle(feedback: .selection)
    }
}
