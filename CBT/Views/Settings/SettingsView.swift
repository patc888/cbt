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
    var showsDismissControl: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ThemedBackground().ignoresSafeArea()

                DeferredRenderView {
                    Spacer()
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
            .navigationTitle("")
#if os(iOS)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .hideNavigationBar()
        }
        .toggleStyle(ThemeToggleStyle())
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
            AppScreenHeadline(title: String(localized: "Settings"))
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
                WhatIsCBTSettingsCard()
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

private struct WhatIsCBTSettingsCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor,
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.55 : 0.70),
                            Color.cyan.opacity(colorScheme == .dark ? 0.38 : 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "brain.head.profile")
                .font(.system(size: 86, weight: .semibold))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 18, y: -8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.92))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "What is CBT?"))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(String(localized: "Interactive guide with the triangle, thought records, evidence checks, and practical next steps."))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                HStack(spacing: 8) {
                    CBTCardPill(icon: "hand.tap.fill", text: "Tap through")
                    CBTCardPill(icon: "chart.dots.scatter", text: "See patterns")
                    CBTCardPill(icon: "checkmark.seal.fill", text: "Practice")
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.22), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }
}

private struct CBTCardPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.white.opacity(0.16))
            .clipShape(Capsule())
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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.7"
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
