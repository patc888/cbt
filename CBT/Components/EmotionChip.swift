import SwiftUI

struct TagChip: View {
    let title: String
    var isSelected: Bool = false
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? themeManager.selectedColor.opacity(0.16) : Theme.toggleBackgroundColor(for: .light))
            .foregroundStyle(isSelected ? themeManager.selectedColor : Theme.primaryText)
            .clipShape(Capsule())
    }
}

// Backward-compatible wrapper for existing call sites.
struct EmotionChip: View {
    let title: String
    var isSelected: Bool = false

    var body: some View {
        TagChip(title: title, isSelected: isSelected)
    }
}
