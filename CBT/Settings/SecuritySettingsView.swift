import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    let settings: UserSettings
    @Namespace private var appLockNamespace
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var showingPrivacyInfo = false
    
    var body: some View {
        SettingsSection(title: "Security") {
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
                .frame(width: 110)
            }
            
            Button(action: {
                HapticManager.shared.lightImpact()
                showingPrivacyInfo = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                    Text("Why your data is private")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(themeManager.selectedColor)
            }
            .buttonStyle(PlainButtonStyle())
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
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.bottom, 8)
                
                TopHeadlineView(title: "Your Data is Private")
                
                Text("We believe your data is personal. This app is designed with privacy at its core.")
                    .font(.system(size: 16, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                PrivacyPoint(icon: "nosign", text: "No trackers or 3rd party analytics")
                PrivacyPoint(icon: "icloud.fill", text: "Securely synced via your private iCloud")
                PrivacyPoint(icon: "lock.fill", text: "Everything stays on your device or in your cloud")
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
                    .background(themeManager.selectedColor)
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
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
    }
}
