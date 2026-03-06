import SwiftUI

struct ThoughtRecordEducationView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @State private var showingFlow = false
    
    var body: some View {
        CBTEducationLayout(title: "Thought Records", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("The 5-Step Method")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Thought records are tool for challenging unhelpful thinking. The goal is not to 'think positive,' but to find a more balanced, realistic perspective.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                EducationSection(
                    title: "The Process",
                    items: [
                        "1. Identify the situation and the automatic thought",
                        "2. Notice your emotions and their intensity",
                        "3. Identify any cognitive distortions (thinking traps)",
                        "4. Examine evidence for and against the thought",
                        "5. Formulate a more balanced, realistic thought"
                    ]
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text("Try this now")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        
                        Text("Have you had a difficult thought today? Try working through it now.")
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                        
                        Button {
                            HapticManager.shared.mediumImpact()
                            showingFlow = true
                        } label: {
                            Text("Start Thought Record")
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

struct EvidenceEducationView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @State private var showingFlow = false
    
    var body: some View {
        CBTEducationLayout(title: "Evidence for & Against", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Being Your Own Detective")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("When we are upset, we often only notice information that supports our negative thoughts. Examining evidence helps us see the full picture.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                EducationSection(
                    title: "What Counts as Evidence?",
                    items: [
                        "Objective facts (something a camera would see)",
                        "Past experiences that contradict the thought",
                        "Alternative explanations for others' behavior",
                        "Information you might be ignoring or downplaying"
                    ]
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text("Try this now")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        
                        Text("Practice gathering evidence in a new thought record.")
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
