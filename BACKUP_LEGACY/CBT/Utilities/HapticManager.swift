#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
import QuartzCore

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
    
    // MARK: - Public API
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: hapticsEnabledKey)
        if enabled { prepareGenerators() }
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
        guard isEnabled else { return }
        notification(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.heavyImpact()
        }
    }
    
    func selection() {
        guard isEnabled else { return }
        throttle(interval: selectionDebounceInterval, last: &lastSelectionTimestamp) {
            self.selectionGenerator.selectionChanged()
            self.selectionGenerator.prepare()
        }
    }
    func lightImpact() {
        guard isEnabled else { return }
        impact(with: lightGenerator, intensity: isStrongEnabled ? 0.9 : 0.65)
    }
    func mediumImpact() { // medium for profile switch, secondary
        guard isEnabled else { return }
        impact(with: mediumGenerator, intensity: isStrongEnabled ? 1.0 : 0.8)
    }
    func heavyImpact() { // strong for confirmations
        guard isEnabled else { return }
        impact(with: heavyGenerator, intensity: isStrongEnabled ? 1.0 : 1.0)
    }
    func success() { // success completions
        guard isEnabled else { return }
        notification(.success)
    }
    func warning() { // destructive confirmations
        guard isEnabled else { return }
        notification(.warning)
    }
    func error() {
        guard isEnabled else { return }
        notification(.error)
    }
    
    /// Throttled light tick for steppers and rapid repeated actions. Avoids spam.
    func lightTick() {
        guard isEnabled else { return }
        throttle(interval: lightTickInterval, last: &lastLightTickTimestamp) {
            self.impact(with: self.lightGenerator, intensity: 0.5)
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
            generator.impactOccurred(intensity: min(max(intensity, 0.1), 1.0))
            generator.prepare()
        }
    }
    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        performOnMain {
            self.notificationGenerator.notificationOccurred(type)
            self.notificationGenerator.prepare()
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
    func setEnabled(_ enabled: Bool) {}
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
