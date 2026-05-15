import OSLog
import SwiftUI
import SwiftData

struct SettingsView: View {
    fileprivate static let logger = AppLogger.make(category: "Settings")

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var metrics: LayoutMetrics { LayoutMetrics.metrics(for: horizontalSizeClass) }
    var showsDismissControl: Bool = true
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground().ignoresSafeArea()

            DeferredRenderView {
                VStack(spacing: 12) {
                    TopHeadlineView(
                        title: String(localized: "Settings"),
                        leading: { StreakToolbarButton() }
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)
            } content: {
                SettingsDashboardContent(showsDismissControl: showsDismissControl)
            }

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

private struct SettingsDashboardContent: View {
    let showsDismissControl: Bool
    @State private var viewModel = SettingsViewModel()
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isInitialized {
                    mainContent
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            viewModel.initialize(with: modelContext)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 12) {
            TopHeadlineView(
                title: String(localized: "Settings"),
                leading: { StreakToolbarButton() }
            )
            .padding(.horizontal, 16)
            
            SubscriptionSettingsView()

            AppearanceSettingsView(
                hapticsEnabled: viewModel.hapticsEnabled,
                currentIcon: viewModel.currentIcon,
                userTheme: Bindable(themeManager).appTheme,
                selectedTheme: Bindable(themeManager).selectedTheme,
                isImmersive: Bindable(themeManager).isImmersive,
                onUpdateHaptics: { enabled in
                    viewModel.updateHaptics(enabled)
                },
                onUpdateIcon: { iconName in
                    viewModel.updateIcon(iconName)
                }
            )

            DataSettingsSection()

            SecuritySettingsView(
                appLockEnabled: viewModel.appLockEnabled,
                onUpdateAppLock: { enabled in
                    viewModel.updateAppLock(enabled)
                }
            )

            SettingsSection(title: String(localized: "Tools")) {
                NavigationLink(destination: BreathingResetView()) {
                    SettingsRow(
                        icon: "wind",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Breathing Reset"),
                        subtitle: String(localized: "Guided box breathing session")
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
                        Text(String(localized: "What is CBT"))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text(String(localized: "A quick interactive guide to Cognitive Behavioral Therapy"))
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
                .padding(.top, 16)

            VersionFooterView()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}


struct PrivacyFooter: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                Text(String(localized: "Your Privacy Matters"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(themeManager.selectedColor)
            
            Text(String(localized: "Your entries are private. We never see your data."))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}

private struct VersionFooterView: View {
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.6"
        return "Version \(version)"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(appVersionText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
