import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class HapticsService {
    var enabled: Bool = true

    enum Flavor { case light, soft, rigid, success, warning, selection }

    func play(_ flavor: Flavor) {
        guard enabled else { return }
        #if canImport(UIKit)
        switch flavor {
        case .light:
            let g = UIImpactFeedbackGenerator(style: .light)
            g.impactOccurred(intensity: 0.5)
        case .soft:
            let g = UIImpactFeedbackGenerator(style: .soft)
            g.impactOccurred(intensity: 0.7)
        case .rigid:
            let g = UIImpactFeedbackGenerator(style: .rigid)
            g.impactOccurred(intensity: 0.9)
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #endif
    }
}
