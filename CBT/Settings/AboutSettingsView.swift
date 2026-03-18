import SwiftUI
import SwiftData

struct AboutSettingsView: View {
    @State private var showingShareApp = false

    var body: some View {
        SettingsSection(title: "About") {
            versionRow
            
            Button(action: {
                HapticManager.shared.lightImpact()
                showingShareApp = true
            }) {
                SettingsRow(icon: "square.and.arrow.up", iconColor: Theme.primaryColor, title: "Share this App") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingShareApp) {
                #if canImport(UIKit)
                ActivityViewController(items: ["I've been using Cognitive Behavioral Therapy+ to master my mind — check it out!", URL(string: "https://xeo.com/CBT/")!])
                    .presentationDetents([.medium])
                #else
                Text("Sharing via Mac Share menu.")
                #endif
            }
            
            Button(action: {
                openURL("https://apps.apple.com/app/id6755934302-placeholder?action=write-review")
            }) {
                SettingsRow(icon: "star.bubble", iconColor: Theme.primaryColor, title: "Review this App") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                openURL("https://xeo.com/CBT/support.html")
            }) {
                SettingsRow(icon: "questionmark.circle", iconColor: Theme.primaryColor, title: "Help Center") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { 
                openURL("https://xeo.com/CBT/privacy-policy.html") 
            }) {
                SettingsRow(icon: "lock.shield", iconColor: Theme.primaryColor, title: "Privacy Policy") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { 
                openURL("https://xeo.com/CBT/terms.html") 
            }) {
                SettingsRow(icon: "doc.text", iconColor: Theme.primaryColor, title: "Terms of Use") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var versionRow: some View {
        SettingsRow(icon: "info.circle", iconColor: Theme.primaryColor, title: "Version") {
            Text(appVersionLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.secondaryText)
        }
    }

    private var appVersionLabel: String {
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        #if DEBUG
        if let buildVersion, !buildVersion.isEmpty {
            return "\(shortVersion) (\(buildVersion))"
        }
        #endif

        return shortVersion
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            HapticManager.shared.lightImpact()
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

#if canImport(UIKit)
private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
