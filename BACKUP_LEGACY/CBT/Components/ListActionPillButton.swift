import SwiftUI

struct ListActionPillButton: View {
    let title: String
    let color: Color
    var font: Font = .system(size: 13, weight: .bold, design: .rounded)
    var hapticType: HapticType = .light
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            HapticManager.shared.trigger(hapticType)
            action()
        } label: {
            Text(title)
                .font(font)
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.cardBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.05 : 0), radius: colorScheme == .dark ? 2 : 0)
        }
        .buttonStyle(.plain)
    }
}
