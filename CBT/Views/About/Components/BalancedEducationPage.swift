import SwiftUI

struct BalancedEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Balanced Perspective",
            subtitle: "The goal isn't just 'positive thinking'—it's 'accurate thinking'."
        ) {
            VStack(spacing: 24) {
                ComparisonView(
                    title: "Automatic Thought",
                    content: "'I made a mistake in the presentation. Everyone thinks I'm incompetent.'",
                    color: .red,
                    icon: "cloud.bolt.fill"
                )
                
                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(themeManager.selectedColor)
                
                ComparisonView(
                    title: "Balanced Thought",
                    content: "'I made one mistake, but the rest went well. Mistakes are human, and no one said they were unhappy.'",
                    color: .green,
                    icon: "sparkles"
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Shift")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("A balanced thought is grounded in all the evidence. It acknowledges the difficulty while also recognizing your strengths and alternative explanations.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }
    
    struct ComparisonView: View {
        let title: String
        let content: String
        let color: Color
        let icon: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .textCase(.uppercase)
                }
                
                Text(content)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}
