import SwiftUI

struct PermissionDeniedView: View {
    let type: PermissionManager.PermissionType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FeatureModalPresenter {
            DSFeatureModal(
                systemImage: iconName,
                title: title,
                subtitle: message,
                primaryTitle: String(localized: "Open System Settings"),
                primaryAction: {
                    PermissionManager.shared.openSettings()
                },
                secondaryTitle: String(localized: "Maybe Later"),
                secondaryAction: {
                    HapticManager.shared.lightImpact()
                    dismiss()
                },
                closeAction: {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
            )
        }
        .dsSheetPresentation(detents: [.medium])
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
