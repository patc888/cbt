import SwiftUI
import StoreKit
import SwiftData

struct SubscriptionView: View {
    // MARK: - Environment & State
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // Configuration
    let config: SubscriptionConfig
    
    @State private var selectedPlanID: String?
    @State private var isPurchasing: Bool = false
    
    // Grid Columns: Adaptive layout for products
    private var useTwoUpLayout: Bool {
        // Regular width and not large accessibility sizes
        horizontalSizeClass == .regular && dynamicTypeSize < .accessibility1
    }
    
    // MARK: - Init
    init(config: SubscriptionConfig = .mock) {
        self.config = config
        // Default initialized plan
        _selectedPlanID = State(initialValue: "com.xeo.CBT.premium.yearly")
    }
    
    var body: some View {
        ZStack {
            // Modal container surface (adapts to Theme)
            Group {
                if themeManager.isImmersive {
                    AuroraBackground(activeColorTheme: themeManager.selectedTheme)
                } else {
                    Color(uiColor: .systemBackground)
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
        .preferredColorScheme(themeManager.appTheme.colorScheme)
        .onAppear {
            if subscriptionManager.availableProducts.isEmpty {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
             if isPremium {
                 dismiss()
             }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // App Icon
            AppIconView(size: 100)
                .cornerRadius(22)
            
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
                ProgressView("Loading plans...")
                    .padding()
            } else {
                // Products layout (using config plans since availableProducts might be empty in stub mode)
                VStack(spacing: 16) {
                    if useTwoUpLayout {
                        // Regular width layout: 2-up for first two plans, full-width for others
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                if config.plans.count > 0 {
                                    StoreProductCardView(
                                        plan: config.plans[0],
                                        isSelected: selectedPlanID == config.plans[0].id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = config.plans[0].id }
                                    )
                                }
                                if config.plans.count > 1 {
                                    StoreProductCardView(
                                        plan: config.plans[1],
                                        isSelected: selectedPlanID == config.plans[1].id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = config.plans[1].id }
                                    )
                                }
                            }
                            
                            if let lifetime = config.oneTimeOption {
                                StoreProductCardView(
                                    plan: lifetime,
                                    isSelected: selectedPlanID == lifetime.id,
                                    isFullWidth: true,
                                    action: { selectedPlanID = lifetime.id }
                                )
                            }
                        }
                    } else {
                        // Compact layout: First two side-by-side, others below
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                if config.plans.count > 0 {
                                    StoreProductCardView(
                                        plan: config.plans[0],
                                        isSelected: selectedPlanID == config.plans[0].id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = config.plans[0].id }
                                    )
                                }
                                if config.plans.count > 1 {
                                    StoreProductCardView(
                                        plan: config.plans[1],
                                        isSelected: selectedPlanID == config.plans[1].id,
                                        isFullWidth: false,
                                        action: { selectedPlanID = config.plans[1].id }
                                    )
                                }
                            }
                            if let lifetime = config.oneTimeOption {
                                StoreProductCardView(
                                    plan: lifetime,
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
                .fill(themeManager.isImmersive ? (colorScheme == .light ? Color(uiColor: .systemBackground) : Color.clear) : (colorScheme == .light ? Color(uiColor: .systemBackground) : Color(uiColor: .systemBackground)))
                .background(themeManager.isImmersive ? (colorScheme == .light ? AnyShapeStyle(Color(uiColor: .systemBackground)) : AnyShapeStyle(.ultraThinMaterial)) : AnyShapeStyle(Color.clear))
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
                        .fill(themeManager.primaryColor)
                        .shadow(color: themeManager.primaryColor.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 12, x: 0, y: 6)
                )
                .foregroundColor(.white)
            }
            .disabled(selectedPlanID == nil || isPurchasing)
            
            if let planID = selectedPlanID,
               let plan = (config.plans + [config.oneTimeOption].compactMap { $0 }).first(where: { $0.id == planID }),
               plan.hasFreeTrial {
                Text("Then \(plan.price)\(plan.billingFrequency). Cancel anytime before trial ends.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func buttonCTAText() -> String {
        guard let planID = selectedPlanID,
              let plan = (config.plans + [config.oneTimeOption].compactMap { $0 }).first(where: { $0.id == planID }) else {
            return config.ctaTitle
        }
        
        if plan.hasFreeTrial {
            return "Start 7-Day Free Trial"
        }
        
        return config.ctaTitle
    }
    
    private var footerActionsRow: some View {
        HStack {
            ForEach(config.secondaryActions) { action in
                Button(action: { handleSecondaryAction(action.actionID) }) {
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
        HapticManager.shared.mediumImpact()
        guard let planID = selectedPlanID else { return }
        
        isPurchasing = true
        Task {
            let success = await subscriptionManager.purchase(planID)
            await MainActor.run { 
                isPurchasing = false 
                if success {
                    dismiss()
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
            if let url = URL(string: "https://xeo.com/CBT/terms.html") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        } else if actionID == "privacy" {
            if let url = URL(string: "https://xeo.com/CBT/privacy-policy.html") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

// MARK: - Subviews

struct StoreProductCardView: View {
    let plan: SubscriptionConfig.SubscriptionPlan
    let isSelected: Bool
    var isFullWidth: Bool = false
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
                    .fill(isSelected ? themeManager.primaryColor.opacity(0.12) : Color.primary.opacity(0.02))
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(themeManager.isImmersive ? Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.05 : 0.6) : Color(uiColor: .systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? themeManager.primaryColor.opacity(0.8) : (plan.isRecommended ? themeManager.primaryColor.opacity(0.25) : Color.clear), lineWidth: isSelected ? 2 : (plan.isRecommended ? 1.5 : 0))
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if plan.isRecommended, let badge = plan.badge {
                Text(badge)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.primaryColor)
                    .clipShape(Capsule())
                    // Visual "tab" onto top edge
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, isFullWidth ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plan.label)
        .accessibilityValue("\(plan.price), \(isSelected ? "Selected" : "Not selected")")
        .accessibilityHint("Double tap to select this plan")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    @ViewBuilder
    private var planTitleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.label)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                
            if plan.id.localizedCaseInsensitiveContains("lifetime") {
                Text("One time payment")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var priceDisplayView: some View {
        VStack(alignment: isFullWidth ? .trailing : .leading, spacing: 4) {
            if plan.hasFreeTrial {
                Text("7-day free trial, then")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, -2)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(plan.price)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                
                if !plan.id.localizedCaseInsensitiveContains("lifetime") {
                    Text(plan.billingFrequency)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: isFullWidth ? .trailing : .leading)
            
            if !plan.id.localizedCaseInsensitiveContains("lifetime") {
                Text("Auto-renews unless canceled")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.8))
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

// MARK: - Decoration & Features

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
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "sparkle" : "sparkles")
                    .font(.system(size: CGFloat.random(in: 12...24)))
                    .foregroundStyle(themeManager.primaryColor.opacity(0.3))
                    .offset(
                        x: CGFloat.random(in: 0...size.width) - size.width/2,
                        y: CGFloat.random(in: 0...size.height/2) - size.height/4
                    )
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }
}
