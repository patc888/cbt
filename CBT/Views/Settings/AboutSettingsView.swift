import SwiftUI
import SwiftData

struct AboutSettingsView: View {
    @State private var showingLegalInfo = false
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        SettingsSection(title: String(localized: "About")) {
            Button(action: {
                openURL("https://xeo.com/CBT/support.html")
            }) {
                SettingsRow(icon: "questionmark.circle", iconColor: themeManager.selectedColor, title: String(localized: "Help Center")) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                HapticManager.shared.lightImpact()
                showingLegalInfo = true
            }) {
                SettingsRow(icon: "doc.text.magnifyingglass", iconColor: themeManager.selectedColor, title: String(localized: "Legal & Info")) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: DataResetOptionsView()) {
                HStack {
                    Image(systemName: "trash")
                    Text(String(localized: "Reset Device Data"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.errorRed)
            }
            .padding(.top, 4)
            .buttonStyle(PlainButtonStyle())

            Divider()
                .padding(.leading, 16)

            NavigationLink(destination: DataResetOptionsView()) {
                HStack {
                    Image(systemName: "person.badge.minus")
                    Text(String(localized: "Delete Account & Data"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.errorRed)
            }
            .padding(.top, 4)
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingLegalInfo) {
            LegalView()
        }
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
