import SwiftUI

struct TimeAboutSettingsView: View {
    @Environment(\.openURL) private var openURL

    let onReset: () -> Void

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            // Brand Header
            VStack(spacing: 16) {
                AppIconView(size: 88)
                    .adaptiveShadow(color: Theme.primaryAccent.opacity(0.3), radius: 12, x: 0, y: 6)

                VStack(spacing: 6) {
                    Text("TimeBlocking")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Design your day, master your time.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            TimeSettingsSection(
                title: "Support"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { openExternalURL("https://xeo.com/TimeBlocking/support") }) {
                        TimeSettingsRow(icon: "questionmark.circle", title: "Help Center") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { openExternalURL("https://xeo.com/TimeBlocking/privacy") }) {
                        TimeSettingsRow(icon: "lock.shield", title: "Privacy Policy") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }


            TimeSettingsSection(
                title: "Data Management"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    TimeSettingsRow(icon: "info.circle", title: "Version") {
                        Text(appVersionDisplay)
                            .timeSettingsValueStyle()
                    }

                    Button(action: {
                        HapticManager.shared.mediumImpact()
                        onReset()
                    }) {
                        TimeSettingsRow(icon: "trash", iconColor: Theme.errorRed, title: "Reset All Data") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openExternalURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        HapticManager.shared.lightImpact()
        openURL(url)
    }
}
