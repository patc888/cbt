import SwiftUI

struct MoodIntensitySelector: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var intensity: Double
    let selectedColor: MoodColor?
    let onNext: () -> Void
    
    private var accent: Color {
        selectedColor.map { $0.color(with: themeManager.selectedColor) } ?? themeManager.selectedColor
    }

    var body: some View {
        MoodStepScaffold(
            title: "How strong is this feeling?",
            subtitle: "Set the intensity so today's entry captures the signal, not just the label.",
            icon: "dial.medium",
            accent: accent,
            action: onNext
        ) {
            MoodGlassPanel(accent: accent) {
                VStack(spacing: 26) {
                    ZStack {
                        Circle()
                            .stroke(accent.opacity(0.12), lineWidth: 18)
                            .frame(width: 168, height: 168)

                        Circle()
                            .trim(from: 0, to: intensity / 10)
                            .stroke(
                                accent,
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .frame(width: 168, height: 168)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: intensity)

                        VStack(spacing: 2) {
                            Text("\(Int(intensity))")
                                .font(.system(size: 62, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(accent)
                                .contentTransition(.numericText())
                                .animation(.spring(), value: intensity)
                                .accessibilityHidden(true)

                            Text("of 10")
                                .font(DSTypography.caption)
                                .foregroundStyle(DSTheme.secondaryText)
                        }
                    }

                    VStack(spacing: 12) {
                        Slider(value: $intensity, in: 1...10, step: 1) {
                            Text("Intensity")
                        } minimumValueLabel: {
                            Text("1")
                                .font(DSTypography.caption)
                                .foregroundStyle(DSTheme.secondaryText)
                        } maximumValueLabel: {
                            Text("10")
                                .font(DSTypography.caption)
                                .foregroundStyle(DSTheme.secondaryText)
                        }
                        .tint(accent)
                        .accessibilityValue("\(Int(intensity)) out of 10")
                        .onChange(of: Int(intensity)) { _, _ in
                            HapticManager.shared.lightTick()
                        }

                        HStack {
                            Text("Gentle")
                            Spacer()
                            Text("Intense")
                        }
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.tertiaryText)
                    }
                }
            }
        }
    }
}
