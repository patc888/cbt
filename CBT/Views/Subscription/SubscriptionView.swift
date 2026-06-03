import SwiftUI
import StoreKit
import SwiftData

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @State private var subscriptionManager = SubscriptionManager.shared

    let config: SubscriptionConfig

    @State private var selectedPlanID: String?
    @State private var isPurchasing = false

    private var userSettings: UserSettings? { settings.first }

    private var yearlyProduct: Product? {
        subscriptionManager.availableProducts.first { $0.id == SubscriptionProductIDs.yearly }
    }

    private var monthlyProduct: Product? {
        subscriptionManager.availableProducts.first { $0.id == SubscriptionProductIDs.monthly }
    }

    private var lifetimeProduct: Product? {
        subscriptionManager.availableProducts.first { $0.id == SubscriptionProductIDs.lifetime }
    }

    init(config: SubscriptionConfig = .cbt) {
        self.config = config
        _selectedPlanID = State(initialValue: SubscriptionProductIDs.yearly)
    }

    var body: some View {
        CBTPaywallTemplateView(
            config: config,
            yearlyProduct: yearlyProduct,
            monthlyProduct: monthlyProduct,
            lifetimeProduct: lifetimeProduct,
            isLoading: subscriptionManager.isLoading,
            availableProductsEmpty: subscriptionManager.availableProducts.isEmpty,
            errorMessage: subscriptionManager.errorMessage,
            selectedPlanID: selectedPlanID,
            isPurchasing: isPurchasing,
            onSelectPlan: { planID in
                selectedPlanID = planID
            },
            onPurchase: handleCTAPress,
            onRestore: handleRestore,
            onClose: {
                dismiss()
            },
            onTryAgain: {
                Task { await subscriptionManager.loadProducts(force: true) }
            },
            onTerms: {
                openURL("https://meliapps.com/CBT/terms.html")
            },
            onPrivacy: {
                openURL("https://meliapps.com/CBT/privacy-policy.html")
            }
        )
        .onAppear {
            LocalRetentionEventStore.shared.record(.paywallShown, sourceScreen: "subscription")
            if subscriptionManager.availableProducts.isEmpty {
                Task {
                    await subscriptionManager.loadProducts()
                    if selectedPlanID == nil || selectedPlanID == SubscriptionProductIDs.yearly,
                       let yearly = yearlyProduct {
                        selectedPlanID = yearly.id
                    }
                }
            }
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
            if isPremium {
                updateUserSettings()
                dismiss()
            }
        }
    }

    private func handleCTAPress() {
        let planID = selectedPlanID ?? yearlyProduct?.id ?? ""
        guard let productToPurchase = subscriptionManager.availableProducts.first(where: { $0.id == planID }) else {
            return
        }

        isPurchasing = true
        Task {
            let success = await subscriptionManager.purchase(productToPurchase)
            await MainActor.run {
                isPurchasing = false
                if success {
                    LocalRetentionEventStore.shared.record(
                        .purchaseCompleted,
                        sourceScreen: "subscription",
                        metadata: ["product": productToPurchase.id]
                    )
                    updateUserSettings()
                    HapticManager.shared.success()
                    dismiss()
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func handleRestore() {
        isPurchasing = true
        Task {
            await subscriptionManager.restorePurchases()
            await MainActor.run {
                isPurchasing = false
                if subscriptionManager.isPremium {
                    LocalRetentionEventStore.shared.record(.purchaseRestored, sourceScreen: "subscription")
                    updateUserSettings()
                }
            }
        }
    }

    private func updateUserSettings() {
        guard let settings = userSettings else { return }
        settings.isPremium = subscriptionManager.isPremium
        try? modelContext.save()
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

struct CBTPaywallTemplateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(ThemeManager.self) private var themeManager

    let config: SubscriptionConfig
    let yearlyProduct: Product?
    let monthlyProduct: Product?
    let lifetimeProduct: Product?
    let isLoading: Bool
    let availableProductsEmpty: Bool
    let errorMessage: String?
    let selectedPlanID: String?
    let isPurchasing: Bool

    let onSelectPlan: (String) -> Void
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onClose: () -> Void
    let onTryAgain: () -> Void
    let onTerms: () -> Void
    let onPrivacy: () -> Void

    private var useTwoUpLayout: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize < .accessibility1
    }

    var body: some View {
        ZStack {
            Group {
                if themeManager.isImmersive {
                    AuroraBackground(activeColorTheme: themeManager.selectedTheme)
                } else {
                    Color(uiColor: .systemBackground)
                }
            }
            .ignoresSafeArea()

            DecorationView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 40)
                    VStack(spacing: 20) {
                        planSelectionSection
                        familySharingBadge
                        featuresSection
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 24)
                .responsiveMaxWidth()
            }
            .safeAreaInset(edge: .bottom) {
                anchoredBottomArea
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: selectedPlanID)
        .preferredColorScheme(themeManager.appTheme.colorScheme)
    }

    private var headerSection: some View {
        VStack(spacing: 20) {
            AppIconView(size: 100)
                .cornerRadius(22)

            VStack(spacing: 6) {
                Text(config.title)
                    .font(DSTypography.pageTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(config.subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, -8)
            }
        }
    }

    private var planSelectionSection: some View {
        VStack(spacing: 20) {
            if isLoading && availableProductsEmpty {
                ProgressView(String(localized: "Loading plans..."))
                    .padding()
            } else if availableProductsEmpty {
                VStack(spacing: 16) {
                    Text(String(localized: "Unable to load plans"))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.errorRed)
                            .multilineTextAlignment(.center)
                    }

                    Button(String(localized: "Try Again")) {
                        HapticManager.shared.mediumImpact()
                        onTryAgain()
                    }
                    .buttonStyle(DSSecondaryButtonStyle(size: .medium))
                }
                .padding()
            } else {
                VStack(spacing: useTwoUpLayout ? 16 : 12) {
                    HStack(spacing: useTwoUpLayout ? 16 : 12) {
                        if let yearly = yearlyProduct {
                            StoreProductCardView(
                                product: yearly,
                                isSelected: selectedPlanID == yearly.id,
                                isFullWidth: false,
                                isRecommended: true,
                                action: { onSelectPlan(yearly.id) }
                            )
                        }
                        if let monthly = monthlyProduct {
                            StoreProductCardView(
                                product: monthly,
                                isSelected: selectedPlanID == monthly.id,
                                isFullWidth: false,
                                isRecommended: false,
                                action: { onSelectPlan(monthly.id) }
                            )
                        }
                    }

                    if let lifetime = lifetimeProduct {
                        StoreProductCardView(
                            product: lifetime,
                            isSelected: selectedPlanID == lifetime.id,
                            isFullWidth: true,
                            isRecommended: false,
                            action: { onSelectPlan(lifetime.id) }
                        )
                    }
                }
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(config.features) { feature in
                FeatureRowView(feature: feature)
            }
        }
        .padding(.all, 28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(themeManager.isImmersive ? Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.05 : 0.6) : Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.clear, lineWidth: 1)
        )
    }

    private var anchoredBottomArea: some View {
        VStack(spacing: 12) {
            primaryCTAButton
            footerActionsRow
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 24)
        .padding(.top, 16)
        .padding(.bottom, 0)
        .frame(maxWidth: horizontalSizeClass == .regular ? 640 : .infinity)
        .background(
            Rectangle()
                .fill(themeManager.isImmersive ? (colorScheme == .light ? Color(uiColor: .systemBackground) : Color.clear) : Color(uiColor: .systemBackground))
                .background(themeManager.isImmersive ? (colorScheme == .light ? AnyShapeStyle(Color(uiColor: .systemBackground)) : AnyShapeStyle(.ultraThinMaterial)) : AnyShapeStyle(Color.clear))
                .ignoresSafeArea()
        )
        .frame(maxWidth: .infinity)
    }

    private var primaryCTAButton: some View {
        VStack(spacing: 8) {
            Button(action: {
                HapticManager.shared.mediumImpact()
                onPurchase()
            }) {
                ZStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonCTAText())
                    }
                }
            }
            .disabled(selectedPlanID == nil || isPurchasing || availableProductsEmpty)
            .buttonStyle(DSButtonStyle(variant: .primary, tint: themeManager.primaryColor, hapticType: nil))

            if let planID = selectedPlanID {
                let allProducts = [yearlyProduct, monthlyProduct, lifetimeProduct].compactMap { $0 }
                if let product = allProducts.first(where: { $0.id == planID }),
                   product.hasFreeTrial,
                   let period = product.subscription?.subscriptionPeriod {
                    let frequencyLabel = product.isYearly ? "year" : period.unitShortName
                    Text("then \(product.displayPrice)/\(frequencyLabel). Cancel anytime before trial ends.")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func buttonCTAText() -> String {
        guard let planID = selectedPlanID else {
            return String(localized: "Continue")
        }

        let allProducts = [yearlyProduct, monthlyProduct, lifetimeProduct].compactMap { $0 }
        guard let product = allProducts.first(where: { $0.id == planID }) else {
            return String(localized: "Continue")
        }

        if product.isYearly {
            return String(localized: "Start 7-Day Free Trial")
        } else if let trialTime = product.trialMessage, !trialTime.isEmpty {
            return String(localized: "Start \(trialTime) Free Trial")
        } else if product.hasFreeTrial {
            return String(localized: "Start 7-Day Free Trial")
        }

        return config.ctaTitle
    }

    private var familySharingBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 54, height: 54)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(themeManager.primaryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Works with Family Sharing"))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(String(localized: "Share with up to 5 family members in your Apple iCloud family group."))
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.all, 24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(themeManager.isImmersive ? Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.05 : 0.6) : Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(themeManager.primaryColor.opacity(0.15), lineWidth: 1.5)
        )
    }

    private var footerActionsRow: some View {
        HStack {
            ForEach(config.secondaryActions) { action in
                Button(action: {
                    HapticManager.shared.lightImpact()
                    if action.actionID == "restore" {
                        onRestore()
                    } else if action.actionID == "terms" {
                        onTerms()
                    } else if action.actionID == "privacy" {
                        onPrivacy()
                    }
                }) {
                    Text(action.title)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
                .buttonStyle(.plain)

                if action.id != config.secondaryActions.last?.id {
                    Spacer()
                }
            }
        }
    }

    private var closeButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onClose()
        }) {
            Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(DSButtonStyle(variant: .neutral, size: .icon(44), expands: false, hapticType: nil))
        .accessibilityLabel(String(localized: "Close"))
    }
}

struct StoreProductCardView: View {
    let product: Product
    let isSelected: Bool
    var isFullWidth = false
    var isRecommended = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            Group {
                if isFullWidth {
                    HStack(alignment: .center) {
                        planTitleView
                        Spacer()
                        priceDisplayView
                        indicator
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            planTitleView
                            Spacer()
                            indicator
                        }
                        priceDisplayView
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.all, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(minHeight: isFullWidth ? nil : 136, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? themeManager.primaryColor.opacity(0.12) : Color.primary.opacity(0.02))
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(themeManager.isImmersive ? Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.05 : 0.6) : Color(uiColor: .systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? themeManager.primaryColor.opacity(0.8) : (isRecommended ? themeManager.primaryColor.opacity(0.25) : Color.clear), lineWidth: isSelected ? 2 : (isRecommended ? 1.5 : 0))
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if isRecommended {
                Text(String(localized: "50% OFF"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.primaryColor)
                    .clipShape(Capsule())
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, isFullWidth ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(product.displayTitle))
        .accessibilityValue(Text("\(product.displayPrice), \(isSelected ? String(localized: "Selected") : String(localized: "Not selected"))"))
        .accessibilityHint(Text(String(localized: "Double tap to select this plan")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var planTitleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.displayTitle)
                .font(DSTypography.pageTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if product.type == .nonConsumable || product.id.localizedCaseInsensitiveContains("lifetime") {
                Text(String(localized: "One time payment"))
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var priceDisplayView: some View {
        VStack(alignment: isFullWidth ? .trailing : .leading, spacing: 4) {
            if product.hasFreeTrial || product.isYearly {
                Text(product.isYearly ? String(localized: "7-day free trial then") : "\(product.trialMessage ?? "7-day") free trial then")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, -2)
            }

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(product.displayPrice)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if let period = product.subscription?.subscriptionPeriod {
                    Text(product.isYearly ? String(localized: "/year") : period.periodDisplayName)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: isFullWidth ? .trailing : .leading)

            if let period = product.subscription?.subscriptionPeriod {
                Text("Auto-renews \(product.isYearly ? "yearly" : period.renewalFrequencyName) unless canceled")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: isFullWidth ? .trailing : .leading)
            } else if !isFullWidth {
                Text(" ")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: isFullWidth ? .trailing : .leading)
            }
        }
    }

    private var indicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? themeManager.primaryColor : Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(themeManager.primaryColor)
                    .frame(width: 12, height: 12)
                    .transition(.scale)
            }
        }
        .padding(.leading, isFullWidth ? 12 : 0)
    }
}

struct FeatureRowView: View {
    let feature: SubscriptionConfig.SubscriptionFeature
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(themeManager.primaryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(feature.description)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DecorationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .frame(width: max(geometry.size.width, geometry.size.height) * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.2)

                Circle()
                    .fill(themeManager.primaryColor.opacity(colorScheme == .dark ? 0.25 : 0.1))
                    .frame(width: max(geometry.size.width, geometry.size.height) * 0.6)
                    .blur(radius: 60)
                    .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.1)

                SparkleGroup(size: geometry.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}

struct SparkleGroup: View {
    let size: CGSize
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: index % 2 == 0 ? "sparkle" : "sparkles")
                    .font(.system(size: CGFloat.random(in: 12...24)))
                    .foregroundStyle(themeManager.primaryColor.opacity(0.3))
                    .offset(
                        x: CGFloat.random(in: 0...size.width) - size.width / 2,
                        y: CGFloat.random(in: 0...size.height / 2) - size.height / 4
                    )
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
    }
}

struct SubscriptionConfig: Codable, Equatable {
    let title: String
    let subtitle: String
    let features: [SubscriptionFeature]
    let ctaTitle: String
    let secondaryActions: [SecondaryAction]

    struct SubscriptionFeature: Identifiable, Codable, Equatable {
        var id: String { title }
        let icon: String
        let title: String
        let description: String
    }

    struct SecondaryAction: Identifiable, Codable, Equatable {
        var id: String { title }
        let title: String
        let actionID: String
    }
}

extension SubscriptionConfig {
    static let cbt = SubscriptionConfig(
        title: "CBT Premium",
        subtitle: "Subscribe to keep Premium access active as the app grows.",
        features: [
            SubscriptionFeature(icon: "star.fill", title: "Premium Access", description: "Keep your account ready for subscriber benefits as new tools and updates are introduced."),
            SubscriptionFeature(icon: "sparkles", title: "Ongoing Updates", description: "Premium helps fund improvements, polish, and new ideas."),
            SubscriptionFeature(icon: "icloud.fill", title: "Same App, Same Data", description: "Your tracking data stays available across your devices."),
            SubscriptionFeature(icon: "checkmark.seal.fill", title: "Flexible Options", description: "Choose monthly, yearly, or lifetime Premium access through the App Store.")
        ],
        ctaTitle: "Continue",
        secondaryActions: [
            SecondaryAction(title: "Restore", actionID: "restore"),
            SecondaryAction(title: "Terms of Use", actionID: "terms"),
            SecondaryAction(title: "Privacy Policy", actionID: "privacy")
        ]
    )

    static let cbtMock = cbt
}

extension Product.SubscriptionPeriod {
    var unitShortName: String {
        if unit == .month && value == 12 { return String(localized: "year") }
        switch unit {
        case .day: return String(localized: "day")
        case .week: return String(localized: "week")
        case .month: return String(localized: "month")
        case .year: return String(localized: "year")
        @unknown default: return ""
        }
    }

    var renewalFrequencyName: String {
        if unit == .month && value == 12 { return String(localized: "yearly") }
        switch unit {
        case .day: return String(localized: "daily")
        case .week: return String(localized: "weekly")
        case .month: return String(localized: "monthly")
        case .year: return String(localized: "yearly")
        @unknown default: return ""
        }
    }

    var periodDisplayName: String {
        if unit == .month && value == 12 { return String(localized: "/year") }
        switch unit {
        case .day: return String(localized: "/day")
        case .week: return String(localized: "/week")
        case .month: return String(localized: "/month")
        case .year: return String(localized: "/year")
        @unknown default: return ""
        }
    }
}

extension Product {
    var isYearly: Bool {
        if id.localizedCaseInsensitiveContains("yearly") {
            return true
        }
        if let subscription {
            let period = subscription.subscriptionPeriod
            return (period.unit == .year && period.value == 1) || (period.unit == .month && period.value == 12)
        }
        return false
    }

    var displayTitle: String {
        if id.localizedCaseInsensitiveContains("monthly") { return String(localized: "Monthly") }
        if id.localizedCaseInsensitiveContains("yearly") { return String(localized: "Yearly") }
        if id.localizedCaseInsensitiveContains("lifetime") { return String(localized: "Lifetime") }

        let clean = displayName
            .replacingOccurrences(of: "CBT", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "subscription", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? displayName : clean.capitalized
    }

    var hasFreeTrial: Bool {
        guard let subscription,
              let introOffer = subscription.introductoryOffer else { return false }
        return introOffer.paymentMode == .freeTrial
    }

    var trialMessage: String? {
        guard hasFreeTrial,
              let introOffer = subscription?.introductoryOffer else { return nil }

        let period = introOffer.period
        let unitString: String
        switch period.unit {
        case .day: unitString = String(localized: "Day")
        case .week: unitString = String(localized: "Week")
        case .month: unitString = String(localized: "Month")
        case .year: unitString = String(localized: "Year")
        @unknown default: return nil
        }

        guard period.value > 0 else { return nil }
        return "\(period.value)-\(unitString)"
    }
}

#Preview {
    SubscriptionView(config: .cbt)
        .modelContainer(for: UserSettings.self, inMemory: true)
}
