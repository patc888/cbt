import SwiftUI

struct ThemeToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appThemeImmersive") private var isImmersive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            Capsule()
                .fill(backgroundColor(isOn: configuration.isOn))
                .frame(width: 51, height: 27)
                .overlay(
                    Circle()
                        .fill(.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 12 : -12)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0), radius: colorScheme == .dark ? 1 : 0, x: 0, y: colorScheme == .dark ? 1 : 0)
                )
                .onTapGesture {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }

    private func backgroundColor(isOn: Bool) -> Color {
        if isOn {
            return Theme.primaryColor
        }
        if colorScheme == .dark && !isImmersive {
            return Color(uiColor: .lightGray)
        }
        return Color(uiColor: .tertiarySystemFill)
    }
}
