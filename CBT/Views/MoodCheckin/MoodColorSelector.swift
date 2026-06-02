import SwiftUI

struct MoodColorSelector: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedColor: MoodColor?
    let onNext: () -> Void
    
    var body: some View {
        MoodStepScaffold(
            title: "How are you feeling right now?",
            subtitle: "Choose the face that feels closest. You can refine the strength next.",
            icon: "face.smiling",
            accent: selectedColor?.color(with: themeManager.selectedColor) ?? themeManager.selectedColor,
            isActionEnabled: selectedColor != nil,
            action: onNext
        ) {
            MoodGlassPanel(accent: selectedColor?.color(with: themeManager.selectedColor) ?? themeManager.selectedColor) {
                VStack(spacing: 22) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                        ForEach(MoodColor.allCases.reversed(), id: \.self) { mood in
                            MoodCircleButton(mood: mood, isSelected: selectedColor == mood) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedColor = mood
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                        Text(selectedColor?.label ?? "Pick a mood")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(selectedColor?.color(with: themeManager.selectedColor) ?? DSTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill((selectedColor?.color(with: themeManager.selectedColor) ?? themeManager.selectedColor).opacity(0.1))
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }
}

private struct MoodCircleButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let mood: MoodColor
    let isSelected: Bool
    let action: () -> Void
    
    #if targetEnvironment(macCatalyst)
    private let circleSize: CGFloat = 60
    private let iconSize: CGFloat = 36
    #else
    private let circleSize: CGFloat = 72
    private let iconSize: CGFloat = 44
    #endif
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    mood.color(with: themeManager.selectedColor).opacity(isSelected ? 0.28 : 0.12),
                                    mood.color(with: themeManager.selectedColor).opacity(isSelected ? 0.12 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: circleSize, height: circleSize)
                        .overlay(
                            Circle()
                                .stroke(mood.color(with: themeManager.selectedColor).opacity(isSelected ? 0.62 : 0.18), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? mood.color(with: themeManager.selectedColor).opacity(0.22) : .clear, radius: 12, y: 6)
                    
                    mood.icon(size: iconSize)
                        .foregroundStyle(mood.iconColor(with: themeManager.selectedColor))
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                }

                Text(mood.label)
                    .font(DSTypography.caption)
                    .foregroundStyle(isSelected ? mood.color(with: themeManager.selectedColor) : DSTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
