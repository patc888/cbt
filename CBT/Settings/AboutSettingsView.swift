import SwiftUI
import SwiftData

struct AboutSettingsView: View {
    var body: some View {
        SettingsSection(title: "About") {
            versionRow
            
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
            
            NavigationLink(destination: DataResetOptionsView()) {
                SettingsRow(icon: "trash", iconColor: Theme.errorRed, title: "Reset All Data") {
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
