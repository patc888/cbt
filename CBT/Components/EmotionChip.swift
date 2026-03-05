import SwiftUI

struct TagChip: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.toggleBackgroundColor(for: .light)) // Or a dedicated card color
            .foregroundStyle(Theme.primaryText)
            .clipShape(Capsule())
    }
}

// Backward-compatible wrapper for existing call sites.
struct EmotionChip: View {
    let title: String

    var body: some View {
        TagChip(title: title)
    }
}
