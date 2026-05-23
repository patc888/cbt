import SwiftUI

struct MoodColorSelector: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedColor: MoodColor?
    let onNext: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 40) {
                    Text("How are you feeling right now?")
                        .font(DSTypography.pageTitle)
                        .foregroundStyle(DSTheme.primaryText)
                        .multilineTextAlignment(.center)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                        ForEach(MoodColor.allCases.reversed(), id: \.self) { mood in
                            MoodCircleButton(mood: mood, isSelected: selectedColor == mood) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedColor = mood
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DSSpacing.large)
                    
                    if let color = selectedColor {
                        Text(color.label)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(color.color(with: themeManager.selectedColor))
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        Text(" ")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                    
                    Button("Continue") {
                        onNext()
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(selectedColor == nil)
                    .opacity(selectedColor == nil ? 0.5 : 1.0)
                    .padding(.horizontal, DSSpacing.large)
                }
                .padding(.bottom, DSSpacing.large)
                .frame(minHeight: geo.size.height)
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
            ZStack {
                Circle()
                    .fill(mood.color(with: themeManager.selectedColor).opacity(isSelected ? 0.25 : 0.1))
                    .frame(width: circleSize, height: circleSize)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                mood.iconView
                    .font(.system(size: iconSize))
                    .foregroundStyle(mood.color(with: themeManager.selectedColor))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
