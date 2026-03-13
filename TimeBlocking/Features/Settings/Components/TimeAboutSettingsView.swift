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
            TimeSettingsRow(icon: "info.circle", iconColor: Theme.primaryPurple, title: "Version") {
                Text(appVersionDisplay)
                    .timeSettingsValueStyle()
            }

            Divider()
                .padding(.vertical, 4)

            TimeSettingsRow(
                icon: "checkmark.seal",
                iconColor: Theme.primaryPurple,
                title: "V1 Focus",
                subtitle: "Scheduling, templates, reminders, and widgets"
            )

            Button(role: .destructive, action: onReset) {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Data")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }
            .padding(.top, 4)
        }
    }
}
