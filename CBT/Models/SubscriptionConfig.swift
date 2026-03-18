import SwiftUI

struct SubscriptionConfig: Codable, Equatable {
    let title: String
    let subtitle: String
    let plans: [SubscriptionPlan]
    let oneTimeOption: SubscriptionPlan?
    let features: [SubscriptionFeature]
    let ctaTitle: String
    let secondaryActions: [SecondaryAction]
    
    struct SubscriptionPlan: Identifiable, Codable, Equatable {
        let id: String
        let label: String
        let price: String
        let billingFrequency: String
        let badge: String?
        let isRecommended: Bool
        let hasFreeTrial: Bool
        
        init(id: String, label: String, price: String, billingFrequency: String, badge: String? = nil, isRecommended: Bool = false, hasFreeTrial: Bool = false) {
            self.id = id
            self.label = label
            self.price = price
            self.billingFrequency = billingFrequency
            self.badge = badge
            self.isRecommended = isRecommended
            self.hasFreeTrial = hasFreeTrial
        }
    }
    
    struct SubscriptionFeature: Identifiable, Codable, Equatable {
        var id: String { title }
        let icon: String // SF Symbol name
        let title: String
        let description: String
    }
    
    struct SecondaryAction: Identifiable, Codable, Equatable {
        var id: String { title }
        let title: String
        let actionID: String // To be handled by the view model
    }
}

extension SubscriptionConfig {
    static let mock = SubscriptionConfig(
        title: "Full Access",
        subtitle: "One subscription for all your devices with unlimited access.",
        plans: [
            SubscriptionPlan(id: "com.xeo.CBT.premium.yearly", label: "Yearly", price: "$11.99", billingFrequency: "/year", badge: "50% OFF", isRecommended: true, hasFreeTrial: true),
            SubscriptionPlan(id: "com.xeo.CBT.premium.monthly", label: "Monthly", price: "$1.99", billingFrequency: "/month")
        ],
        oneTimeOption: SubscriptionPlan(id: "com.xeo.CBT.premium.lifetime", label: "Lifetime", price: "$39.99", billingFrequency: "one-time payment"),
        features: [
            SubscriptionFeature(icon: "list.bullet.clipboard", title: "Unlimited Entries", description: "Log as often as you like and track your thoughts without any restrictions."),
            SubscriptionFeature(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", description: "Discover deep insights into your mental well-being with trend analysis."),
            SubscriptionFeature(icon: "icloud.fill", title: "iCloud Sync", description: "Your data stays in sync securely across your iPhone, iPad, and Mac."),
            SubscriptionFeature(icon: "target", title: "Goal Focused", description: "Stay on track with specialized maintenance modes to support your progress.")
        ],
        ctaTitle: "Continue",
        secondaryActions: [
            SecondaryAction(title: "Restore", actionID: "restore"),
            SecondaryAction(title: "Terms of Use", actionID: "terms"),
            SecondaryAction(title: "Privacy Policy", actionID: "privacy")
        ]
    )
}
