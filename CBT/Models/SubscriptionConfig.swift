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
        
        init(id: String, label: String, price: String, billingFrequency: String, badge: String? = nil, isRecommended: Bool = false) {
            self.id = id
            self.label = label
            self.price = price
            self.billingFrequency = billingFrequency
            self.badge = badge
            self.isRecommended = isRecommended
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
        title: String(localized: "Full Access"),
        subtitle: String(localized: "One subscription for all your devices with unlimited access."),
        plans: [
            SubscriptionPlan(id: "com.xeo.CBT.premium.yearly", label: String(localized: "Yearly"), price: "$11.99/year", billingFrequency: String(localized: "Billed at $11.99/yr after trial"), badge: String(localized: "50% OFF"), isRecommended: true),
            SubscriptionPlan(id: "com.xeo.CBT.premium.monthly", label: String(localized: "Monthly"), price: "$1.99/month", billingFrequency: String(localized: "Billed at $1.99/month"))
        ],
        oneTimeOption: SubscriptionPlan(id: "com.xeo.CBT.premium.lifetime", label: String(localized: "Lifetime"), price: "$39.99", billingFrequency: String(localized: "one-time payment")),
        features: [
            SubscriptionFeature(icon: "list.bullet.clipboard", title: String(localized: "Unlimited Entries"), description: String(localized: "Log as often as you like without any restrictions.")),
            SubscriptionFeature(icon: "chart.line.uptrend.xyaxis", title: String(localized: "Advanced Analytics"), description: String(localized: "Get detailed predictions and advanced trends.")),
            SubscriptionFeature(icon: "icloud.fill", title: String(localized: "Multi-Device Sync"), description: String(localized: "Your data stays in sync across iPhone, iPad, and Mac via iCloud.")),
            SubscriptionFeature(icon: "target", title: String(localized: "Maintenance Mode"), description: String(localized: "Special tracking modes for when you've reached your goals."))
        ],
        ctaTitle: String(localized: "Continue"),
        secondaryActions: [
            SecondaryAction(title: String(localized: "Restore"), actionID: "restore"),
            SecondaryAction(title: String(localized: "Terms of Use"), actionID: "terms"),
            SecondaryAction(title: String(localized: "Privacy Policy"), actionID: "privacy")
        ]
    )
}
