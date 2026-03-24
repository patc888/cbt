import Combine
import LocalAuthentication
import SwiftUI

@MainActor
class SecurityManager: ObservableObject {
    @Published var isLocked = false
    @Published var isBiometricsAvailable = false
    @Published var biometryType: LABiometryType = .none

    static let shared = SecurityManager()

    init() {
        checkBiometrics()
    }

    func checkBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricsAvailable = true
            biometryType = context.biometryType
        } else {
            isBiometricsAvailable = false
            biometryType = .none
        }
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            self.isLocked = false
            return
        }

        let reason = "Unlock CBT"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            Task { @MainActor in
                if success {
                    self.isLocked = false
                } else {
                    // If user cancelled or failed, keep locked but don't crash
                    self.isLocked = true
                }
            }
        }
    }

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
    }
}
