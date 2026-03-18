import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var settings: [UserSettings]
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var metrics: LayoutMetrics { LayoutMetrics.metrics(for: horizontalSizeClass) }
    
    @State private var showingSubscription = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var userSettings: UserSettings? { settings.first }
    var showsDismissControl: Bool = true
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mainContent
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            if showsDismissControl {
                navigationArrow
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
        }
#if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
#endif

        .task {
            if settings.isEmpty {
                let newSettings = UserSettings()
                modelContext.insert(newSettings)
                try? modelContext.save()
            }
            
            let enabled = userSettings?.hapticsEnabled ?? true
            HapticManager.shared.setEnabled(enabled)
            await subscriptionManager.loadProducts()
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
        .onChange(of: userSettings?.hapticsEnabled ?? true) { _, enabled in
            HapticManager.shared.setEnabled(enabled)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            // Removed manual padding since VStack has spacing now
            

            
            SubscriptionSettingsView(
                subscriptionManager: subscriptionManager,
                showingSubscription: $showingSubscription
            )
            
            AppearanceSettingsView(
                userTheme: Bindable(themeManager).appTheme,
                selectedTheme: Bindable(themeManager).selectedTheme,
                isImmersive: Bindable(themeManager).isImmersive,
                hapticsEnabled: Binding(
                    get: { userSettings?.hapticsEnabled ?? true },
                    set: {
                        userSettings?.hapticsEnabled = $0
                        HapticManager.shared.setEnabled($0)
                        try? modelContext.save()
                    }
                ),
                currentIcon: Binding(
                    get: { userSettings?.currentIcon },
                    set: { userSettings?.currentIcon = $0; try? modelContext.save() }
                )
            )
            
            DataSettingsSection()


            if let settings = userSettings {
                SecuritySettingsView(settings: settings)

            }

            SettingsSection(title: "Tools") {
                NavigationLink(destination: BreathingResetView()) {
                    SettingsRow(
                        icon: "wind",
                        iconColor: themeManager.selectedColor,
                        title: "Breathing Reset",
                        subtitle: "Guided box breathing session"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }

            RemindersSettingsSection()
            
            NavigationLink(destination: WhatIsCBTPagerView()) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What is CBT")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text("A quick interactive guide to Cognitive Behavioral Therapy")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                .background(themeManager.selectedColor)
                .cornerRadius(Theme.cornerRadiusMedium)
            }
            .buttonStyle(.plain)
            
            AboutSettingsView()
            
            PrivacyFooter()
                .padding(.top, 16) // Combined with 16 spacing = 32 total
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var navigationArrow: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            dismiss()
        }) {
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .padding(8)
                .contentShape(Rectangle())
        }
        .padding(.trailing, 20)
        .padding(.top, 12)
    }
}

struct PrivacyFooter: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                Text("Your Privacy Matters")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(themeManager.selectedColor)
            
            Text("Your entries are private. We never see your data.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}


