import SwiftUI

struct DSTheme {
    static var primaryText: Color { AppTokens.Theme.primaryText }
    static var secondaryText: Color { AppTokens.Theme.secondaryText }
    static var tertiaryText: Color { AppTokens.Theme.tertiaryText }
    static var background: Color { AppTokens.Theme.background }
    static var cardBackground: Color { AppTokens.Theme.cardBackground }
    static var elevatedFill: Color { AppTokens.Theme.elevatedFill }
    static var separator: Color { AppTokens.Theme.separator }

    static var success: Color { AppTokens.Theme.success }
    static var warning: Color { AppTokens.Theme.warning }
    static var destructive: Color { AppTokens.Theme.destructive }

    static var cardMaterial: Material { AppTokens.Theme.cardMaterial }
}

extension View {
    func dsSettingsContentWidth() -> some View {
        self.frame(maxWidth: 560) // Consistent max width for iPad/Mac
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
