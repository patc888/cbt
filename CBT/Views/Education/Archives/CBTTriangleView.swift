import SwiftUI

struct CBTTriangleView: View {
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @State private var activeNode: CBTDiagramTriangle.CBTNodeType? = .thought
    
    var body: some View {
        CBTEducationLayout(title: "The CBT Triangle", hideBackground: hideBackground, hideTitle: hideTitle) {
            DSCardContainer {
                VStack(spacing: DSSpacing.large) {
                    Text("The Core Model")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Tapping each node reveals how they interact.")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    
                    InteractiveCBTTriangle(activeNode: $activeNode)
                        .frame(height: 220)
                        .padding(.vertical)
                    
                    Divider()
                        .background(DSTheme.separator)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.medium) {
                        Text(activeNodeTitle)
                            .font(DSTypography.body)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.primaryColor)
                        
                        Text(activeNodeDescription)
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    .id(activeNode)
                }
            }
            .padding(.horizontal)
            
            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("Interconnectedness")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSTheme.primaryText)
                    
                    Text("Change one side of the triangle, and the others follow. This is the foundation of change in CBT.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                    
                    BulletPoint(text: "Thoughts impact how we feel.")
                    BulletPoint(text: "Feelings lead to certain behaviors.")
                    BulletPoint(text: "Behaviors influence our mindset.")
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var activeNodeTitle: String {
        switch activeNode {
        case .thought: return "Thoughts: What we tell ourselves"
        case .emotion: return "Emotions: What we feel"
        case .behavior: return "Behaviors: What we do"
        case .none: return "Select a node"
        }
    }
    
    private var activeNodeDescription: String {
        switch activeNode {
        case .thought:
            return "Cognitive processes like interpretations, beliefs, and self-talk. CBT focused on identifying and challenging distorted thoughts."
        case .emotion:
            return "Emotional states like anxiety, sadness, or joy, often accompanied by physical sensations in the body."
        case .behavior:
            return "External actions and choices, including avoidance, social engagement, and habits. Changing behavior can directly improve how you feel."
        case .none:
            return "Tapping any of the three nodes on the triangle will provide basic information on how that area affects your well-being."
        }
    }
}

struct InteractiveCBTTriangle: View {
    @Binding var activeNode: CBTDiagramTriangle.CBTNodeType?
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) * 0.4
            
            let pts = [
                CGPoint(x: center.x, y: center.y - radius), // Top: Thought
                CGPoint(x: center.x - radius * 0.866, y: center.y + radius * 0.5), // Bottom Left: Emotion
                CGPoint(x: center.x + radius * 0.866, y: center.y + radius * 0.5)  // Bottom Right: Behavior
            ]
            
            ZStack {
                // Lines with Arrows
                Path { path in
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.closeSubpath()
                }
                .stroke(Theme.primaryColor.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Nodes
                InteractiveNode(title: "Thoughts", icon: "bubble.left.fill", pt: pts[0], type: .thought, activeNode: $activeNode)
                InteractiveNode(title: "Emotions", icon: "heart.fill", pt: pts[1], type: .emotion, activeNode: $activeNode)
                InteractiveNode(title: "Behaviors", icon: "figure.walk", pt: pts[2], type: .behavior, activeNode: $activeNode)
            }
        }
    }
    
    struct InteractiveNode: View {
        let title: String
        let icon: String
        let pt: CGPoint
        let type: CBTDiagramTriangle.CBTNodeType
        @Binding var activeNode: CBTDiagramTriangle.CBTNodeType?
        
        var body: some View {
            Button {
                withAnimation(.spring) {
                    activeNode = type
                }
            } label: {
                VStack(spacing: 6) {
                    Circle()
                        .fill(activeNode == type ? Theme.primaryColor : DSTheme.cardBackground)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: icon)
                                .foregroundStyle(activeNode == type ? .white : Theme.primaryColor)
                                .font(.system(size: 20, weight: .bold))
                        )
                        .overlay(
                            Circle()
                                .stroke(Theme.primaryColor.opacity(0.6), lineWidth: 2)
                        )
                        .shadow(color: Theme.primaryColor.opacity(activeNode == type ? 0.4 : 0.1), radius: 10, y: 5)
                        .scaleEffect(activeNode == type ? 1.1 : 1.0)
                    
                    Text(title)
                        .font(DSTypography.caption)
                        .fontWeight(.heavy)
                        .foregroundStyle(activeNode == type ? Theme.primaryColor : DSTheme.primaryText)
                        .background(
                            Capsule()
                                .fill(DSTheme.cardBackground.opacity(0.8))
                                .padding(.horizontal, -10)
                                .padding(.vertical, -3)
                        )
                }
            }
            .buttonStyle(.plain)
            .position(pt)
        }
    }
}
