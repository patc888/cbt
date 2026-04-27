import SwiftUI

struct CBTFurtherReadingView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    struct Reference {
        let title: String
        let author: String
        let description: String
    }
    
    let references = [
        Reference(
            title: "Feeling Good: The New Mood Therapy",
            author: "David Burns, MD",
            description: "A classic and comprehensive guide to using CBT to manage depression and anxiety, widely considered one of the best for self-help."
        ),
        Reference(
            title: "CBT Made Simple",
            author: "Seth Gillihan, PhD",
            description: "A more concise and modern guide to the core principles and practices of CBT, perfect for beginners and practice."
        ),
        Reference(
            title: "Cognitive Behavior Therapy: Basics and Beyond",
            author: "Judith Beck, PhD",
            description: "Written by the daughter of CBT's founder, this book is both clinical and accessible for those wanting a deep dive into the theory."
        ),
        Reference(
            title: "A Guide to Rational Living",
            author: "Albert Ellis, PhD",
            description: "Focused on Rational Emotive Behavior Therapy (REBT), a precursor and form of CBT that emphasizes challenging irrational beliefs."
        )
    ]
    
    var body: some View {
        CBTEducationLayout(title: "Further Reading", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Expanding Your Knowledge")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("If you're interested in learning more about the theory and practice of CBT, these resources are excellent starting points.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                ForEach(references, id: \.title) { ref in
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            Text(ref.title)
                                .font(DSTypography.body)
                                .fontWeight(.heavy)
                                .foregroundStyle(Theme.primaryColor)
                            
                            Text("by \(ref.author)")
                                .font(DSTypography.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(DSTheme.secondaryText)
                            
                            Text(ref.description)
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                DSCardContainer {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text("Online Resources")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        
                        Text("Websites from reputable organizations can provide additional exercises and information.")
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                        
                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            BulletPoint(text: "Association for Behavioral and Cognitive Therapies (ABCT)")
                            BulletPoint(text: "Beck Institute for Cognitive Behavior Therapy")
                            BulletPoint(text: "Academy of Cognitive & Behavioral Therapies")
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .center, spacing: DSSpacing.medium) {
                    Divider()
                        .padding(.horizontal)
                    
                    Text("Disclaimer")
                        .font(DSTypography.caption)
                        .fontWeight(.heavy)
                        .foregroundStyle(DSTheme.secondaryText)
                        .textCase(.uppercase)
                    
                    Text("This app provides educational tools based on cognitive behavioral therapy principles and is not a substitute for professional mental health care.")
                        .font(DSTypography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DSTheme.secondaryText)
                        .padding(.horizontal, DSSpacing.large)
                }
                .padding(.top, DSSpacing.large)
                .padding(.bottom, DSSpacing.xLarge)
            }
        }
    }
}
