#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
import QuartzCore
import AudioToolbox

/// Haptic intents for consistent feedback across the app. Use HapticManager.shared.trigger(_:) or the convenience methods.
enum HapticType {
    case light, medium, heavy, selection, success, warning, error, errorDouble
    /// Throttled light tick for steppers / rapid repeated actions.
    case lightTick
    /// Soft impact for long-press / context menu open.
    case longPressSoft
}

final class HapticManager {
    static let shared = HapticManager()
    
    // MARK: - Persistence
    private let defaults: UserDefaults
    private let hapticsEnabledKey = "hapticsEnabled"
    private let soundsEnabledKey = "interactionSoundsEnabled"
    private let strongHapticsKey = "strongHapticsEnabled"
    
    // MARK: - Generators
    private let lightGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Throttling for selection
    private var lastSelectionTimestamp: CFTimeInterval = 0
    private let selectionDebounceInterval: CFTimeInterval = 0.3
    private var lastLightTickTimestamp: CFTimeInterval = 0
    private let lightTickInterval: CFTimeInterval = 0.15
    private var lastSoundTimestamp: CFTimeInterval = 0
    private let soundDebounceInterval: CFTimeInterval = 0.08
    
    // MARK: - Init
    private init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
        prepareGenerators()
    }
    
    // MARK: - Public Flags
    var isEnabled: Bool {
        guard defaults.object(forKey: hapticsEnabledKey) != nil else { return true }
        return defaults.bool(forKey: hapticsEnabledKey)
    }
    var isStrongEnabled: Bool {
        guard defaults.object(forKey: strongHapticsKey) != nil else { return false }
        return defaults.bool(forKey: strongHapticsKey)
    }
    var isSoundEnabled: Bool {
        guard defaults.object(forKey: soundsEnabledKey) != nil else { return true }
        return defaults.bool(forKey: soundsEnabledKey)
    }
    
    // MARK: - Public API
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: hapticsEnabledKey)
        if enabled { prepareGenerators() }
    }
    func setSoundEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: soundsEnabledKey)
    }
    func setStrongEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: strongHapticsKey)
    }
    
    /// Generic trigger for a specific haptic type. Safe to call from any thread.
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
        case .lightTick: lightTick()
        case .longPressSoft: longPressSoft()
        }
    }
    
    func errorDouble() {
        notification(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.heavyImpact()
        }
    }
    
    func selection() {
        performOnMain {
            self.throttle(interval: self.selectionDebounceInterval, last: &self.lastSelectionTimestamp) {
                if self.isEnabled {
                    self.selectionGenerator.selectionChanged()
                    self.selectionGenerator.prepare()
                }
                self.playSound(.selection)
            }
        }
    }
    func lightImpact() {
        impact(with: lightGenerator, intensity: isStrongEnabled ? 0.9 : 0.65)
    }
    func mediumImpact() { // medium for profile switch, secondary
        impact(with: mediumGenerator, intensity: isStrongEnabled ? 1.0 : 0.8)
    }
    func heavyImpact() { // strong for confirmations
        impact(with: heavyGenerator, intensity: isStrongEnabled ? 1.0 : 1.0)
    }
    func success() { // success completions
        notification(.success)
    }
    func warning() { // destructive confirmations
        notification(.warning)
    }
    func error() {
        notification(.error)
    }
    
    /// Throttled light tick for steppers and rapid repeated actions. Avoids spam.
    func lightTick() {
        performOnMain {
            guard self.isEnabled else { return }
            self.throttle(interval: self.lightTickInterval, last: &self.lastLightTickTimestamp) {
                self.impact(with: self.lightGenerator, intensity: 0.5)
            }
        }
    }
    
    /// Soft impact for long-press / context menu presentation.
    func longPressSoft() {
        guard isEnabled else { return }
        impact(with: lightGenerator, intensity: 0.4)
    }
    
    // MARK: - Convenience shortcuts
    func tap() { lightImpact() }
    func primaryAction() { mediumImpact() }
    func destructiveAction() { heavyImpact() }
    
    // MARK: - Private helpers
    private func impact(with generator: UIImpactFeedbackGenerator, intensity: CGFloat) {
        performOnMain {
            if self.isEnabled {
                generator.impactOccurred(intensity: min(max(intensity, 0.1), 1.0))
                generator.prepare()
            }
            self.playSound(intensity >= 0.95 ? .strongImpact : .softImpact)
        }
    }
    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        performOnMain {
            if self.isEnabled {
                self.notificationGenerator.notificationOccurred(type)
                self.notificationGenerator.prepare()
            }
            self.playSound(Self.feedbackSound(for: type))
        }
    }
    private func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
    private func throttle(interval: CFTimeInterval, last: inout CFTimeInterval, action: @escaping () -> Void) {
        let now = CACurrentMediaTime()
        guard now - last >= interval else { return }
        last = now
        action()
    }

    private enum FeedbackSound {
        case selection, softImpact, strongImpact, success, warning, error

        var id: SystemSoundID {
            switch self {
            case .selection: return 1519
            case .softImpact: return 1104
            case .strongImpact: return 1520
            case .success: return 1057
            case .warning: return 1054
            case .error: return 1073
            }
        }
    }

    private static func feedbackSound(for type: UINotificationFeedbackGenerator.FeedbackType) -> FeedbackSound {
        switch type {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        @unknown default: return .softImpact
        }
    }

    private func playSound(_ sound: FeedbackSound) {
        guard isSoundEnabled else { return }
        throttle(interval: soundDebounceInterval, last: &lastSoundTimestamp) {
            AudioServicesPlaySystemSound(sound.id)
        }
    }
}
#else
// MARK: - Mac Catalyst – HapticType and no-op implementation (no device haptics)
enum HapticType {
    case light, medium, heavy, selection, success, warning, error, errorDouble, lightTick, longPressSoft
}

final class HapticManager {
    static let shared = HapticManager()
    var isEnabled: Bool { false }
    var isStrongEnabled: Bool { false }
    var isSoundEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) {}
    func setSoundEnabled(_ enabled: Bool) {}
    func setStrongEnabled(_ enabled: Bool) {}
    func trigger(_ type: HapticType) {}
    func errorDouble() {}
    func selection() {}
    func lightImpact() {}
    func mediumImpact() {}
    func heavyImpact() {}
    func success() {}
    func warning() {}
    func error() {}
    func lightTick() {}
    func longPressSoft() {}
    func tap() {}
    func primaryAction() {}
    func destructiveAction() {}
}
#endif
