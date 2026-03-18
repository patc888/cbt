import SwiftUI
import SwiftData
import StoreKit

struct UsageGate {
    static let maxFreeUses = 10
    
    @MainActor
    static func canCreateNewItem(in context: ModelContext) -> Bool {
        if SubscriptionManager.shared.isPremium { return true }
        
        // Count total non-deleted mood entries
        let moodCount = (try? context.fetchCount(FetchDescriptor<MoodEntry>(predicate: #Predicate { !$0.isDeleted }))) ?? 0
        
        // Count total non-deleted thought records
        let thoughtCount = (try? context.fetchCount(FetchDescriptor<ThoughtRecord>(predicate: #Predicate { !$0.isDeleted }))) ?? 0
        
        return (moodCount + thoughtCount) < maxFreeUses
    }
    
    @MainActor
    static func currentUsageCount(in context: ModelContext) -> Int {
        let moodCount = (try? context.fetchCount(FetchDescriptor<MoodEntry>(predicate: #Predicate { !$0.isDeleted }))) ?? 0
        let thoughtCount = (try? context.fetchCount(FetchDescriptor<ThoughtRecord>(predicate: #Predicate { !$0.isDeleted }))) ?? 0
        return moodCount + thoughtCount
    }
}

struct UsageGateModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @AppStorage("hasShownPrePaywallReview") private var hasShownPrePaywallReview = false
    @Binding var isAttemptingAction: Bool
    let onProceed: () -> Void
    
    @State private var showingLimitModal = false
    @State private var showingSubscription = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isAttemptingAction) { _, newValue in
                if newValue {
                    // Reset the toggle immediately so it can be fired again if needed
                    isAttemptingAction = false
                    
                    if UsageGate.canCreateNewItem(in: modelContext) {
                        // Check if about to hit the pre-paywall threshold
                        let isPremium = SubscriptionManager.shared.isPremium
                        let currentCount = UsageGate.currentUsageCount(in: modelContext)
                        
                        // We want to trigger it "before the user reaches the paywall limit"
                        // Specifically: 1 action before the 15th, or in this case, 1 action before maxFreeUses
                        let threshold = UsageGate.maxFreeUses - 1
                        
                        // We show it only once at the intended threshold
                        if !hasShownPrePaywallReview && !isPremium && currentCount == threshold {
                            hasShownPrePaywallReview = true
                            requestReview()
                        }
                        
                        onProceed()
                    } else {
                        showingLimitModal = true
                    }
                }
            }
            .sheet(isPresented: $showingLimitModal) {
                FeatureModalPresenter {
                    DSFeatureModal(
                        title: "Free Limit Reached",
                        subtitle: "You've used your 10 free entries. Subscribe to Premium to continue creating new mood check-ins and thought records.",
                        bullets: [
                            DSBullet(icon: "lock.open.fill", text: "Unlimited Mood Check-ins"),
                            DSBullet(icon: "brain.head.profile", text: "Unlimited Thought Records")
                        ],
                        primaryTitle: "View Premium Plans",
                        primaryAction: {
                            HapticManager.shared.lightImpact()
                            showingLimitModal = false
                            
                            // Delay slightly to allow the modal to smoothly disappear before showing full screen subscription
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showingSubscription = true
                            }
                        },
                        secondaryTitle: "Maybe Later",
                        secondaryAction: {
                            HapticManager.shared.lightImpact()
                            showingLimitModal = false
                        },
                        closeAction: {
                            HapticManager.shared.lightImpact()
                            showingLimitModal = false
                        }
                    )
                }
                .presentationDetents([.fraction(0.85), .large])
            }
        #if os(macOS)
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
                    .frame(minWidth: 600, minHeight: 600)
            }
        #else
            .fullScreenCover(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        #endif
    }
}

extension View {
    func withUsageGate(isAttemptingAction: Binding<Bool>, onProceed: @escaping () -> Void) -> some View {
        modifier(UsageGateModifier(isAttemptingAction: isAttemptingAction, onProceed: onProceed))
    }
}
