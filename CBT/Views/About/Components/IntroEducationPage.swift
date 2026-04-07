import SwiftUI

struct IntroEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "What is CBT?",
            subtitle: "Cognitive Behavioral Therapy (CBT) is an evidence-based approach to mental wellness."
        ) {
            VStack(spacing: 20) {
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundStyle(themeManager.selectedColor)
                            Text("Practical Tools")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                        }
                        
                        Text("Unlike some therapies that focus on the past, CBT is centered on the 'here and now'. It gives you practical tools to manage stress, anxiety, and low mood in your daily life.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title2)
                                .foregroundStyle(themeManager.selectedColor)
                            Text("Breaking Cycles")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                        }
                        
                        Text("CBT is based on the idea that how we think (Cognition) and how we act (Behavior) directly impact how we feel.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }
}
