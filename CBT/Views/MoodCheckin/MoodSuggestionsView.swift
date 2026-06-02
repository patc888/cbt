import SwiftUI

struct MoodSuggestionsView: View {
    @Environment(ThemeManager.self) private var themeManager
    let onNext: () -> Void
    @State private var showingThoughtRecord = false
    @State private var attemptingThoughtRecord = false
    @State private var showingBreathing = false
    
    var body: some View {
        MoodStepScaffold(
            title: "Would you like help with this feeling?",
            subtitle: "Choose a short support tool, or continue straight to your summary.",
            icon: "hands.sparkles",
            accent: themeManager.selectedColor,
            actionTitle: "No thanks, continue",
            action: onNext
        ) {
            MoodGlassPanel(accent: themeManager.selectedColor) {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        SuggestionButton(
                            title: "Breathing Reset",
                            subtitle: "One minute of paced breathing",
                            icon: "wind"
                        ) {
                            showingBreathing = true
                        }
                        
                        SuggestionButton(
                            title: "Write a Thought Record",
                            subtitle: "Sort the thought from the feeling",
                            icon: "brain.head.profile"
                        ) {
                            showingThoughtRecord = true
                        }
                        
                        SuggestionButton(
                            title: "Try a CBT Exercise",
                            subtitle: "Move into a guided coping practice",
                            icon: "list.bullet.rectangle.portrait"
                        ) {
                            onNext()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingThoughtRecord) {
            NewThoughtRecordFlowView()
                .dsSheetPresentation()
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingBreathing) {
            NavigationStack {
                BreathingResetView(
                    durationSeconds: 60,
                    pattern: .box,
                    autoStart: true,
                    showsDismissControl: true,
                    showControls: true,
                    hideBackground: false,
                    onComplete: nil,
                    onDismiss: { showingBreathing = false }
                )
            }
        }
        #else
        .sheet(isPresented: $showingBreathing) {
            NavigationStack {
                BreathingResetView(
                    durationSeconds: 60,
                    pattern: .box,
                    autoStart: true,
                    showsDismissControl: true,
                    showControls: true,
                    hideBackground: false,
                    onComplete: nil,
                    onDismiss: { showingBreathing = false }
                )
            }
            .dsSheetPresentation()
        }
        #endif
    }
}

private struct SuggestionButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous)
                        .fill(themeManager.selectedColor.opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DSTypography.button)
                        .foregroundStyle(DSTheme.primaryText)

                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            }
            .foregroundStyle(themeManager.selectedColor)
        }
        .buttonStyle(DSButtonStyle(variant: .neutral, size: .large, hapticType: nil))
    }
}
