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

    var body: some View {
        SettingsSection(title: "Data") {
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
