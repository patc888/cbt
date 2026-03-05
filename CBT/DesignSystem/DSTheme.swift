import SwiftUI

struct DSTheme {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary
    static let background = Color.secondary.opacity(0.1)
    static let cardBackground = Color.primary.opacity(0.05)
    static let elevatedFill = Color.primary.opacity(0.1)
    static let separator = Color.secondary.opacity(0.2)

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
