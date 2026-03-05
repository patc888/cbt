import SwiftUI

struct DSTheme {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color(.tertiaryLabel)

    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.systemBackground)
    static let elevatedFill = Color(.secondarySystemFill)
    static let separator = Color(.separator)

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
