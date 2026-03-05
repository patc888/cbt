import SwiftUI

struct EmotionSelectorView: View {
    @Binding var selectedEmotions: Set<String>
    let onNext: () -> Void
    
    private let emotions = [
        "Anxious", "Stressed", "Sad", "Angry", "Lonely", "Excited",
        "Happy", "Calm", "Grateful", "Frustrated", "Tired", "Overwhelmed"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            Text("What specific emotions do you feel?")
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(emotions, id: \.self) { emotion in
                        let isSelected = selectedEmotions.contains(emotion)
                        
                        Button {
                            HapticManager.shared.lightImpact()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if isSelected {
                                    selectedEmotions.remove(emotion)
                                } else {
                                    selectedEmotions.insert(emotion)
                                }
                            }
                        } label: {
                            Text(emotion)
                                .font(DSTypography.body)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundColor(isSelected ? .white : DSTheme.primaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous)
                                        .fill(isSelected ? Theme.primaryColor : DSTheme.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous)
                                        .stroke(isSelected ? Color.clear : DSTheme.separator.opacity(0.18), lineWidth: 1)
                                )
                                .scaleEffect(isSelected ? 1.05 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(emotion)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityHint(isSelected ? "Removes \(emotion)" : "Adds \(emotion)")
                    }
                }
                .padding(.horizontal, DSSpacing.large)
            }
            
            Button("Continue") {
                onNext()
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .padding(.horizontal, DSSpacing.large)
            .padding(.bottom, DSSpacing.large)
        }
    }
}
