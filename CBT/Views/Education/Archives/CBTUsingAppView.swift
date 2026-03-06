import SwiftUI

struct CBTUsingAppView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    struct AppFeature {
        let title: String
        let description: String
        let icon: String
        let color: Color
    }
    
    let features = [
        AppFeature(title: "Mood Tracking", description: "Log your mood once a day to see trends in your emotional well-being over time.", icon: "heart.fill", color: Color.red),
        AppFeature(title: "Thought Records", description: "Use the Journal to record unhelpful thoughts and follow the structured flow to challenge them.", icon: "bubble.left.fill", color: Color.blue),
        AppFeature(title: "CBT Exercises", description: "Practice specific CBT techniques in a guided, easy-to-follow format to build your mental toolbox.", icon: "lightbulb.fill", color: Color.yellow),
        AppFeature(title: "Breathing Reset", description: "In moments of high stress or anxiety, use the guided breathing tool to calm your nervous system.", icon: "wind", color: Color.cyan),
        AppFeature(title: "Daily Insights", description: "Review your progress and identify patterns in your mood, thoughts, and behaviors.", icon: "chart.bar.fill", color: Color.green)
    ]
    
    var body: some View {
        CBTEducationLayout(title: "Using This App", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Your Guide to Progress")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("This app is designed to be your daily companion in building better mental health habits.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                ForEach(features, id: \.title) { feature in
                    DSCardContainer {
                        HStack(spacing: DSSpacing.medium) {
                            Circle()
                                .fill(feature.color.opacity(0.12))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: feature.icon)
                                        .foregroundStyle(feature.color)
                                        .font(.system(size: 18, weight: .bold))
                                )
                            
                            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                                Text(feature.title)
                                    .font(DSTypography.body)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(DSTheme.primaryText)
                                
                                Text(feature.description)
                                    .font(DSTypography.body)
                                    .foregroundStyle(DSTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Daily Practice is Key")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("The more you use these features, the more effective they will be for your mental well-being.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
        }
    }
}
