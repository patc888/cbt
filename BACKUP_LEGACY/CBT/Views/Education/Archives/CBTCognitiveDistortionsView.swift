import SwiftUI

struct CBTCognitiveDistortionsView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @State private var expandedId: String? = "all-or-nothing"
    
    struct Distortion {
        let id: String
        let title: String
        let definition: String
        let example: String
        let antidote: String
    }
    
    let distortions = [
        Distortion(
            id: "all-or-nothing",
            title: "All-or-Nothing Thinking",
            definition: "Viewing situations in black-and-white terms, where anything less than perfect is seen as a complete failure.",
            example: "\"I didn't get an A on the test, so I'm a total failure.\"",
            antidote: "Recognize that there is a spectrum, and one imperfection doesn't mean total failure."
        ),
        Distortion(
            id: "catastrophizing",
            title: "Catastrophizing",
            definition: "Expecting the absolute worst outcome, even when there is little evidence to suggest it will happen.",
            example: "\"If I make a mistake at work, I'll get fired and end up homeless.\"",
            antidote: "Consider the actual likelihood of the worst case and plan for more probable outcomes."
        ),
        Distortion(
            id: "mind-reading",
            title: "Mind Reading",
            definition: "Assuming you know what others are thinking or why they are acting a certain way, usually in a negative light and without evidence.",
            example: "\"She didn't wave back to me; she must be angry and hate me.\"",
            antidote: "Ask yourself what other explanations might exist, or clarify with the person if appropriate."
        ),
        Distortion(
            id: "overgeneralization",
            title: "Overgeneralization",
            definition: "Taking a single negative event and seeing it as a never-ending pattern of defeat.",
            example: "\"I didn't get this job; I'll never find work and I'm a failure.\"",
            antidote: "Avoid words like 'always' or 'never' and treat each situation as unique."
        ),
        Distortion(
            id: "personalization",
            title: "Personalization",
            definition: "Taking responsibility for things outside your control, often blaming yourself for someone else's behavior or a negative event.",
            example: "\"My friend is having a bad day; I must have done something to upset them.\"",
            antidote: "Acknowledge that many factors contribute to a person's behavior that have nothing to do with you."
        )
    ]
    
    var body: some View {
        CBTEducationLayout(title: "Cognitive Distortions", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Thinking Shorthand")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("These are common ways the brain distorts reality to maintain negative emotions. Recognizing them is the first step in changing them.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.medium) {
                ForEach(distortions, id: \.id) { distortion in
                    DistortionCard(
                        distortion: distortion,
                        isExpanded: expandedId == distortion.id,
                        onToggle: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if expandedId == distortion.id {
                                    expandedId = nil
                                } else {
                                    expandedId = distortion.id
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct DistortionCard: View {
        let distortion: Distortion
        let isExpanded: Bool
        let onToggle: () -> Void
        
        var body: some View {
            DSCardContainer {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onToggle) {
                        HStack {
                            Text(distortion.title)
                                .font(DSTypography.body)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.primaryColor)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.primaryColor)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if isExpanded {
                        VStack(alignment: .leading, spacing: DSSpacing.medium) {
                            Divider()
                                .padding(.vertical, DSSpacing.small)
                                .background(DSTheme.separator)
                            
                            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                                Text("What it is:")
                                    .font(DSTypography.caption)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(DSTheme.secondaryText)
                                Text(distortion.definition)
                                    .font(DSTypography.body)
                                    .foregroundStyle(DSTheme.primaryText)
                            }
                            
                            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                                Text("Example:")
                                    .font(DSTypography.caption)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(DSTheme.secondaryText)
                                Text(distortion.example)
                                    .font(DSTypography.body)
                                    .italic()
                                    .foregroundStyle(DSTheme.secondaryText)
                            }
                            
                            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                                Text("The Antidote:")
                                    .font(DSTypography.caption)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(Theme.primaryColor)
                                Text(distortion.antidote)
                                    .font(DSTypography.body)
                                    .foregroundStyle(DSTheme.primaryText)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
    }
}
