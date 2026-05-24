import SwiftUI

struct PermissionDeniedView: View {
    let type: PermissionManager.PermissionType
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(themeManager.primaryColor)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    PermissionManager.shared.openSettings()
                }) {
                    Text(String(localized: "Open System Settings"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text(String(localized: "Maybe Later"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .padding()
        .background(ThemedBackground().ignoresSafeArea())
    }
    
    private var iconName: String {
        switch type {
        case .notifications: return "bell.slash.fill"
        case .locationWhenInUse: return "location.slash.fill"
        case .camera: return "camera.fill"
        case .microphone: return "mic.slash.fill"
        }
    }
    
    private var title: String {
        String(localized: "\(type.localizedName) Access Required")
    }
    
    private var message: String {
        switch type {
        case .notifications:
            return String(localized: "Enable notifications to receive the gentle reminders you choose.")
        case .locationWhenInUse:
            return String(localized: "Location access helps us understand how your environment affects your mood.")
        case .camera:
            return String(localized: "Camera access is needed to add photos to your journal entries.")
        case .microphone:
            return String(localized: "Microphone access allows you to record voice journals and affirmations.")
        }
    }
}

#Preview {
    PermissionDeniedView(type: .notifications)
        .environment(ThemeManager())
}
