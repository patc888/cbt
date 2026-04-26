import SwiftUI

struct TimeInfrastructureSettingsView: View {
    var body: some View {
        TimeSettingsSection(title: "Infrastructure") {
            TimeSettingsRow(icon: "externaldrive", iconColor: Theme.primaryAccent, title: "Engine", subtitle: "Persistence layer") {
                Text("SwiftData")
                    .timeSettingsValueStyle()
            }
            TimeSettingsRow(icon: "icloud", iconColor: Theme.primaryAccent, title: "Sync", subtitle: "Cloud-backed direction") {
                Text("Private iCloud")
                    .timeSettingsValueStyle()
            }
            TimeSettingsRow(icon: "person", iconColor: Theme.primaryAccent, title: "Mode", subtitle: "App session model") {
                Text("Single User")
                    .timeSettingsValueStyle()
            }
        }
    }
}
