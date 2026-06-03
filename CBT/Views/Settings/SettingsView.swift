import OSLog
import StoreKit
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

            SettingsSection(title: String(localized: "Trust Center")) {
                NavigationLink(destination: PrivacySafetySettingsView()) {
                    SettingsRow(
                        icon: "hand.raised.shield.fill",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Privacy & Safety"),
                        subtitle: String(localized: "App lock, sync, export, delete/reset, and crisis resources")
                    ) {
                        SettingsDisclosureIndicator()
                    }
                }
                .buttonStyle(.plain)
            }

            AppearanceSettingsView(
                hapticsEnabled: viewModel.hapticsEnabled,
                currentIcon: viewModel.currentIcon,
                tonePreference: viewModel.tonePreference,
                userTheme: Bindable(themeManager).appTheme,
                selectedTheme: Bindable(themeManager).selectedTheme,
                isImmersive: Bindable(themeManager).isImmersive,
                onUpdateHaptics: { enabled in
                    viewModel.updateHaptics(enabled)
                },
                onUpdateIcon: { iconName in
                    viewModel.updateIcon(iconName)
                },
                onUpdateTonePreference: { preference in
                    viewModel.updateTonePreference(preference)
                }
            )

            SettingsSection(title: String(localized: "Daily Plan")) {
                ToggleRow(
                    icon: "heart.text.square.fill",
                    iconColor: themeManager.selectedColor,
                    title: String(localized: "Comfort Mode"),
                    subtitle: String(localized: "Show 1-2 tiny actions, soften plan language, and keep breathing, grounding, and safety support close."),
                    isOn: Binding(
                        get: { viewModel.comfortModeEnabled },
                        set: { viewModel.updateComfortMode($0) }
                    )
                )
            }

            SettingsSection(title: String(localized: "Tools")) {
                NavigationLink(destination: SafetyPlanView()) {
                    SettingsRow(
                        icon: "cross.case.fill",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Rough Patch Plan & Crisis Support"),
                        subtitle: String(localized: "Not medical care; open support steps and crisis options")
                    ) {
                        SettingsDisclosureIndicator()
                    }
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.optInToFirstSevenDays()
                } label: {
                    SettingsRow(
                        icon: "sparkles",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "First 7 Days Journey"),
                        subtitle: viewModel.journeyOptInMessage ?? String(localized: "Start a gentle local starter plan")
                    ) {
                        SettingsDisclosureIndicator()
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(destination: BreathingResetView()) {
                    SettingsRow(
                        icon: "wind",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Breathing Reset"),
                        subtitle: String(localized: "Guided box breathing session")
                    ) {
                        SettingsDisclosureIndicator()
                    }
                }
                .buttonStyle(.plain)

            }

            RemindersSettingsSection()

            SessionBoundariesSettingsSection()

            NavigationLink(destination: WhatIsCBTPagerView()) {
                WhatIsCBTSettingsCard()
            }
            .buttonStyle(.plain)

            ShareFeedbackSettingsView()

            AboutSettingsView()

            PrivacyFooter()
                .padding(.top, 16)

            VersionFooterView()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

private struct SessionBoundariesSettingsSection: View {
    @Environment(ThemeManager.self) private var themeManager

    @AppStorage(SessionBoundaryPreferences.enabledKey) private var gentleStopEnabled = false
    @AppStorage(SessionBoundaryPreferences.minutesKey) private var gentleStopMinutes = SessionBoundaryPreferences.defaultMinutes

    var body: some View {
        SettingsSection(title: String(localized: "Session Boundaries")) {
            VStack(spacing: 16) {
                ToggleRow(
                    icon: "timer",
                    iconColor: themeManager.selectedColor,
                    title: String(localized: "Gentle Stop"),
                    subtitle: gentleStopEnabled
                        ? String(localized: "Pause longer CBT sessions before they turn into rumination")
                        : String(localized: "Off until you choose a session boundary"),
                    isOn: $gentleStopEnabled
                )

                if gentleStopEnabled {
                    SettingsRow(
                        icon: "hourglass",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Maximum Session Length"),
                        subtitle: String(localized: "When reached, offer save and close, breathing, or continue")
                    ) {
                        Picker(String(localized: "Maximum Session Length"), selection: $gentleStopMinutes) {
                            ForEach(SessionBoundaryPreferences.minuteOptions, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onAppear {
                            if !SessionBoundaryPreferences.minuteOptions.contains(gentleStopMinutes) {
                                gentleStopMinutes = SessionBoundaryPreferences.defaultMinutes
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct WhatIsCBTSettingsCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                #if canImport(UIKit)
                .fill(Color(UIColor.systemBackground))
                #elseif canImport(AppKit)
                .fill(Color(nsColor: .windowBackgroundColor))
                #else
                .fill(Color.black)
                #endif
                .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.22), radius: 18, x: 0, y: 10)

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

                pillLayout
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var pillLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                CBTCardPill(icon: "hand.tap.fill", text: "Tap through")
                CBTCardPill(icon: "chart.dots.scatter", text: "See patterns")
                CBTCardPill(icon: "checkmark.seal.fill", text: "Practice")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CBTCardPill(icon: "hand.tap.fill", text: "Tap through")
                    CBTCardPill(icon: "chart.dots.scatter", text: "See patterns")
                }

                CBTCardPill(icon: "checkmark.seal.fill", text: "Practice")
            }

            VStack(alignment: .leading, spacing: 8) {
                CBTCardPill(icon: "hand.tap.fill", text: "Tap through")
                CBTCardPill(icon: "chart.dots.scatter", text: "See patterns")
                CBTCardPill(icon: "checkmark.seal.fill", text: "Practice")
            }
        }
    }
}

private struct CBTCardPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.white.opacity(0.16))
            .clipShape(Capsule())
    }
}

private struct ShareFeedbackSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager

    private let appShareURL = URL(string: "https://apps.apple.com/us/app/cognitive-behavioral-therapy/id6760043548")
    private let shareMessage = String(localized: "I have been using CBT for private mood tracking, thought records, and guided self-help tools.")

    var body: some View {
        SettingsSection(title: String(localized: "Share")) {
            if let appShareURL {
                ShareLink(
                    item: appShareURL,
                    subject: Text(String(localized: "CBT")),
                    message: Text(shareMessage)
                ) {
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Share App")
                    ) {
                        SettingsDisclosureIndicator()
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                HapticManager.shared.lightImpact()
                if let url = URL(string: "itms-apps://apps.apple.com/app/id6760043548?action=write-review") {
                    openURL(url)
                }
            } label: {
                SettingsRow(
                    icon: "star.bubble",
                    iconColor: themeManager.selectedColor,
                    title: String(localized: "Write a Review")
                ) {
                    SettingsDisclosureIndicator()
                }
            }
            .buttonStyle(.plain)
        }
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
            
            Text(String(localized: "Your entries are private. Retention analytics stay local on your device, do not include entry content, and are never sent to us."))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}

private struct VersionFooterView: View {
    private var appVersionText: String {
        return "2.0.0"
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
