import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    private static let logger = AppLogger.make(category: "SecuritySettings")

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var securityManager: SecurityManager
    
    let appLockEnabled: Bool
    let discreetModeEnabled: Bool
    @Namespace private var appLockNamespace
    @Namespace private var discreetModeNamespace
    @Environment(ThemeManager.self) private var themeManager
    
    let onUpdateAppLock: (Bool) -> Void
    let onUpdateDiscreetMode: (Bool) -> Void
    
    @State private var showingPrivacyInfo = false
    
    @AppStorage("autoLockDelay") private var autoLockDelay: String = "Immediately"
    @AppStorage("hideAppSwitcher") private var hideAppSwitcher: Bool = false
    
    private let lockOptions = ["Immediately", "1m", "5m"]
    
    var body: some View {
        SettingsSection(title: "Security") {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "lock.shield",
                    iconColor: themeManager.selectedColor,
                    title: "Lock with Face ID or passcode",
                    subtitle: appLockSubtitle
                ) {
                    SegmentedToggle(
                        isOn: Binding(
                            get: { appLockEnabled },
                            set: { onUpdateAppLock($0) }
                        ),
                        namespace: appLockNamespace
                    )
                    .disabled(!securityManager.isAppLockAvailable)
                    .opacity(securityManager.isAppLockAvailable ? 1 : 0.55)
                }

                SettingsRow(
                    icon: "eye.slash.fill",
                    iconColor: themeManager.selectedColor,
                    title: "Discreet Mode",
                    subtitle: "Use neutral notification text, widget labels, and CBT wording outside the app."
                ) {
                    SegmentedToggle(
                        isOn: Binding(
                            get: { discreetModeEnabled },
                            set: { onUpdateDiscreetMode($0) }
                        ),
                        namespace: discreetModeNamespace
                    )
                }
                .padding(.top, 12)
                
                Button(action: {
                    HapticManager.shared.lightImpact()
                    showingPrivacyInfo = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                        Text("Why your data is private")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.top, 12)
                    .padding(.leading, 32) // Align with text
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingPrivacyInfo) {
            PrivacyInfoPopup()
                .dsSheetPresentation(detents: [.medium])
        }
        .onAppear {
            securityManager.checkBiometrics()
            disableUnsupportedAppLockIfNeeded()
        }
        .onChange(of: securityManager.isAppLockAvailable) { _, _ in
            disableUnsupportedAppLockIfNeeded()
        }
    }

    private var appLockSubtitle: String? {
        securityManager.isAppLockAvailable ? nil : securityManager.appLockAvailabilityMessage
    }

    private func disableUnsupportedAppLockIfNeeded() {
        guard !securityManager.isAppLockAvailable else { return }
        guard appLockEnabled else { return }

        onUpdateAppLock(false)
    }
}

struct PrivacyInfoPopup: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        FeatureModalPresenter {
            DSFeatureModal(
                systemImage: "hand.raised.shield.fill",
                title: "Your Data is Private",
                subtitle: "We believe your data belongs only to you. This app is designed with privacy at its core.",
                bullets: [
                    DSBullet(icon: "nosign", text: "No trackers or 3rd party analytics"),
                    DSBullet(icon: "internaldrive.fill", text: "Stored locally on this device while sync is unavailable"),
                    DSBullet(icon: "lock.fill", text: "Device-level security helps protect local data"),
                    DSBullet(icon: "person.badge.shield.checkmark.fill", text: "We never sell or share your data")
                ],
                primaryTitle: "Got it",
                primaryAction: {
                    HapticManager.shared.lightImpact()
                    dismiss()
                },
                closeAction: {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
            )
        }
    }
}
