import SwiftUI
import SwiftData

struct UsageGate {
    @MainActor
    static func canCreateNewItem(in context: ModelContext) -> Bool {
        _ = context
        return true
    }
}

struct UsageGateModifier: ViewModifier {
    @Binding var isAttemptingAction: Bool
    let onProceed: () -> Void
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .onChange(of: isAttemptingAction) { _, newValue in
                if newValue {
                    // Reset the toggle immediately so it can be fired again if needed
                    isAttemptingAction = false
                    onProceed()
                }
            }
    }
}

extension View {
    func withUsageGate(isAttemptingAction: Binding<Bool>, onProceed: @escaping () -> Void) -> some View {
        modifier(UsageGateModifier(isAttemptingAction: isAttemptingAction, onProceed: onProceed))
    }
}
