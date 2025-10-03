import CoreModels
import SharedUtilities

extension HapticFeedbackIntensity {
    init(style: SwipeHapticStyle) {
        switch style {
        case .light:
            self = .light
        case .medium:
            self = .medium
        case .heavy:
            self = .heavy
        case .soft:
            self = .soft
        case .rigid:
            self = .rigid
        }
    }
}
