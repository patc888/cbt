import SwiftUI

struct CBTEducationIntroView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    
    var body: some View {
        CBTEducationLayout(title: "What is CBT?", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("The Core Idea")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Cognitive Behavioral Therapy (CBT) is based on the idea that our thoughts, feelings, and behaviors are all connected. By changing unhelpful thinking patterns, we can change how we feel and what we do.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                    
                    CBTDiagramTriangle(activeNode: nil)
                        .frame(height: 200)
                        .padding(.vertical)
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("How it Works")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("CBT helps you become an observer of your own mind. Instead of accepting every thought as a 'fact', you learn to treat them as 'hypotheses' that can be tested.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        BulletPoint(text: "Identify negative thought patterns.")
                        BulletPoint(text: "Challenge their accuracy.")
                        BulletPoint(text: "Develop more balanced perspectives.")
                    }
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Practical and Present-Focused")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Unlike some therapies that focus deeply on the past, CBT is primarily focused on the 'here and now'—giving you tools to manage your current difficulties and improve your quality of life today.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CBTDiagramTriangle: View {
    let activeNode: CBTNodeType?
    
    enum CBTNodeType {
        case thought, emotion, behavior
    }
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) * 0.35
            
            let pts = [
                CGPoint(x: center.x, y: center.y - radius), // Top: Thought
                CGPoint(x: center.x - radius * 0.866, y: center.y + radius * 0.5), // Bottom Left: Emotion
                CGPoint(x: center.x + radius * 0.866, y: center.y + radius * 0.5)  // Bottom Right: Behavior
            ]
            
            ZStack {
                // Lines
                Path { path in
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.closeSubpath()
                }
                .stroke(Theme.primaryColor.opacity(0.3), lineWidth: 3)
                
                // Nodes
                NodeView(title: "Thoughts", icon: "bubble.left.fill", pt: pts[0], isActive: activeNode == .thought)
                NodeView(title: "Emotions", icon: "heart.fill", pt: pts[1], isActive: activeNode == .emotion)
                NodeView(title: "Behaviors", icon: "figure.walk", pt: pts[2], isActive: activeNode == .behavior)
            }
        }
    }
    
    struct NodeView: View {
        let title: String
        let icon: String
        let pt: CGPoint
        let isActive: Bool
        
        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(isActive ? Theme.primaryColor : DSTheme.cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(isActive ? .white : Theme.primaryColor)
                            .font(.system(size: 18, weight: .bold))
                    )
                    .overlay(
                        Circle()
                            .stroke(Theme.primaryColor.opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: Theme.primaryColor.opacity(isActive ? 0.4 : 0.1), radius: 8, y: 4)
                
                Text(title)
                    .font(DSTypography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(isActive ? Theme.primaryColor : DSTheme.primaryText)
                    .background(
                        Capsule()
                            .fill(DSTheme.cardBackground.opacity(0.8))
                            .padding(.horizontal, -8)
                            .padding(.vertical, -2)
                    )
            }
            .position(pt)
        }
    }
}
