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
            VStack(spacing: 12) {
                AppIconView(size: 80)

                VStack(spacing: 4) {
                    Text("TimeBlocking")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Design your day, master your time.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            TimeSettingsSection(title: "Support") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { openExternalURL("https://xeo.com/TimeBlocking/support") }) {
                        TimeSettingsRow(icon: "questionmark.circle", title: "Help Center") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()

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

            TimeSettingsSection(title: "Spread the Word") {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { openExternalURL("itms-apps://itunes.apple.com/app/id6759693729?action=write-review") }) {
                        TimeSettingsRow(icon: "star", title: "Rate on App Store") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()

                    ShareLink(item: URL(string: "https://apps.apple.com/app/id6759693729")!) {
                        TimeSettingsRow(icon: "square.and.arrow.up", title: "Share TimeBlocking") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            TimeSettingsSection(title: "Data Management") {
                VStack(alignment: .leading, spacing: 12) {
                    TimeSettingsRow(icon: "info.circle", title: "Version") {
                        Text(appVersionDisplay)
                            .timeSettingsValueStyle()
                    }

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
    }

    private func openExternalURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        HapticManager.shared.lightImpact()
        openURL(url)
    }
}
