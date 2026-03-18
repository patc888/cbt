import SwiftUI

struct MoodSuggestionsView: View {
    let onNext: () -> Void
    @State private var showingThoughtRecord = false
    @State private var showingBreathing = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 10)
            
            Text("Would you like help with this feeling?")
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                SuggestionButton(
                    title: "Breathing Reset",
                    icon: "wind"
                ) {
                    showingBreathing = true
                }
                
                SuggestionButton(
                    title: "Write a Thought Record",
                    icon: "brain.head.profile"
                ) {
                    showingThoughtRecord = true
                }
                
                SuggestionButton(
                    title: "Try a CBT Exercise",
                    icon: "list.bullet.rectangle.portrait"
                ) {
                    // In a full app, this might navigate to the exercises tab.
                    // For now, we continue since exercises are in another area.
                    onNext()
                }
            }
            .padding(.horizontal, DSSpacing.large)
            
            Spacer()
            
            Button("No thanks, continue") {
                onNext()
            }
            .buttonStyle(.plain)
            .font(DSTypography.body.bold())
            .foregroundStyle(DSTheme.secondaryText)
            .padding(.bottom, DSSpacing.large)
        }
        .sheet(isPresented: $showingThoughtRecord) {
            NewThoughtRecordFlowView()
        }
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
    }
}

private struct SuggestionButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 32)
                
                Text(title)
                    .font(DSTypography.button)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            }
            .padding(20)
            .foregroundStyle(themeManager.selectedColor)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
            )
            .padding(.horizontal, 4) // Space for shadow
        }
        .buttonStyle(.plain)
    }
}
