import SwiftUI
import SwiftData

struct AboutSettingsView: View {
    #if DEBUG
    @State private var showingDebugPlaceholder = false
    #endif

    var body: some View {
        SettingsSection(title: "About") {
            versionRow
            
            Button(action: {
                HapticManager.shared.lightImpact()
                openURL("https://xeo.com/CBT/support.html")
            }) {
                SettingsRow(icon: "questionmark.circle", iconColor: Theme.primaryColor, title: "Help Center") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { HapticManager.shared.lightImpact(); openURL("https://xeo.com/CBT/privacy-policy.html") }) {
                SettingsRow(icon: "lock.shield", iconColor: Theme.primaryColor, title: "Privacy Policy") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { HapticManager.shared.lightImpact(); openURL("https://xeo.com/CBT/terms.html") }) {
                SettingsRow(icon: "doc.text", iconColor: Theme.primaryColor, title: "Terms of Use") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        #if DEBUG
        .sheet(isPresented: $showingDebugPlaceholder) {
            NavigationStack {
                Text("Debug Placeholder (Chores debug views were stripped)")
                    .navigationTitle("Debug")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
        #endif
    }

    @ViewBuilder
    private var versionRow: some View {
        #if DEBUG
        SettingsRow(icon: "info.circle", iconColor: Theme.primaryColor, title: "Version") {
            Text(appVersionLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.secondaryText)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 3) {
            HapticManager.shared.lightImpact()
            showingDebugPlaceholder = true
        }
        #else
        SettingsRow(icon: "info.circle", iconColor: Theme.primaryColor, title: "Version") {
            Text(appVersionLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.secondaryText)
        }
        #endif
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
            if let nsURL = URL(string: url.absoluteString) {
                NSWorkspace.shared.open(nsURL)
            }
            #endif
        }
    }
}
