import SwiftUI

struct TimeAboutSettingsView: View {
    let onResetRequested: () -> Void
    
    var body: some View {
        TimeSettingsSection(
            title: "About"
        ) {
            Button(action: { 
                HapticManager.shared.lightImpact()
                openURL("https://xeo.com/TimeBlocking/support.html") 
            }) {
                TimeSettingsRow(icon: "questionmark.circle", iconColor: Theme.primaryAccent, title: "Help Center") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                HapticManager.shared.lightImpact()
                // Legal info logic
            }) {
                TimeSettingsRow(icon: "doc.text.magnifyingglass", iconColor: Theme.primaryAccent, title: "Legal & Info") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(role: .destructive) {
                HapticManager.shared.warning()
                onResetRequested()
            } label: {
                TimeSettingsRow(
                    icon: "trash",
                    iconColor: .red,
                    title: "Reset all data"
                ) {
                    EmptyView()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @Environment(\.openURL) private var openURLAction

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            openURLAction(url)
        }
    }
}
