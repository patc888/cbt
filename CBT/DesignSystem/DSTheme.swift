import SwiftUI

struct DSTheme {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary
    #if canImport(UIKit)
    static let background = Color(UIColor.secondarySystemBackground)
    static let cardBackground = Color(UIColor.systemBackground)
    static let elevatedFill = Color(UIColor.tertiarySystemFill)
    #elseif canImport(AppKit)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let elevatedFill = Color(nsColor: .quaternaryLabelColor).opacity(0.14)
    #else
    static let background = Color.secondary.opacity(0.1)
    static let cardBackground = Color.primary.opacity(0.05)
    static let elevatedFill = Color.primary.opacity(0.1)
    #endif
    static let separator = Color.secondary.opacity(0.16)

    static let success = Color.green
    static let warning = Color.orange
    static let destructive = Color.red

    static let cardMaterial: Material = .regularMaterial
}

extension View {
    func dsSettingsContentWidth() -> some View {
        self.frame(maxWidth: 560) // Consistent max width for iPad/Mac
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
