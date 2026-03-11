import Combine
import LocalAuthentication
import SwiftUI

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

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock CBT"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isLocked = false
                    } else {
                        self.isLocked = true
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.isLocked = false
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
