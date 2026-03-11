import SwiftUI
import SwiftData
import StoreKit

struct TimeSubscriptionSettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let isPremium: Bool
    let action: () -> Void
    
    private var dynamicFootnote: String? {
        let store = appEnvironment.subscriptionStore
        let yearlyPlan = store.config.plans.first { $0.id == "yearly" }
        guard let yearlyPlan, let product = store.product(for: yearlyPlan) else {
            return store.config.billingFootnote
        }
        
        let priceString = product.displayPrice
        var billingUnit = "year"
        
        if let subscription = product.subscription {
            switch subscription.subscriptionPeriod.unit {
            case .day: billingUnit = "day"
            case .week: billingUnit = "week"
            case .month: billingUnit = "month"
            case .year: billingUnit = "year"
            @unknown default: break
            }
        }
        
        if let subscription = product.subscription,
           let introOffer = subscription.introductoryOffer,
           introOffer.paymentMode == .freeTrial {
            
            let period = introOffer.period
            let trialValue = period.value
            let trialUnit: String
            
            switch period.unit {
            case .day: trialUnit = "day"
            case .week: trialUnit = "week"
            case .month: trialUnit = "month"
            case .year: trialUnit = "year"
            @unknown default: trialUnit = "day"
            }
            
            return "\(priceString) per \(billingUnit) after \(trialValue)-\(trialUnit) trial."
        } else {
            return "\(priceString) per \(billingUnit)."
        }
    }
    
    var body: some View {
        TimeSettingsSection(title: "") {
            TimeFullAccessCard(
                isPremium: isPremium,
                subtitle: isPremium ? "All premium planning features are unlocked." : appEnvironment.subscriptionStore.config.subtitle,
                footnote: isPremium ? nil : dynamicFootnote,
                isLoading: appEnvironment.subscriptionStore.isBusy,
                action: action
            )
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPremium {
                HapticManager.shared.lightImpact()
                action()
            }
        }
    }
}
