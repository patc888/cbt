import os
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.xeo.timeblocking", category: "TimeSecuritySettingsView")

struct TimeSecuritySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    let preferences: AppPreferences?
    @Namespace private var appLockNamespace
    
    @State private var showingPrivacyInfo = false
    
    var body: some View {
        TimeSettingsSection(
            title: "Security"
        ) {
            VStack(spacing: 0) {
                TimeSettingsRow(icon: "faceid", iconColor: Theme.primaryAccent, title: "Lock app with Face ID or passcode") {
                    SegmentedToggle(
                        isOn: Binding(
                            get: { preferences?.appLockEnabled ?? false },
                            set: { newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if let preferences = preferences {
                                        preferences.appLockEnabled = newValue
                                        do {
                                            try modelContext.save()
                                        } catch {
                                            logger.error("Failed to save app lock setting: \(error)")
                                        }
                                        HapticManager.shared.lightImpact()
                                    }
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
                        Text("Why your schedule data is private")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(.top, 12)
                    .padding(.leading, 32) // Align with text
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingPrivacyInfo) {
            TimePrivacyInfoPopup()
                .presentationDetents([.medium])
                .presentationCornerRadius(Theme.cornerRadiusXLarge)
                .presentationBackground { 
                    Theme.backgroundColor
                        .overlay(.ultraThinMaterial)
                }
        }
    }
}

struct TimePrivacyInfoPopup: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Theme.secondaryText.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(.bottom, 8)
                
                TimeTopHeadlineView(title: "Your Data is Private")
                
                Text("We believe your schedule and focus data is personal. This app is designed with privacy at its core.")
                    .font(.system(size: 16, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                TimePrivacyPoint(icon: "nosign", text: "No trackers or 3rd party analytics")
                TimePrivacyPoint(icon: "icloud.fill", text: "Securely synced via your private iCloud")
                TimePrivacyPoint(icon: "lock.fill", text: "Everything stays on your device")
                TimePrivacyPoint(icon: "person.badge.shield.checkmark.fill", text: "We never sell or share your data")
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
                    .background(Theme.primaryAccent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

struct TimePrivacyPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.primaryAccent)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
    }
}
