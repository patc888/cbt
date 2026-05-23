import SwiftUI

struct ThoughtRecordEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Thought Records",
            subtitle: "The most powerful tool in the CBT toolkit for processing difficult moments."
        ) {
            VStack(spacing: 20) {
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why write it down?")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("Writing down your thoughts helps you step back and see them as 'mental events' rather than absolute facts. This 'de-centering' is key to emotional regulation.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    StepRow(number: "1", title: "The Situation", description: "What happened? (Who, where, when)")
                    StepRow(number: "2", title: "Automatic Thoughts", description: "What went through your mind at that exact moment?")
                    StepRow(number: "3", title: "Emotions", description: "What did you feel, and how intense was it (0-100%)?")
                    StepRow(number: "4", title: "Evidence", description: "Look for facts that support AND facts that contradict the thought.")
                    StepRow(number: "5", title: "Balanced Perspective", description: "Write a more accurate, helpful view based on the evidence.")
                }
                .padding(.top, 8)
            }
        }
    }
    
    struct StepRow: View {
        let number: String
        let title: String
        let description: String
        @Environment(ThemeManager.self) private var themeManager
        
        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Text(number)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 32, height: 32)
                    .background(themeManager.selectedColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}
