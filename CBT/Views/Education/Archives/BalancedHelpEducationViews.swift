import SwiftUI

struct BalancedThoughtEducationView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @State private var showingFlow = false
    
    var body: some View {
        CBTEducationLayout(title: "Balanced Perspectives", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Beyond Positive Thinking")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("A balanced thought is a realistic alternative that accounts for all the evidence you've gathered—both for and against your automatic thought.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                EducationSection(
                    title: "Examples",
                    items: [
                        "Original: 'I'll never get this done.'\nBalanced: 'This is a large task, but I have finished similar ones before by taking small steps.'",
                        "Original: 'Everyone thinks I'm boring.'\nBalanced: 'I don't have proof of what everyone thinks. Some people enjoy my company, and I can't please everyone.'",
                        "Original: 'I'm a failure because I messed up.'\nBalanced: 'I made a mistake, which is human. One mistake doesn't define my entire ability.'"
                    ]
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text("Try this now")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        
                        Text("Practice creating balanced thoughts in the app.")
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                        
                        Button {
                            HapticManager.shared.mediumImpact()
                            showingFlow = true
                        } label: {
                            Text("Start Practice")
                                .font(DSTypography.body)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.primaryColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingFlow) {
            NewThoughtRecordFlowView()
        }
    }
}

struct ProfessionalHelpEducationView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    var body: some View {
        CBTEducationLayout(title: "Professional Support", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("When to Seek Help")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("While this app is a helpful tool for self-reflection and building CBT skills, it is not a replacement for professional clinical care.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                EducationSection(
                    title: "Consider Professional Help If:",
                    items: [
                        "Distress is making it hard to manage daily life or work",
                        "You feel overwhelmed by emotions most of the time",
                        "Self-help tools don't seem to be providing enough relief",
                        "You want structured guidance from a trained therapist"
                    ]
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text("You're Not Alone")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        
                        Text("Many people find that a combination of self-guided tools and professional therapy yields the best results. Don't hesitate to reach out to a mental health professional.")
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                    }
                }
                .padding(.horizontal)
                
                Text("Note: This app is for educational purposes only. If you are in a crisis, please contact your local emergency services or a crisis hotline immediately.")
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
