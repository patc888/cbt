import Combine
import LocalAuthentication
import SwiftUI

@MainActor
class SecurityManager: ObservableObject {
    @Published var isLocked = false
    @Published var isContentProtected = false
    @Published var isBiometricsAvailable = false
    @Published var biometryType: LABiometryType = .none
    @Published private(set) var isAppLockAvailable = false
    @Published private(set) var appLockAvailabilityMessage: String?

    static let shared = SecurityManager()

    init() {
        checkBiometrics()
    }

    func checkBiometrics() {
        let context = LAContext()
        var biometricsError: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &biometricsError) {
            isBiometricsAvailable = true
            biometryType = context.biometryType
        } else {
            isBiometricsAvailable = false
            biometryType = .none
        }

        var authenticationError: NSError?
        updateAppLockAvailability(
            canAuthenticate: context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authenticationError),
            error: authenticationError
        )
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            updateAppLockAvailability(canAuthenticate: false, error: error)
            return
        }

        updateAppLockAvailability(canAuthenticate: true, error: nil)

        let reason = "Unlock CBT"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            Task { @MainActor in
                if success {
                    self.unlock()
                } else {
                    self.checkBiometrics()
                    // If user cancelled or failed, keep locked
                    self.lock()
                }
            }
        }
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

    private func updateAppLockAvailability(canAuthenticate: Bool, error: NSError?) {
        isAppLockAvailable = canAuthenticate
        appLockAvailabilityMessage = canAuthenticate ? nil : Self.message(for: error)
    }

    private static func message(for error: NSError?) -> String {
        guard
            let error,
            error.domain == LAError.errorDomain,
            let code = LAError.Code(rawValue: error.code)
        else {
            return "Requires Face ID, Touch ID, or a device passcode."
        }

        switch code {
        case .passcodeNotSet:
            return "Set a device passcode to enable app lock."
        case .biometryNotAvailable, .biometryNotEnrolled:
            return "Requires a device passcode or enrolled biometrics."
        default:
            return "Requires Face ID, Touch ID, or a device passcode."
        }
    }
}
