import LocalAuthentication
import Combine
import SwiftUI

@MainActor
class SecurityManager: ObservableObject {
    @Published var isLocked = false
    @Published var isBiometricsAvailable = false
    @Published var biometryType: LABiometryType = .none

    static let shared = SecurityManager()

    private init() {
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

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock Time Blocking"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                Task { @MainActor in
                    if success {
                        self.isLocked = false
                    } else {
                        // Keep locked if failed
                        self.isLocked = true
                    }
                }
            }
        } else {
            // No biometrics or default passcode, just unlock (or handle error)
            self.isLocked = false
        }
    }

    func lock() {
        self.isLocked = true
    }
}
