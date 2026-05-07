import SwiftUI

struct TimeAboutSettingsView: View {
    let onResetRequested: () -> Void
    
    @State private var showingShareApp = false
    @Environment(\.openURL) private var openURLAction
    
    var body: some View {
        TimeSettingsSection(
            title: "About"
        ) {
            Button(action: { 
                HapticManager.shared.lightImpact()
                openURL("https://melichan.com/TimeBlocking/support.html") 
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

            Button {
                HapticManager.shared.lightImpact()
                showingShareApp = true
            } label: {
                TimeSettingsRow(icon: "square.and.arrow.up", iconColor: Theme.primaryAccent, title: "Share this App") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                HapticManager.shared.lightImpact()
                openURL("https://apps.apple.com/app/id6760246021?action=write-review")
            } label: {
                TimeSettingsRow(icon: "star.bubble", iconColor: Theme.primaryAccent, title: "Review this App") {
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
        .sheet(isPresented: $showingShareApp) {
            TimeShareAppView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            openURLAction(url)
        }
    }
}
