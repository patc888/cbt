import SwiftUI

struct CBTResearchView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    struct ResearchBar: View {
        let label: String
        let value: CGFloat
        let color: Color
        let delay: Double
        
        @State private var animate = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text(label)
                    .font(DSTypography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(DSTheme.secondaryText)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(0.1))
                            .frame(maxWidth: .infinity)
                        
                        Capsule()
                            .fill(color)
                            .frame(width: animate ? geo.size.width * value : 0)
                            .overlay(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(Capsule())
                            )
                    }
                }
                .frame(height: 24)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).delay(delay)) {
                    animate = true
                }
            }
        }
    }
    
    var body: some View {
        CBTEducationLayout(title: "What Research Shows", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("The Gold Standard")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("CBT is extensively researched and considered the 'gold standard' for many mental health conditions.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    Text("Comparative Effectiveness")
                        .font(DSTypography.body)
                        .fontWeight(.heavy)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    VStack(spacing: DSSpacing.large) {
                        ResearchBar(label: "CBT Effectiveness (High)", value: 0.9, color: Theme.primaryColor, delay: 0.1)
                        ResearchBar(label: "Medication Alone (Moderate)", value: 0.65, color: Theme.secondaryColor, delay: 0.3)
                        ResearchBar(label: "No Treatment (Low)", value: 0.15, color: DSTheme.secondaryText.opacity(0.4), delay: 0.5)
                    }
                    
                    Text("Based on multiple meta-analyses of clinical trials, showing relative success in symptom reduction.")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                        .italic()
                        .padding(.top, DSSpacing.small)
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Evidence Highlights")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Thousands of studies have demonstrated CBT's effectiveness for a variety of conditions.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        BulletPoint(text: "High success rates for Anxiety and Depression.")
                        BulletPoint(text: "Reduced relapse rates compared to medication.")
                        BulletPoint(text: "Improvement in overall quality of life.")
                        BulletPoint(text: "Adaptable for different ages and cultures.")
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
