import SwiftUI

struct LockCheckDecision: Equatable {
    enum Action: Equatable {
        case none
        case authenticate
    }

    let nextShouldCheckLockOnNextActive: Bool
    let action: Action
}

struct SecurityCoverRoot: View {
    @EnvironmentObject private var securityManager: SecurityManager

    var body: some View {
        Group {
            if securityManager.isLocked {
                LockView()
            } else {
                PrivacyShieldView()
            }
        }
    }
}
