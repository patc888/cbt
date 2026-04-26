import SwiftUI

struct TimeInfrastructureSettingsView: View {
    var body: some View {
        TimeSettingsSection(
            title: "Infrastructure"
        ) {
            TimeSettingsRow(icon: "externaldrive", iconColor: Theme.primaryAccent, title: "Engine") {
                Text("SwiftData")
                    .timeSettingsValueStyle()
            }
            TimeSettingsRow(icon: "icloud", iconColor: Theme.primaryAccent, title: "Sync") {
                Text("Private iCloud")
                    .timeSettingsValueStyle()
            }
            TimeSettingsRow(icon: "person", iconColor: Theme.primaryAccent, title: "Mode") {
                Text("Single User")
                    .timeSettingsValueStyle()
            }
        }
    }
}
