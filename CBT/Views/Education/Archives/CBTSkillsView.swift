import SwiftUI

struct CBTSkillsView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    struct Skill {
        let title: String
        let description: String
        let icon: String
    }
    
    let skills = [
        Skill(title: "Mood awareness", description: "The ability to notice and label your emotions in real-time, which is the foundational first step in CBT.", icon: "bell.fill"),
        Skill(title: "Thought records", description: "A structured process for tracking unhelpful thoughts and challenging them to find more balanced alternatives.", icon: "bubble.left.fill"),
        Skill(title: "Behavioral experiments", description: "Testing your negative beliefs by intentionally trying new behaviors and observing the outcome.", icon: "magnifyingglass"),
        Skill(title: "Relaxation techniques", description: "Using breathwork and other physical practices to calm your nervous system and reduce physical tension.", icon: "wind")
    ]
    
    var body: some View {
        CBTEducationLayout(title: "CBT Skills", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Your Toolbox")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("These skills are designed to work together, helping you manage both your mind and your body.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                ForEach(skills, id: \.title) { skill in
                    DSCardContainer {
                        HStack(spacing: DSSpacing.medium) {
                            Circle()
                                .fill(Theme.primaryColor.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: skill.icon)
                                        .foregroundStyle(Theme.primaryColor)
                                        .font(.system(size: 18, weight: .bold))
                                )
                            
                            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                                Text(skill.title)
                                    .font(DSTypography.body)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(Theme.primaryColor)
                                
                                Text(skill.description)
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
                    Text("Consistent Practice")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("The more you use these tools, the more natural they become. Don't worry if it feels awkward at first.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
        }
    }
}
