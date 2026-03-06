import SwiftUI

struct CBTPatternsView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    var body: some View {
        CBTEducationLayout(title: "Seeing Patterns", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("The Power of Tracking")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Tracking your mood over time allows you to identify patterns in your thoughts and behaviors that might be keeping you stuck.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    Text("Weekly Mood Visualization")
                        .font(DSTypography.body)
                        .fontWeight(.heavy)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    MoodBarChart()
                        .frame(height: 180)
                        .padding(.vertical, DSSpacing.small)
                    
                    Text("This simple bar chart shows how mood fluctuations can reveal emotional trends and triggers.")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                        .italic()
                        .padding(.top, DSSpacing.small)
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Common Patterns to Look For")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        BulletPoint(text: "Avoidance cycles that maintain anxiety.")
                        BulletPoint(text: "Rumination loops that lead to sadness.")
                        BulletPoint(text: "Negative self-talk that impacts confidence.")
                        BulletPoint(text: "Coping mechanisms that aren't working.")
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct MoodBarChart: View {
    @State private var animateBars = false
    
    let days = ["M", "T", "W", "T", "F", "S", "S"]
    let values: [CGFloat] = [0.6, 0.45, 0.75, 0.55, 0.8, 0.9, 0.7] // 0.0 to 1.0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: DSSpacing.medium) {
            ForEach(0..<7) { index in
                VStack(spacing: DSSpacing.small) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.primaryColor.opacity(0.1))
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Capsule()
                                    .fill(Theme.primaryColor)
                                    .frame(height: animateBars ? geo.size.height * values[index] : 0)
                                    .frame(maxWidth: .infinity, alignment: .bottom)
                                    .overlay(
                                        LinearGradient(
                                            colors: [.white.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .clipShape(Capsule())
                                    )
                                    .shadow(color: Theme.primaryColor.opacity(0.3), radius: 4, y: 2)
                                    .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.1), value: animateBars)
                                , alignment: .bottom
                            )
                    }
                    
                    Text(days[index])
                        .font(DSTypography.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
        }
        .onAppear {
            animateBars = true
        }
    }
}
