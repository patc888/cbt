import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

struct JSONExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        self.fileURL = URL(fileURLWithPath: "/")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: fileURL)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct DataSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DataSettingsSection()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Data")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct DataSettingsSection: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showICloudInfo = false

    private var syncStatus: CloudSyncMonitor.SyncStatus {
        CloudSyncMonitor.shared.status
    }

    private var needsICloudSetup: Bool {
        syncStatus == .noAccount || syncStatus == .disabled
    }

    private var syncSubtitle: String? {
        syncStatus == .synced ? nil : String(localized: "iPhone, iPad, and Mac sync. Backs up your data and stays private to you.")
    }

    var body: some View {
        SettingsSection(title: "Data") {
            SettingsRow(
                icon: "icloud.fill",
                iconColor: themeManager.primaryColor,
                title: needsICloudSetup ? String(localized: "iCloud Sync (Off)") : String(localized: "iCloud Sync"),
                subtitle: syncSubtitle
            ) {
                HStack(spacing: 12) {
                    if needsICloudSetup {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showICloudInfo.toggle()
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(themeManager.primaryColor)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: syncStatus == .synced ? "checkmark.icloud.fill" : (needsICloudSetup ? "icloud.slash" : syncStatus.iconName))
                        .font(.system(size: syncStatus == .synced ? 20 : 16, weight: .semibold))
                        .foregroundStyle(syncStatus == .synced ? Theme.successGreen : (needsICloudSetup ? Theme.errorRed : syncStatus.color))
                }
            }

            if needsICloudSetup && showICloudInfo {
                ICloudSyncSignInReminder()
                    .padding(.top, 4)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }

            Divider()
                .padding(.vertical, 8)

            NavigationLink(destination: DataExportView()) {
                SettingsRow(
                    icon: "square.and.arrow.up.fill",
                    iconColor: themeManager.primaryColor,
                    title: "Export Data",
                    subtitle: "Portability and backups"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            NavigationLink(destination: AdvancedDataSettingsView()) {
                SettingsRow(
                    icon: "gearshape.2.fill",
                    iconColor: themeManager.primaryColor,
                    title: "Advanced Data",
                    subtitle: "Exports and data management"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct ICloudSyncSignInReminder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "To enable sync, sign in to iCloud and allow CBT to use iCloud Drive."))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                instructionRow(String(localized: "Open the system Settings app."))
                instructionRow(String(localized: "Sign in to your Apple ID."))
                instructionRow(String(localized: "Turn on iCloud Drive for CBT."))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.successGreen)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
