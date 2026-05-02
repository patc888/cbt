import SwiftUI

public struct LayoutMetrics {
    public let contentMaxWidth: CGFloat
    public let horizontalPadding: CGFloat
    public let cardCornerRadius: CGFloat
    public let cardSpacing: CGFloat
    
    public static let floatingToolbarBottomInset: CGFloat = 110
    
    public init(contentMaxWidth: CGFloat, horizontalPadding: CGFloat, cardCornerRadius: CGFloat, cardSpacing: CGFloat) {
        self.contentMaxWidth = contentMaxWidth
        self.horizontalPadding = horizontalPadding
        self.cardCornerRadius = cardCornerRadius
        self.cardSpacing = cardSpacing
    }
    
    public func gridColumnCount(for sizeClass: UserInterfaceSizeClass?) -> Int {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return 1
        #else
        return 1 // Single column for all iOS/iPadOS size classes
        #endif
    }
    
    public static func metrics(for sizeClass: UserInterfaceSizeClass?) -> LayoutMetrics {
        let isCompact = sizeClass == .compact
        
        return LayoutMetrics(
            contentMaxWidth: 720,
            horizontalPadding: isCompact ? 16 : 32,
            cardCornerRadius: isCompact ? Theme.cornerRadiusMedium : Theme.cornerRadiusXLarge,
            cardSpacing: isCompact ? Theme.paddingMedium : Theme.paddingLarge
        )
    }
}
