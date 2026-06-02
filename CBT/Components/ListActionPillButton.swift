import SwiftUI

struct ListActionPillButton: View {
    let title: String
    let color: Color
    var font: Font = .system(size: 13, weight: .bold, design: .rounded)
    var hapticType: HapticType = .light
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .lineLimit(2)
                .font(font)
        }
        .buttonStyle(
            DSButtonStyle(
                variant: .secondary,
                size: .compact,
                expands: false,
                tint: color,
                hapticType: hapticType
            )
        )
    }
}
