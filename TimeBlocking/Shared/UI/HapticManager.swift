import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum HapticType {
    case light, medium, heavy, selection, success, warning, error, errorDouble
}

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    private var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    /// Generic trigger for a specific haptic type.
    func trigger(_ type: HapticType) {
        switch type {
        case .light: lightImpact()
        case .medium: mediumImpact()
        case .heavy: heavyImpact()
        case .selection: selection()
        case .success: success()
        case .warning: warning()
        case .error: error()
        case .errorDouble: errorDouble()
        }
    }
    
    /// Triggers a light impact haptic, suitable for small ticks or subtle feedback.
    func lightImpact() {
        guard isEnabled else { return }
        #if os(iOS)
        impact(.light)
        #endif
    }
    
    /// Triggers a medium impact haptic, suitable for standard button taps or actionable elements.
    func mediumImpact() {
        guard isEnabled else { return }
        #if os(iOS)
        impact(.medium)
        #endif
    }
    
    /// Triggers a success notification haptic, suitable for completing a task or saving data.
    func success() {
        guard isEnabled else { return }
        #if os(iOS)
        notification(.success)
        #endif
    }
    
    /// Triggers a heavy impact haptic, suitable for major events.
    func heavyImpact() {
        guard isEnabled else { return }
        #if os(iOS)
        impact(.heavy)
        #endif
    }
    
    /// Triggers a selection change haptic, suitable for tab switching or picker selection.
    func selection() {
        guard isEnabled else { return }
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
    
    /// Triggers an error notification haptic, suitable for failed actions.
    func error() {
        guard isEnabled else { return }
        #if os(iOS)
        notification(.error)
        #endif
    }
    
    func warning() {
        guard isEnabled else { return }
        #if os(iOS)
        notification(.warning)
        #endif
    }
    
    func errorDouble() {
        guard isEnabled else { return }
        #if os(iOS)
        notification(.error)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        #endif
    }

    #if os(iOS)
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    #endif
}
