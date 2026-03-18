import SwiftUI

struct MoodColorSelector: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedColor: MoodColor?
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("How are you feeling right now?")
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                ForEach(MoodColor.allCases.reversed(), id: \.self) { mood in
                    MoodCircleButton(mood: mood, isSelected: selectedColor == mood) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedColor = mood
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            if let color = selectedColor {
                Text(color.label)
                    .font(.headline)
                    .foregroundStyle(color.color(with: themeManager.selectedColor))
                    .transition(.opacity.combined(with: .scale))
            } else {
                Text(" ")
                    .font(.headline)
            }
            
            Spacer()
            
            Button("Continue") {
                onNext()
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(selectedColor == nil)
            .opacity(selectedColor == nil ? 0.5 : 1.0)
            .padding(.horizontal, DSSpacing.large)
            .padding(.bottom, DSSpacing.large)
        }
    }
}

private struct MoodCircleButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let mood: MoodColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(mood.color(with: themeManager.selectedColor).opacity(isSelected ? 0.2 : 0.1))
                    .frame(width: isSelected ? 72 : 56, height: isSelected ? 72 : 56)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                Image(systemName: mood.symbol)
                    .font(.system(size: isSelected ? 32 : 24))
                    .foregroundStyle(mood.color(with: themeManager.selectedColor))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
