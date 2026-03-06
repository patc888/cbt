import SwiftUI
import StoreKit
import SwiftData

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    let config: SubscriptionConfig
    
    @State private var selectedPlanID: String? = "com.xeo.CBT.premium.yearly"
    @State private var isPurchasing: Bool = false
    
    private var useTwoUpLayout: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize < .accessibility1
    }
    
    init(config: SubscriptionConfig = .mock) {
        self.config = config
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
            Task {
                await subscriptionManager.loadProducts()
            }
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
             if isPremium {
                 dismiss()
             }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
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
        VStack(spacing: 16) {
            if useTwoUpLayout {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        StubProductCardView(plan: config.plans[0], isSelected: selectedPlanID == config.plans[0].id, isFullWidth: false, action: { selectedPlanID = config.plans[0].id })
                        StubProductCardView(plan: config.plans[1], isSelected: selectedPlanID == config.plans[1].id, isFullWidth: false, action: { selectedPlanID = config.plans[1].id })
                    }
                    if let lifetime = config.oneTimeOption {
                        StubProductCardView(plan: lifetime, isSelected: selectedPlanID == lifetime.id, isFullWidth: true, action: { selectedPlanID = lifetime.id })
                    }
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        StubProductCardView(plan: config.plans[0], isSelected: selectedPlanID == config.plans[0].id, isFullWidth: false, action: { selectedPlanID = config.plans[0].id })
                        StubProductCardView(plan: config.plans[1], isSelected: selectedPlanID == config.plans[1].id, isFullWidth: false, action: { selectedPlanID = config.plans[1].id })
                    }
                    if let lifetime = config.oneTimeOption {
                        StubProductCardView(plan: lifetime, isSelected: selectedPlanID == lifetime.id, isFullWidth: true, action: { selectedPlanID = lifetime.id })
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
            purchaseButton
            secondaryActionsRow
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 0 : 24)
        .padding(.top, 16)
        .padding(.bottom, 0)
        .frame(maxWidth: horizontalSizeClass == .regular ? 640 : .infinity)
        .background(bottomBackground)
        .frame(maxWidth: .infinity)
    }
    
    private var purchaseButton: some View {
        Button(action: handleCTAPress) {
            ZStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(config.ctaTitle)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(themeManager.selectedColor)
                    .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.4 : 0), radius: colorScheme == .dark ? 12 : 0, x: 0, y: colorScheme == .dark ? 6 : 0)
            )
            .foregroundColor(.white)
        }
        .disabled(selectedPlanID == nil || isPurchasing)
    }
    
    private var secondaryActionsRow: some View {
        HStack {
            ForEach(config.secondaryActions) { action in
                Button(action: { handleSecondaryAction(action.actionID) }) {
                    Text(action.title)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
                .buttonStyle(.plain)
                
                if action.id != config.secondaryActions.last?.id { Spacer() }
            }
        }
    }
    
    @ViewBuilder
    private var bottomBackground: some View {
        if themeManager.isImmersive {
            if colorScheme == .light {
                Rectangle()
                    .fill(Color(uiColor: .systemBackground))
                    .background(AnyShapeStyle(Color(uiColor: .systemBackground)))
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .background(AnyShapeStyle(.ultraThinMaterial))
                    .ignoresSafeArea()
            }
        } else {
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .background(AnyShapeStyle(Color.clear))
                .ignoresSafeArea()
        }
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary.opacity(0.4))
                .padding(20)
        }
    }
    
    private func handleCTAPress() {
        HapticManager.shared.mediumImpact()
        guard let planID = selectedPlanID else { return }
        
        isPurchasing = true
        Task {
            let success = await subscriptionManager.purchase(planID)
            await MainActor.run { 
                isPurchasing = false 
                if success { dismiss() }
            }
        }
    }
    
    private func handleSecondaryAction(_ actionID: String) {
        if actionID == "restore" {
            isPurchasing = true
            Task { 
                await subscriptionManager.restorePurchases() 
                await MainActor.run { isPurchasing = false }
            }
        }
    }
}

// STUB IMPLEMENTATION COMPONENT TO RUN INDEPENDENTLY OF REAL STOREKIT
struct StubProductCardView: View {
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
            cardContent
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if plan.isRecommended, let badge = plan.badge {
                Text(badge)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.selectedColor)
                    .clipShape(Capsule())
                    .offset(y: -12)
            }
        }
        .padding(.top, isFullWidth ? 0 : 12)
    }
    
    @ViewBuilder
    private var cardContent: some View {
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
        .background(backgroundShape1)
        .background(backgroundShape2)
        .overlay(borderShape)
    }
    
    private var backgroundShape1: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isSelected ? themeManager.selectedColor.opacity(0.12) : Color.primary.opacity(0.02))
    }
    
    @ViewBuilder
    private var backgroundShape2: some View {
        if themeManager.isImmersive {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.05 : 0.6))
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        }
    }
    
    private var borderShape: some View {
        let strokeColor = isSelected ? themeManager.selectedColor.opacity(0.8) : (plan.isRecommended ? themeManager.selectedColor.opacity(0.25) : Color.clear)
        let lineWidth: CGFloat = isSelected ? 2 : (plan.isRecommended ? 1.5 : 0)
        
        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(strokeColor, lineWidth: lineWidth)
    }
    
    private var planTitleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.label)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
    
    private var priceDisplayView: some View {
        VStack(alignment: isFullWidth ? .trailing : .leading, spacing: 4) {
            Text(plan.price)
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(plan.billingFrequency)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
    
    private var indicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? themeManager.selectedColor : Color.secondary.opacity(0.2), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(themeManager.selectedColor)
                    .frame(width: 12, height: 12)
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
                Circle().fill(themeManager.selectedColor.opacity(0.1)).frame(width: 44, height: 44)
                Image(systemName: feature.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(themeManager.selectedColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title).font(.system(.headline, design: .rounded, weight: .bold))
                Text(feature.description).font(.system(.subheadline, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
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
                Circle().fill(themeManager.selectedColor.opacity(colorScheme == .dark ? 0.3 : 0.15)).frame(width: max(geometry.size.width, geometry.size.height) * 0.8).blur(radius: 80).offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.2)
                Circle().fill(themeManager.selectedColor.opacity(colorScheme == .dark ? 0.25 : 0.1)).frame(width: max(geometry.size.width, geometry.size.height) * 0.6).blur(radius: 60).offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}
