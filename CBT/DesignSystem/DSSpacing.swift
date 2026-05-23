import SwiftUI

enum DSSpacing {
    static var xSmall: CGFloat { AppTokens.Spacing.xs }
    static var small: CGFloat { AppTokens.Spacing.sm }
    static var medium: CGFloat { AppTokens.Spacing.md }
    static var large: CGFloat { AppTokens.Spacing.lg }
    static var xLarge: CGFloat { AppTokens.Spacing.xl }
    static var xxLarge: CGFloat { AppTokens.Spacing.xxl }
}

enum DSCornerRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}
