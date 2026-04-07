import SwiftUI

struct CycleEducationPage: View {
    @State private var step = 0
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Unhelpful Cycles",
            subtitle: "A single event can trigger a spiral. CBT helps you spot these cycles early."
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    CycleStep(icon: "bell.fill", title: "Trigger Event", description: "You receive a brief email from your boss: 'Let's meet tomorrow.'", isActive: step >= 0)
                    
                    Arrow()
                    
                    CycleStep(icon: "bubble.left.fill", title: "Thought", description: "'I'm in trouble. I'm going to get fired.'", isActive: step >= 1)
                    
                    Arrow()
                    
                    CycleStep(icon: "heart.fill", title: "Emotion", description: "Intense anxiety, heart racing, inability to focus.", isActive: step >= 2)
                    
                    Arrow()
                    
                    CycleStep(icon: "figure.walk", title: "Behavior", description: "Avoid preparing for the meeting; stay up late worrying.", isActive: step >= 3)
                }
                .padding()
                .background(Theme.cardBackground.opacity(0.5))
                .cornerRadius(16)
                
                HStack {
                    Button("Reset") { withAnimation { step = 0 } }
                        .font(.caption.bold())
                        .foregroundStyle(Theme.secondaryText)
                    
                    Spacer()
                    
                    Button(step < 3 ? "Next Step" : "Cycle Complete") {
                        if step < 3 {
                            withAnimation(.spring()) { step += 1 }
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeManager.selectedColor.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
    }
    
    struct CycleStep: View {
        let icon: String
        let title: String
        let description: String
        let isActive: Bool
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .padding(8)
                    .background(isActive ? Theme.primaryColor : Color.secondary.opacity(0.2))
                    .foregroundStyle(isActive ? .white : Color.secondary)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isActive ? Theme.primaryText : Color.secondary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(isActive ? Theme.secondaryText : Color.secondary.opacity(0.5))
                }
                Spacer()
            }
            .opacity(isActive ? 1.0 : 0.4)
        }
    }
    
    struct Arrow: View {
        var body: some View {
            Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.secondaryText.opacity(0.3))
                .padding(.leading, 18)
        }
    }
}
