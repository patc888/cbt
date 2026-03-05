import SwiftUI

struct MoodTriggerSelector: View {
    @Binding var selectedTriggers: Set<String>
    let onNext: () -> Void
    
    private let triggers = [
        "Work", "Family", "Health", "Sleep", "Social",
        "Finances", "Weather", "News", "Exercise", "Food", "Nothing specific"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            Text("What influenced this mood?")
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach(triggers, id: \.self) { trigger in
                        let isSelected = selectedTriggers.contains(trigger)
                        
                        Button {
                            HapticManager.shared.lightImpact()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if trigger == "Nothing specific" {
                                    if isSelected {
                                        selectedTriggers.remove(trigger)
                                    } else {
                                        selectedTriggers.removeAll()
                                        selectedTriggers.insert(trigger)
                                    }
                                } else {
                                    if isSelected {
                                        selectedTriggers.remove(trigger)
                                    } else {
                                        selectedTriggers.remove("Nothing specific")
                                        selectedTriggers.insert(trigger)
                                    }
                                }
                            }
                        } label: {
                            Text(trigger)
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
                        .accessibilityLabel(trigger)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityHint(isSelected ? "Removes \(trigger)" : "Adds \(trigger)")
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
