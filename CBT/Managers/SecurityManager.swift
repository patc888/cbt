import Combine
import SwiftUI

@MainActor
class SecurityManager: ObservableObject {
    @Published var isLocked = false
    @Published var isContentProtected = false
    @Published var isBiometricsAvailable = false
    @Published private(set) var isAppLockAvailable = false
    @Published private(set) var appLockAvailabilityMessage: String? = "App lock is temporarily unavailable."

    static let shared = SecurityManager()

    init() {
    }

    func checkBiometrics() {
        isBiometricsAvailable = false
        updateAppLockAvailability(canAuthenticate: false)
    }

    func authenticate() {
        unlock()
    }

    func protectContent() {
        isContentProtected = true
    }

    func clearContentProtection() {
        guard !isLocked else { return }
        isContentProtected = false
    }

    func lock() {
        isLocked = true
        isContentProtected = true
    }

    func unlock() {
        isLocked = false
        isContentProtected = false
    }

    private func updateAppLockAvailability(canAuthenticate: Bool) {
        isAppLockAvailable = canAuthenticate
        appLockAvailabilityMessage = canAuthenticate ? nil : "App lock is temporarily unavailable."
    }
}
