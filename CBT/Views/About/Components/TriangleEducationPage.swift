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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        PagerLayout(
            title: "The CBT Triangle",
            subtitle: "Your thoughts, emotions, and behaviors are all interconnected."
        ) {
            VStack(spacing: 24) {
                InteractiveCBTTriangle(activeNode: $activeNode)
                    .frame(height: triangleHeight)
                    .padding(.vertical)
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(activeNodeTitle)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(activeNodeDescription)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .id(activeNode)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                }
                
                Text("Tap the nodes above to see how they interact.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var triangleHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 300 : 244
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let nodeSize = resolvedNodeSize(width: width, height: height)
            let activeRadius = nodeSize * 0.53
            let edgeInset = activeRadius + 8
            let thought = CGPoint(x: width * 0.5, y: edgeInset)
            let emotion = CGPoint(x: edgeInset, y: height - edgeInset)
            let behavior = CGPoint(x: width - edgeInset, y: height - edgeInset)

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
            VStack(spacing: max(4, size * 0.07)) {
                Image(systemName: node.symbolName)
                    .font(.system(size: size * 0.24, weight: .semibold))
                    .frame(height: size * 0.28)

                Text(node.title)
                    .font(.system(size: max(11, size * 0.14), weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.center)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: max(44, size - 12))
            }
            .padding(.horizontal, 6)
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
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(point)
        .accessibilityLabel(node.title)
    }

    private func resolvedNodeSize(width: CGFloat, height: CGFloat) -> CGFloat {
        let edgeBound = min(width * 0.31, height * 0.34)
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 90 : 76
        let maximum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 112 : 94
        return min(max(edgeBound, minimum), maximum)
    }
}
