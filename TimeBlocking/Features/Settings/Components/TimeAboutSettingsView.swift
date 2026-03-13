import SwiftUI

struct TimeAboutSettingsView: View {
    let onReset: () -> Void

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        TimeSettingsSection(title: "About") {
            VStack(alignment: .leading, spacing: 12) {
                TimeSettingsRow(icon: "info.circle", title: "Version") {
                    Text(appVersionDisplay)
                        .timeSettingsValueStyle()
                }
                
                Divider()
                
                Button(action: { openURL("https://xeo.com/TimeBlocking/support") }) {
                    TimeSettingsRow(icon: "questionmark.circle", title: "Help Center") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                
                Button(action: { openURL("https://xeo.com/TimeBlocking/privacy") }) {
                    TimeSettingsRow(icon: "lock.shield", title: "Privacy Policy") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                
                Button(action: {
                    HapticManager.shared.mediumImpact()
                    onReset()
                }) {
                    TimeSettingsRow(icon: "trash", iconColor: Theme.errorRed, title: "Reset All Data", subtitle: "Clear your schedule and preferences") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            HapticManager.shared.lightImpact()
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}
