import SwiftUI

struct DistortionExampleCardView: View {
    @Environment(ThemeManager.self) private var themeManager
    let example: CognitiveDistortionExample
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingMedium) {
            // Distortion Name
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(themeManager.selectedColor)
                Text(example.distortion)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primaryText)
            }
            
            // Explanation
            Text(example.explanation)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(Theme.secondaryText)
            
            Divider()
            
            // Example Thought
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                Label("Example Thought", systemImage: "cloud")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
                
                Text("\"\(example.thought)\"")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .italic()
                    .foregroundColor(Theme.primaryText)
                    .padding(.leading, Theme.paddingMedium)
            }
            
            // Balanced Thought
            VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                Label("Balanced Reframe", systemImage: "leaf")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.successGreen)
                
                Text(example.balancedThought)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.primaryText)
                    .padding(.leading, Theme.paddingMedium)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
