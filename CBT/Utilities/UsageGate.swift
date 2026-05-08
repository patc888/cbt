import SwiftUI
import SwiftData

struct UsageGate {
    static let trialLimit = 10

    @MainActor
    static func canCreateNewItem(in context: ModelContext) -> Bool {
        // If they already paid, always allow
        if SubscriptionManager.shared.isPremium {
            return true
        }
        
        // Count total entries across main categories
        let thoughtCount = (try? context.fetchCount(FetchDescriptor<ThoughtRecord>())) ?? 0
        let journalCount = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? 0
        let moodCount = (try? context.fetchCount(FetchDescriptor<MoodEntry>())) ?? 0
        
        let totalCount = thoughtCount + journalCount + moodCount
        
        return totalCount < trialLimit
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
            }
    }
}

extension View {
    func withUsageGate(isAttemptingAction: Binding<Bool>, onProceed: @escaping () -> Void) -> some View {
        modifier(UsageGateModifier(isAttemptingAction: isAttemptingAction, onProceed: onProceed))
    }
}
