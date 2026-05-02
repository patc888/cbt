import SwiftUI

struct TimeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TimeScaleButtonStyle {
    static var timeScale: TimeScaleButtonStyle {
        TimeScaleButtonStyle()
    }
}
