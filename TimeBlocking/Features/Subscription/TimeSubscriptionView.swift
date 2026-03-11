import StoreKit
import SwiftUI

struct TimeSubscriptionView: View {
    // MARK: - Environment & State
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    
    private var store: TimeSubscriptionStore {
        appEnvironment.subscriptionStore
    }
    
    private var config: TimeSubscriptionConfig {
        store.config
    }
    
    @State private var selectedPlanID: String?
    
    #if DEBUG
    @AppStorage("devDiagnosticsEnabled") private var devDiagnosticsEnabled = false
    #endif
    
    // Grid Columns: Adaptive layout for products
    private var useTwoUpLayout: Bool {
        // Regular width and not large accessibility sizes
        horizontalSizeClass == .regular && dynamicTypeSize < .accessibility1
    }
    
    // MARK: - Products Mapping
    private var yearlyPlan: TimeSubscriptionConfig.Plan? {
        config.plans.first(where: { $0.id == "yearly" })
    }
    private var monthlyPlan: TimeSubscriptionConfig.Plan? {
        config.plans.first(where: { $0.id == "monthly" })
    }
    private var lifetimePlan: TimeSubscriptionConfig.Plan? {
        config.plans.first(where: { $0.id == "lifetime" })
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Modal container surface
            AuroraBackground()
                .ignoresSafeArea()
            
            // Decorative background elements
            DecorationView()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 40)
                    
                    VStack(spacing: 20) {
                        planSelectionSection
                        
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
        .task {
            if selectedPlanID == nil {
                selectedPlanID = config.recommendedPlanID
            }
            await store.refresh()
        }
        .onChange(of: store.isPremium) { _, isPremium in
             if isPremium {
                 dismiss()
             }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // App Icon / Branding
            subscriptionIcon
                .frame(width: 100, height: 100)
                .cornerRadius(22)
                .shadow(color: Theme.primaryPurple.opacity(0.3), radius: 15, x: 0, y: 8)
            
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
    
    private var subscriptionIcon: some View {
        Group {
            #if os(iOS)
            if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let lastIcon = iconFiles.last,
               let image = UIImage(named: lastIcon) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                AppIconView(size: 100)
            }
            #else
            AppIconView(size: 100)
            #endif
        }
    }
    
    private var planSelectionSection: some View {
        VStack(spacing: 20) {
            if store.purchaseState == .loadingProducts && store.availableProductsByID.isEmpty {
                ProgressView("Loading plans...")
                    .padding()
            } else if store.availableProductsByID.isEmpty && !store.isBusy {
                VStack(spacing: 16) {
                    Text("Unable to load plans")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Button("Try Again") {
                        Task { await store.refresh() }
                    }
                    .buttonStyle(.bordered)
                    
                    #if DEBUG
                    if devDiagnosticsEnabled {
                        DisclosureGroup("DEBUG Diagnostics") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("IDs Requested: \(config.productIDs.joined(separator: ", "))")
                                Text("Available Count: \(store.availableProductsByID.count)")
                                if let errorMsg = store.lastErrorMessage {
                                    Text("Last Error: \(errorMsg)")
                                        .foregroundStyle(.red)
                                }
                                Text("Common Fixes:")
                                Text("1. Attach StoreKit Config file in Simulator scheme.\n2. Sign into a Sandbox Apple ID in Settings.\n3. Ensure Product IDs exist exactly in App Store Connect.")
                                    .padding(.leading, 8)
                                    .opacity(0.8)
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(.caption, weight: .bold))
                        .tint(.red)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    }
                    #endif
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    if useTwoUpLayout {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                if let yearly = yearlyPlan {
                                    StoreProductCardView(
                                        plan: yearly,
                                        product: store.product(for: yearly),
                                        isSelected: selectedPlanID == yearly.id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = yearly.id }
                                    )
                                }
                                if let monthly = monthlyPlan {
                                    StoreProductCardView(
                                        plan: monthly,
                                        product: store.product(for: monthly),
                                        isSelected: selectedPlanID == monthly.id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = monthly.id }
                                    )
                                }
                            }
                            
                            if let lifetime = lifetimePlan {
                                StoreProductCardView(
                                    plan: lifetime,
                                    product: store.product(for: lifetime),
                                    isSelected: selectedPlanID == lifetime.id,
                                    isFullWidth: true,
                                    action: { selectedPlanID = lifetime.id }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                if let yearly = yearlyPlan {
                                    StoreProductCardView(
                                        plan: yearly,
                                        product: store.product(for: yearly),
                                        isSelected: selectedPlanID == yearly.id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = yearly.id }
                                    )
                                }
                                if let monthly = monthlyPlan {
                                    StoreProductCardView(
                                        plan: monthly,
                                        product: store.product(for: monthly),
                                        isSelected: selectedPlanID == monthly.id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = monthly.id }
                                    )
                                }
                            }
                            if let lifetime = lifetimePlan {
                                StoreProductCardView(
                                    plan: lifetime,
                                    product: store.product(for: lifetime),
                                    isSelected: selectedPlanID == lifetime.id,
                                    isFullWidth: true,
                                    action: { selectedPlanID = lifetime.id }
                                )
                            }
                        }
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
                .fill(Theme.backgroundColor.opacity(colorScheme == .dark ? 0.05 : 0.6))
        )
    }
    
    private var anchoredBottomArea: some View {
        VStack(spacing: 12) {
            primaryCTAButton
            
            footerActionsRow
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: horizontalSizeClass == .regular ? 640 : .infinity)
        .background(
            Rectangle()
                .fill(colorScheme == .light ? Theme.backgroundColor : Color.clear)
                .background(colorScheme == .light ? AnyShapeStyle(Theme.backgroundColor) : AnyShapeStyle(.ultraThinMaterial))
                .ignoresSafeArea()
        )
        .frame(maxWidth: .infinity)
    }
    
    private var primaryCTAButton: some View {
        Button(action: handleCTAPress) {
            ZStack {
                if case .purchasing = store.purchaseState {
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
                    .fill(Theme.primaryPurple)
                    .shadow(color: Theme.primaryPurple.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 12, x: 0, y: 6)
            )
            .foregroundColor(.white)
        }
        .disabled(selectedPlanID == nil || store.isBusy)
        .opacity((selectedPlanID == nil) ? 0.6 : 1.0)
    }
    
    private func buttonCTAText() -> String {
        guard let planID = selectedPlanID,
              let plan = config.plans.first(where: { $0.id == planID }) else {
            return config.ctaTitle
        }
        
        if let product = store.product(for: plan),
           let subscription = product.subscription,
           let introOffer = subscription.introductoryOffer,
           introOffer.paymentMode == .freeTrial {
            
            let trialTime = trialMessage(for: product) ?? ""
            if !trialTime.isEmpty {
                return "Start Free Trial · Bills in \(trialTime)"
            } else {
                return "Start Free Trial"
            }
        }
        
        return config.ctaTitle
    }
    
    private func trialMessage(for product: Product) -> String? {
        guard let subscription = product.subscription,
              let introOffer = subscription.introductoryOffer,
              introOffer.paymentMode == .freeTrial else { return nil }
        
        let period = introOffer.period
        let value = period.value
        let unitString: String
        switch period.unit {
        case .day: unitString = value == 1 ? "day" : "days"
        case .week: unitString = value == 1 ? "week" : "weeks"
        case .month: unitString = value == 1 ? "month" : "months"
        case .year: unitString = value == 1 ? "year" : "years"
        @unknown default: return nil
        }
        
        guard value > 0 else { return nil }
        return "\(value) \(unitString)"
    }
    
    private var footerActionsRow: some View {
        HStack {
            ForEach(config.secondaryActions) { action in
                Button(action: { handleSecondaryAction(action.actionID) }) {
                    Text(action.title)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.secondary)
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
            dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.4))
                .padding(20)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Close")
    }
    
    // MARK: - Helpers
    
    private func handleCTAPress() {
        guard let planID = selectedPlanID,
              let plan = config.plans.first(where: { $0.id == planID }) else {
            return
        }
        
        Task {
            _ = await store.purchase(plan: plan)
        }
    }
    
    private func handleSecondaryAction(_ actionID: String) {
        if actionID == "restore" {
            Task { 
                await store.restorePurchases() 
            }
        } else if actionID == "terms" {
            if let url = URL(string: "https://example.com/terms") {
                openURL(url)
            }
        } else if actionID == "privacy" {
            if let url = URL(string: "https://example.com/privacy") {
                openURL(url)
            }
        }
    }
}

// MARK: - Subviews

struct StoreProductCardView: View {
    let plan: TimeSubscriptionConfig.Plan
    let product: Product?
    let isSelected: Bool
    var isFullWidth: Bool = false
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var displayPrice: String {
        product?.displayPrice ?? plan.fallbackPrice
    }
    
    private var displayDetail: String {
        if let product = product, let subscription = product.subscription {
            let period = subscription.subscriptionPeriod
            let unit = period.unit
            let value = period.value
            let unitName: String
            switch unit {
            case .day: unitName = value == 1 ? "day" : "days"
            case .week: unitName = value == 1 ? "week" : "weeks"
            case .month: unitName = value == 1 ? "month" : "months"
            case .year: unitName = value == 1 ? "yr" : "yrs"
            @unknown default: unitName = ""
            }
            
            let billedText = "Billed at \(product.displayPrice)/\(unitName)"
            let trialText = (subscription.introductoryOffer?.paymentMode == .freeTrial) ? " after free trial" : ""
            return billedText + trialText
        }
        return plan.fallbackDetail
    }
    
    private var periodString: String? {
        if let product = product, let subscription = product.subscription {
            let period = subscription.subscriptionPeriod
            let unit = period.unit
            let value = period.value
            
            switch unit {
            case .day: return value == 1 ? "/ day" : "/ \(value) days"
            case .week: return value == 1 ? "/ week" : "/ \(value) weeks"
            case .month: return value == 1 ? "/ month" : "/ \(value) months"
            case .year: return value == 1 ? "/ year" : "/ \(value) years"
            @unknown default: return nil
            }
        }
        
        // Fallback periods for when product is not yet loaded
        if plan.isLifetime { return nil }
        if plan.id == "yearly" { return "/ year" }
        if plan.id == "monthly" { return "/ month" }
        
        return nil
    }

    var body: some View {
        Button(action: action) {
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
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(.all, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: isFullWidth ? nil : 136, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Theme.primaryPurple.opacity(0.12) : Color.primary.opacity(0.02))
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.backgroundColor.opacity(colorScheme == .dark ? 0.05 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Theme.primaryPurple.opacity(0.8) : (plan.isRecommended ? Theme.primaryPurple.opacity(0.25) : Color.clear), lineWidth: isSelected ? 2 : (plan.isRecommended ? 1.5 : 0))
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if plan.isRecommended {
                Text(plan.badge ?? "50% OFF")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.primaryPurple)
                    .clipShape(Capsule())
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, isFullWidth ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plan.title)
        .accessibilityValue("\(displayPrice), \(isSelected ? "Selected" : "Not selected")")
        .accessibilityHint("Double tap to select this plan")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var planTitleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            if plan.isLifetime {
                Text("One time payment")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var priceDisplayView: some View {
        VStack(alignment: isFullWidth ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(displayPrice)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                if let period = periodString {
                    Text(period)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: isFullWidth ? .trailing : .leading)
            
            Text(displayDetail)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: isFullWidth ? .trailing : .leading)
        }
    }
    
    private var indicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Theme.primaryPurple : Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 22, height: 22)
            
            if isSelected {
                Circle()
                    .fill(Theme.primaryPurple)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.leading, isFullWidth ? 12 : 0)
    }
}

struct FeatureRowView: View {
    let feature: TimeSubscriptionConfig.Feature
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.primaryPurple.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryPurple)
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
                    .fill(Theme.primaryPurple.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .frame(width: max(geometry.size.width, geometry.size.height) * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.2)
                
                Circle()
                    .fill(Theme.primaryPurple.opacity(colorScheme == .dark ? 0.25 : 0.1))
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
                    .foregroundStyle(Theme.primaryPurple.opacity(0.3))
                    .offset(
                        x: CGFloat.random(in: 0...size.width) - size.width/2,
                        y: CGFloat.random(in: 0...size.height/2) - size.height/4
                    )
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }
}


