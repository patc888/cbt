import SwiftUI

struct CBTHowItWorksView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    struct Step {
        let title: String
        let description: String
        let icon: String
    }
    
    let steps = [
        Step(title: "Notice Mood", description: "Pay attention to your feelings. If you're feeling a strong or negative emotion, it's time to pause.", icon: "bell.fill"),
        Step(title: "Identify Thought", description: "What was going through your mind just before you felt that way? Capture it.", icon: "bubble.left.fill"),
        Step(title: "Examine Evidence", description: "Is the thought true? What evidence supports it? What evidence contradicts it?", icon: "magnifyingglass"),
        Step(title: "Balanced Thought", description: "Based on the evidence, create a more accurate and helpful way of viewing the situation.", icon: "arrow.triangle.2.circlepath"),
        Step(title: "Emotions Improve", description: "By changing the thought, your mood naturally begins to lift and settle.", icon: "heart.fill")
    ]
    
    var body: some View {
        CBTEducationLayout(title: "How CBT Works", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("The Path to Change")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("CBT is a systematic process of self-observation and mental habit change. It works best when practiced consistently.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: DSSpacing.medium) {
                            StepIndicator(icon: step.icon, isLast: index == steps.count - 1)
                            
                            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                                Text(step.title)
                                    .font(DSTypography.body)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(Theme.primaryColor)
                                
                                Text(step.description)
                                    .font(DSTypography.body)
                                    .foregroundStyle(DSTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, DSSpacing.large)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("The Outcome")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Over time, this process becomes automatic, and you find yourself reacting to events with more grace and mental flexibility.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct StepIndicator: View {
        let icon: String
        let isLast: Bool
        
        var body: some View {
            VStack(spacing: 0) {
                Circle()
                    .fill(Theme.primaryColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                    )
                
                if !isLast {
                    Rectangle()
                        .fill(Theme.primaryColor.opacity(0.3))
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
}
