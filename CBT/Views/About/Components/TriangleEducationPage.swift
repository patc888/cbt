import SwiftUI

enum CBTDiagramTriangle {
    enum CBTNodeType: String, CaseIterable, Identifiable {
        case thought
        case emotion
        case behavior

        var id: String { rawValue }

        var title: String {
            switch self {
            case .thought: return "Thoughts"
            case .emotion: return "Emotions"
            case .behavior: return "Behaviors"
            }
        }

        var symbolName: String {
            switch self {
            case .thought: return "bubble.left.and.bubble.right.fill"
            case .emotion: return "heart.fill"
            case .behavior: return "figure.walk"
            }
        }
    }
}

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
                            .font(.system(.headline, design: .rounded).weight(.bold))
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

private struct InteractiveCBTTriangle: View {
    @Binding var activeNode: CBTDiagramTriangle.CBTNodeType?
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let nodeSize = min(width, height) * 0.28
            let thought = CGPoint(x: width * 0.5, y: height * 0.15)
            let emotion = CGPoint(x: width * 0.18, y: height * 0.78)
            let behavior = CGPoint(x: width * 0.82, y: height * 0.78)

            ZStack {
                Path { path in
                    path.move(to: thought)
                    path.addLine(to: emotion)
                    path.addLine(to: behavior)
                    path.closeSubpath()
                }
                .stroke(themeManager.selectedColor.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                node(.thought, at: thought, size: nodeSize)
                node(.emotion, at: emotion, size: nodeSize)
                node(.behavior, at: behavior, size: nodeSize)
            }
            .frame(width: width, height: height)
        }
        .accessibilityElement(children: .contain)
    }

    private func node(_ node: CBTDiagramTriangle.CBTNodeType, at point: CGPoint, size: CGFloat) -> some View {
        let isActive = activeNode == node

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                activeNode = node
            }
            HapticManager.shared.lightImpact()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: node.symbolName)
                    .font(.system(size: size * 0.28, weight: .semibold))
                Text(node.title)
                    .font(.system(size: max(12, size * 0.13), weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? .white : themeManager.selectedColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isActive ? themeManager.selectedColor : DSTheme.cardBackground)
                    .shadow(color: .black.opacity(isActive ? 0.16 : 0.08), radius: isActive ? 12 : 6, y: 4)
            )
            .overlay(
                Circle()
                    .stroke(themeManager.selectedColor.opacity(isActive ? 0 : 0.28), lineWidth: 1)
            )
            .scaleEffect(isActive ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel(node.title)
    }
}
