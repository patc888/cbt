import SwiftUI

struct CBTFlexibleThinkingView: View {
    @State private var showBalanced = false
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    var body: some View {
        CBTEducationLayout(title: "Flexible Thinking", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Beyond Black and White")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Flexible thinking is the ability to shift your perspective and consider alternative viewpoints. It's the hallmark of emotional intelligence and mental well-being.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                Toggle("Show Balanced Perspective", isOn: $showBalanced.animation(.spring(response: 0.4, dampingFraction: 0.8)))
                    .font(DSTypography.body)
                    .fontWeight(.bold)
                    .foregroundStyle(DSTheme.primaryText)
                    .tint(Theme.primaryColor)
                
                ZStack {
                    if showBalanced {
                        ThoughtComparisonCard(
                            title: "Balanced Thought",
                            icon: "leaf.fill",
                            color: DSTheme.success,
                            content: "\"Maybe they were busy or distracted. It's not a reflection of my worth and I can reach out later.\""
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    } else {
                        ThoughtComparisonCard(
                            title: "Automatic Thought",
                            icon: "bolt.fill",
                            color: DSTheme.warning,
                            content: "\"They ignored me. They must dislike me and I'm probably a failure at making friends anyway.\""
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("How to Shift")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        BulletPoint(text: "Ask for evidence, not just assumptions.")
                        BulletPoint(text: "Consider multiple explanations for an event.")
                        BulletPoint(text: "Practice self-compassion and kindness.")
                        BulletPoint(text: "Focus on what's helpful, not just what's 'true'.")
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct ThoughtComparisonCard: View {
        let title: String
        let icon: String
        let color: Color
        let content: String
        
        var body: some View {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                        Text(title)
                            .font(DSTypography.caption)
                            .fontWeight(.heavy)
                            .foregroundStyle(color)
                            .textCase(.uppercase)
                    }
                    
                    Text(content)
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.primaryText)
                        .italic(title == "Automatic Thought")
                }
            }
        }
    }
}
