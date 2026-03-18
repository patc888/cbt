import SwiftUI

struct MoodCheckInEducationView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @State private var showingFlow = false
    @State private var attemptingFlow = false
    
    var body: some View {
        CBTEducationLayout(title: "Mood Check-In", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Why Track Your Mood?")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Mood tracking is a fundamental CBT skill. By logging how you feel, you can identify patterns between your activities, thoughts, and emotions.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: DSSpacing.large) {
                EducationSection(
                    title: "Benefits",
                    items: [
                        "Identify triggers for low mood or anxiety",
                        "Recognize positive changes over time",
                        "Build emotional awareness",
                        "Understand the connection between thoughts and feelings"
                    ]
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text("Try this now")
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                        
                        Text("Take a moment to check in with yourself. How are you feeling right now?")
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                        
                        Button {
                            HapticManager.shared.mediumImpact()
                            attemptingFlow = true
                        } label: {
                            Text("Log My Mood")
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
            MoodCheckinView()
        }
        .withUsageGate(isAttemptingAction: $attemptingFlow) {
            showingFlow = true
        }
    }
}

struct EducationSection: View {
    let title: String
    let items: [String]
    
    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                Text(title)
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(DSTheme.primaryText)
                
                VStack(alignment: .leading, spacing: DSSpacing.small) {
                    ForEach(items, id: \.self) { item in
                        BulletPoint(text: item)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
