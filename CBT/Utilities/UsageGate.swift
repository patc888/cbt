import SwiftUI
import SwiftData

struct UsageGate {
    static let trialLimit = 10

    @MainActor
    static func canCreateNewItem(in context: ModelContext) -> Bool {
        return true
    }
}

struct UsageGateModifier: ViewModifier {
    @Binding var isAttemptingAction: Bool
    let onProceed: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingPaywall = false
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .onChange(of: isAttemptingAction) { _, newValue in
                if newValue {
                    // Reset the toggle immediately so it can be fired again if needed
                    isAttemptingAction = false
                    
                    if UsageGate.canCreateNewItem(in: modelContext) {
                        onProceed()
                    } else {
                        HapticManager.shared.warning()
                        showingPaywall = true
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionView()
                    .dsSheetPresentation(detents: [.large])
            }
    }
}

extension View {
    func withUsageGate(isAttemptingAction: Binding<Bool>, onProceed: @escaping () -> Void) -> some View {
        modifier(UsageGateModifier(isAttemptingAction: isAttemptingAction, onProceed: onProceed))
    }
}
