import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    private static let logger = AppLogger.make(category: "SecuritySettings")

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var securityManager: SecurityManager
    
    let appLockEnabled: Bool
    @Namespace private var appLockNamespace
    @Environment(ThemeManager.self) private var themeManager
    
    let onUpdateAppLock: (Bool) -> Void
    
    @State private var showingPrivacyInfo = false
    
    @AppStorage("autoLockDelay") private var autoLockDelay: String = "Immediately"
    @AppStorage("appLockEnabled") private var appLockEnabledStorage: Bool = false
    @AppStorage("hideAppSwitcher") private var hideAppSwitcher: Bool = false
    
    private let lockOptions = ["Immediately", "1m", "5m"]
    
    var body: some View {
        SettingsSection(title: "Security") {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "faceid",
                    iconColor: themeManager.selectedColor,
                    title: "Lock app with Face ID or passcode",
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
                .presentationDetents([.medium])
                .presentationCornerRadius(Theme.cornerRadiusXLarge)
                .presentationBackground { Theme.secondaryBackground }
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
        guard appLockEnabled || appLockEnabledStorage else { return }

        onUpdateAppLock(false)
        appLockEnabledStorage = false
    }
}

struct PrivacyInfoPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Theme.tertiaryText.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(themeManager.primaryColor)
                    .padding(.bottom, 8)
                
                Text("Your Data is Private")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                
                Text("We believe your data belongs only to you. This app is designed with privacy at its core.")
                    .font(.system(size: 16, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                PrivacyPoint(icon: "nosign", text: "No trackers or 3rd party analytics")
                PrivacyPoint(icon: "internaldrive.fill", text: "Stored locally on this device while sync is unavailable")
                PrivacyPoint(icon: "lock.fill", text: "Face ID or passcode protection is available on device")
                PrivacyPoint(icon: "person.badge.shield.checkmark.fill", text: "We never sell or share your data")
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 20)
            
            Button(action: {
                HapticManager.shared.lightImpact()
                dismiss()
            }) {
                Text("Got it")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.primaryColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}


struct PrivacyPoint: View {
    @Environment(ThemeManager.self) private var themeManager
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(themeManager.primaryColor)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
    }
}
