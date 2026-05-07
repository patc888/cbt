import SwiftUI
import StoreKit
import SwiftData

private enum TimePaywallSystemColor {
    static var background: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }

    static var gray: Color {
#if os(macOS)
        Color(nsColor: .systemGray)
#else
        Color(uiColor: .systemGray)
#endif
    }
}

struct SubscriptionView: View {
    // MARK: - Environment & State
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var preferences: [AppPreferences]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // Configuration
    let config: SubscriptionConfig
    
    @State private var selectedPlanID: String?
    @State private var isPurchasing: Bool = false
    
    private var appPreferences: AppPreferences? { preferences.first }
    
    // Grid Columns: Adaptive layout for products
    private var useTwoUpLayout: Bool {
        // Regular width and not large accessibility sizes
        horizontalSizeClass == .regular && dynamicTypeSize < .accessibility1
    }
    
    // MARK: - Products Mapping
    private var yearlyProduct: Product? {
        subscriptionManager.availableProducts.first(where: { $0.id == "com.xeo.timeblocking.yearly" })
    }
    private var monthlyProduct: Product? {
        subscriptionManager.availableProducts.first(where: { $0.id == "com.xeo.timeblocking.monthly" })
    }
    private var lifetimeProduct: Product? {
        subscriptionManager.availableProducts.first(where: { $0.id == "com.xeo.timeblocking.lifetime" })
    }
    
    // MARK: - Init
    init(config: SubscriptionConfig = .mock) {
        self.config = config
        // Default initialized plan, we will update it based on loading if needed.
        _selectedPlanID = State(initialValue: "com.xeo.timeblocking.yearly")
    }
    
    var body: some View {
        ZStack {
            // Modal container surface (adapts to Theme)
            Group {
                if Theme.isImmersive {
                    AuroraBackground()
                } else {
                    TimePaywallSystemColor.background
                }
            }
            .ignoresSafeArea()
            
            // Decorative background elements
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
                .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                anchoredBottomArea
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: selectedPlanID)
        .onAppear {
            if subscriptionManager.availableProducts.isEmpty {
                Task {
                    await subscriptionManager.loadProducts()
                    // Sync selection if yearly isn't primary ID
                    if selectedPlanID == nil || selectedPlanID == "com.xeo.timeblocking.yearly",
                       let yearly = yearlyProduct {
                        selectedPlanID = yearly.id
                    }
                }
            }
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
             if isPremium {
                 updateAppPreferences()
                 dismiss()
             }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // App Icon
            AppIconView(size: 100)
                .frame(width: 100, height: 100)
            
            VStack(spacing: 6) {
                Text(config.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
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
            if subscriptionManager.isLoading && subscriptionManager.availableProducts.isEmpty {
                ProgressView(String(localized: "Loading plans..."))
                    .padding()
            } else if subscriptionManager.availableProducts.isEmpty {
                VStack(spacing: 16) {
                    Text(String(localized: "Unable to load plans"))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Button(String(localized: "Try Again")) {
                        HapticManager.shared.mediumImpact()
                        Task { await subscriptionManager.loadProducts() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                // Store products layout
                VStack(spacing: 16) {
                    if useTwoUpLayout {
                        // Regular width layout: 2-up for Yearly/Monthly, full-width for Lifetime
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                if let yearly = yearlyProduct {
                                    StoreProductCardView(
                                        product: yearly,
                                        isSelected: selectedPlanID == yearly.id,
                                        isFullWidth: false,
                                        isRecommended: true,
                                        action: { selectedPlanID = yearly.id }
                                    )
                                }
                                if let monthly = monthlyProduct {
                                    StoreProductCardView(
                                        product: monthly,
                                        isSelected: selectedPlanID == monthly.id,
                                        isFullWidth: false,
                                        isRecommended: false,
                                        action: { selectedPlanID = monthly.id }
                                    )
                                }
                            }
                            
                            if let lifetime = lifetimeProduct {
                                StoreProductCardView(
                                    product: lifetime,
                                    isSelected: selectedPlanID == lifetime.id,
                                    isFullWidth: true,
                                    isRecommended: false,
                                    action: { selectedPlanID = lifetime.id }
                                )
                            }
                        }
                    } else {
                        // Compact layout: Yearly & Monthly side-by-side, Lifetime below
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                if let yearly = yearlyProduct {
                                    StoreProductCardView(
                                        product: yearly,
                                        isSelected: selectedPlanID == yearly.id,
                                        isFullWidth: false,
                                        isRecommended: true,
                                        action: { selectedPlanID = yearly.id }
                                    )
                                }
                                if let monthly = monthlyProduct {
                                    StoreProductCardView(
                                        product: monthly,
                                        isSelected: selectedPlanID == monthly.id,
                                        isFullWidth: false,
                                        isRecommended: false,
                                        action: { selectedPlanID = monthly.id }
                                    )
                                }
                            }
                            if let lifetime = lifetimeProduct {
                                StoreProductCardView(
                                    product: lifetime,
                                    isSelected: selectedPlanID == lifetime.id,
                                    isFullWidth: true,
                                    isRecommended: false,
                                    action: { selectedPlanID = lifetime.id }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var familySharingBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.primaryAccent.opacity(0.1))
                    .frame(width: 54, height: 54)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.primaryAccent)
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
                .fill(Theme.isImmersive ? TimePaywallSystemColor.background.opacity(colorScheme == .dark ? 0.05 : 0.6) : TimePaywallSystemColor.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Theme.primaryAccent.opacity(0.15), lineWidth: 1.5)
        )
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
                .fill(Theme.isImmersive ? TimePaywallSystemColor.background.opacity(colorScheme == .dark ? 0.05 : 0.6) : TimePaywallSystemColor.background)
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
                .fill(Theme.isImmersive ? (colorScheme == .light ? TimePaywallSystemColor.background : Color.clear) : (colorScheme == .light ? TimePaywallSystemColor.background : TimePaywallSystemColor.background))
                .background(Theme.isImmersive ? (colorScheme == .light ? AnyShapeStyle(TimePaywallSystemColor.background) : AnyShapeStyle(.ultraThinMaterial)) : AnyShapeStyle(Color.clear))
                .ignoresSafeArea()
        )
        .frame(maxWidth: .infinity)
    }
    
    private var primaryCTAButton: some View {
        VStack(spacing: 8) {
            Button(action: handleCTAPress) {
                ZStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonCTAText())
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Theme.primaryAccent)
                        .shadow(color: colorScheme == .dark ? Theme.primaryAccent.opacity(0.4) : .clear, radius: colorScheme == .dark ? 12 : 0, x: 0, y: colorScheme == .dark ? 6 : 0)
                )
                .foregroundColor(.white)
            }
            .disabled(selectedPlanID == nil || isPurchasing || subscriptionManager.availableProducts.isEmpty)
            .opacity((selectedPlanID == nil || subscriptionManager.availableProducts.isEmpty) ? 0.6 : 1.0)
            
            if let planID = selectedPlanID {
                let allProducts = [yearlyProduct, monthlyProduct, lifetimeProduct].compactMap { $0 }
                if let product = allProducts.first(where: { $0.id == planID }),
                   product.hasFreeTrial,
                   let period = product.subscription?.subscriptionPeriod {
                    let frequencyLabel = product.isYearly ? "year" : period.unitShortName
                    let priceLabel = product.displayPrice
                    Text("then \(priceLabel)/\(frequencyLabel). Cancel anytime before trial ends.")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func buttonCTAText() -> String {
        guard let planID = selectedPlanID else {
            return String(localized: "Update to Full Access")
        }
        
        let allProducts = [yearlyProduct, monthlyProduct, lifetimeProduct].compactMap { $0 }
        guard let product = allProducts.first(where: { $0.id == planID }) else {
            return String(localized: "Update to Full Access")
        }
        
        if product.isYearly {
            return String(localized: "Start 7-Day Free Trial")
        } else if let trialTime = product.trialMessage, !trialTime.isEmpty {
            return String(localized: "Start \(trialTime) Free Trial")
        } else if product.hasFreeTrial {
            return String(localized: "Start 7-Day Free Trial")
        }
        
        return String(localized: "Update to Full Access")
    }
    
    private var footerActionsRow: some View {
        HStack {
            ForEach(config.secondaryActions) { action in
                Button(action: { handleSecondaryAction(action.actionID) }) {
                    Text(action.title)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(TimePaywallSystemColor.gray)
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
            dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.4))
                .padding(20)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(localized: "Close"))
    }
    
    // MARK: - Helpers
    
    private func handleCTAPress() {
        HapticManager.shared.mediumImpact()
        // Find the fallback to yearly if not set
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
                    updateAppPreferences()
                    HapticManager.shared.success()
                    dismiss()
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func handleSecondaryAction(_ actionID: String) {
        HapticManager.shared.lightImpact()
        if actionID == "restore" {
            isPurchasing = true
             Task { 
                await subscriptionManager.restorePurchases() 
                await MainActor.run { 
                    isPurchasing = false
                }
            }
        } else if actionID == "terms" {
            if let url = URL(string: "https://xeo.com/TimeBlocking/terms.html") {
                openURL(url)
            }
        } else if actionID == "privacy" {
            if let url = URL(string: "https://xeo.com/TimeBlocking/privacy.html") {
                openURL(url)
            }
        }
    }
    
    private func updateAppPreferences() {
        guard let appPreferences else { return }
        appPreferences.isPremium = subscriptionManager.isPremium
        try? modelContext.save()
    }
}

// MARK: - Subviews

struct StoreProductCardView: View {
    let product: Product
    let isSelected: Bool
    var isFullWidth: Bool = false
    var isRecommended: Bool = false
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    @ViewBuilder
    private var planTitleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.paywallDisplayName)
                .font(.system(.title2, design: .rounded, weight: .bold))
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
                let trialLabel: String = {
                    if product.isYearly {
                        return "7-day free trial then"
                    }
                    if let trialTime = product.trialMessage {
                        return "\(trialTime) free trial then"
                    }
                    return "7-day free trial then"
                }()
                Text(trialLabel)
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
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            Group {
                if isFullWidth {
                    // Row Layout (iPhone)
                    HStack(alignment: .center) {
                        planTitleView
                        
                        Spacer()
                        
                        priceDisplayView
                        
                        indicator
                    }
                } else {
                    // Block Layout (iPad/Mac)
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
                    .fill(isSelected ? Theme.primaryAccent.opacity(0.12) : Color.primary.opacity(0.02))
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.isImmersive ? TimePaywallSystemColor.background.opacity(colorScheme == .dark ? 0.05 : 0.6) : TimePaywallSystemColor.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Theme.primaryAccent.opacity(0.8) : (isRecommended ? Theme.primaryAccent.opacity(0.25) : Color.clear), lineWidth: isSelected ? 2 : (isRecommended ? 1.5 : 0))
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
                    .background(Theme.primaryAccent)
                    .clipShape(Capsule())
                    // Visual "tab" onto top edge
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, isFullWidth ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(product.paywallDisplayName))
        .accessibilityValue(Text("\(product.displayPrice), \(isSelected ? String(localized: "Selected") : String(localized: "Not selected"))"))
        .accessibilityHint(Text(String(localized: "Double tap to select this plan")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var indicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Theme.primaryAccent : Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 22, height: 22)
            
            if isSelected {
                Circle()
                    .fill(Theme.primaryAccent)
                    .frame(width: 12, height: 12)
                    .transition(.scale)
            }
        }
        .padding(.leading, isFullWidth ? 12 : 0)
    }
}

// MARK: - Decoration & Features

struct FeatureRowView: View {
    let feature: SubscriptionConfig.SubscriptionFeature
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.primaryAccent.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryAccent)
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(Theme.primaryAccent.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .frame(width: max(geometry.size.width, geometry.size.height) * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.2)
                
                Circle()
                    .fill(Theme.primaryAccent.opacity(colorScheme == .dark ? 0.25 : 0.1))
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
    
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "sparkle" : "sparkles")
                    .font(.system(size: CGFloat.random(in: 12...24)))
                    .foregroundStyle(Theme.primaryAccent.opacity(0.3))
                    .offset(
                        x: CGFloat.random(in: 0...size.width) - size.width/2,
                        y: CGFloat.random(in: 0...size.height/2) - size.height/4
                    )
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }
}

// MARK: - StoreKit Helpers

private extension Product {
    var paywallDisplayName: String {
        if id.localizedCaseInsensitiveContains("monthly") { return "Monthly" }
        if id.localizedCaseInsensitiveContains("yearly") { return "Yearly" }
        if id.localizedCaseInsensitiveContains("lifetime") { return "Lifetime" }

        let clean = displayName
            .replacingOccurrences(of: "TimeBlocking", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Time Blocking", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "subscription", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        return clean.isEmpty ? displayName : clean.capitalized
    }
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

    func unitName(value: Int) -> String? {
        switch unit {
        case .day: return value == 1 ? String(localized: "day") : String(localized: "days")
        case .week: return value == 1 ? String(localized: "week") : String(localized: "weeks")
        case .month: return value == 1 ? String(localized: "month") : String(localized: "months")
        case .year: return value == 1 ? String(localized: "year") : String(localized: "years")
        @unknown default: return nil
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

    var hasFreeTrial: Bool {
        guard let subscription,
              let introOffer = subscription.introductoryOffer else { return false }
        return introOffer.paymentMode == .freeTrial
    }

    var trialMessage: String? {
        guard hasFreeTrial,
              let introOffer = subscription?.introductoryOffer else { return nil }

        let period = introOffer.period
        let value = period.value
        let unitString: String
        switch period.unit {
        case .day: unitString = String(localized: "Day")
        case .week: unitString = String(localized: "Week")
        case .month: unitString = String(localized: "Month")
        case .year: unitString = String(localized: "Year")
        @unknown default: return nil
        }

        guard value > 0 else { return nil }

        return "\(value)-\(unitString)"
    }
}
