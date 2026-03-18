import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    let settings: UserSettings
    @Namespace private var appLockNamespace
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var showingPrivacyInfo = false
    
    @AppStorage("autoLockDelay") private var autoLockDelay: String = "Immediately"
    @AppStorage("hideAppSwitcher") private var hideAppSwitcher: Bool = false
    
    private let lockOptions = ["Immediately", "1m", "5m"]
    
    var body: some View {
        SettingsSection(title: "Security") {
            VStack(spacing: 0) {
                SettingsRow(icon: "faceid", iconColor: themeManager.selectedColor, title: "Lock app with Face ID or passcode") {
                    SegmentedToggle(
                        isOn: Binding(
                            get: { settings.appLockEnabled ?? false },
                            set: { newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.appLockEnabled = newValue
                                    try? modelContext.save()
                                }
                            }
                        ),
                        namespace: appLockNamespace
                    )
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
                PrivacyPoint(icon: "icloud.fill", text: "Securely synced via your private iCloud")
                PrivacyPoint(icon: "lock.fill", text: "Everything stays on your device")
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
