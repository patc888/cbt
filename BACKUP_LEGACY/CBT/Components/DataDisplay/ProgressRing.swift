import SwiftUI

struct ProgressRing<CenterContent: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let accentColor: Color?
    @ViewBuilder let centerContent: () -> CenterContent

    init(
        progress: Double,
        lineWidth: CGFloat = 14,
        accentColor: Color? = nil,
        @ViewBuilder centerContent: @escaping () -> CenterContent
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.accentColor = accentColor
        self.centerContent = centerContent
    }

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth)
                )

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    accentColor ?? .accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: clampedProgress)

            centerContent()
        }
    }
}
