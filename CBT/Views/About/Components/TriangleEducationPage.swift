import SwiftUI

struct TriangleEducationPage: View {
    @State private var activeNode: CBTDiagramTriangle.CBTNodeType? = .thought
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "The CBT Triangle",
            subtitle: "Your thoughts, emotions, and behaviors are all interconnected."
        ) {
            VStack(spacing: 24) {
                InteractiveCBTTriangle(activeNode: $activeNode)
                    .frame(height: 220)
                    .padding(.vertical)
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(activeNodeTitle)
                            .font(.headline)
                            .foregroundStyle(themeManager.selectedColor)
                        
                        Text(activeNodeDescription)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .id(activeNode)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                }
                
                Text("Tap the nodes above to see how they interact.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
            }
        }
    }
    
    private var activeNodeTitle: String {
        switch activeNode {
        case .thought: return "Thoughts"
        case .emotion: return "Emotions"
        case .behavior: return "Behaviors"
        case .none: return "The Connection"
        }
    }
    
    private var activeNodeDescription: String {
        switch activeNode {
        case .thought: return "What we tell ourselves about a situation. These can be helpful or unhelpful, facts or interpretations."
        case .emotion: return "How we feel in our body and mind (e.g., anxiety, sadness, joy). Emotions often follow our interpretations."
        case .behavior: return "What we do in response. This includes actions, avoidance, or habits that can reinforce how we feel."
        case .none: return "Select a node to learn more about how it contributes to your well-being."
        }
    }
}
