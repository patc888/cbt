import SwiftUI

struct IntroEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedStep: CBTLoopStep = .thought
    @State private var revealedTruths: Set<CBTTruth> = []
    
    var body: some View {
        PagerLayout(
            title: "What is CBT?",
            subtitle: "A practical, evidence-based way to understand your mind and build steadier responses."
        ) {
            VStack(spacing: 18) {
                heroCard
                loopExplorer
                quickWinsGrid
                truthCards
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(0.95),
                            themeManager.selectedColor.opacity(0.62),
                            Color.cyan.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }

            Image(systemName: "sparkles")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.white.opacity(0.18))
                .offset(x: -18, y: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Label("Mind skills, not mind reading", systemImage: "brain.head.profile")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }

                Text("CBT helps you catch the moment between what happens and what you do next.")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You learn to notice automatic thoughts, test them against evidence, and choose responses that match your values instead of your alarm system.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .shadow(color: themeManager.selectedColor.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private var loopExplorer: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tap the CBT loop")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Text("\(selectedStep.index)/4")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(themeManager.selectedColor)
                }

                HStack(spacing: 10) {
                    ForEach(CBTLoopStep.allCases) { step in
                        Button {
                            HapticManager.shared.trigger(.selection)
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                                selectedStep = step
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: step.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .frame(width: 42, height: 42)
                                    .background(selectedStep == step ? themeManager.selectedColor : themeManager.selectedColor.opacity(0.10))
                                    .foregroundStyle(selectedStep == step ? .white : themeManager.selectedColor)
                                    .clipShape(Circle())

                                Text(step.title)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(selectedStep == step ? Theme.primaryText : Theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedStep.prompt)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text(selectedStep.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.selectedColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var quickWinsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 12)], spacing: 12) {
            MiniBenefitCard(icon: "magnifyingglass", title: "Spot patterns", text: "Name recurring thoughts before they run the show.")
            MiniBenefitCard(icon: "scalemass", title: "Check facts", text: "Separate feelings, guesses, and evidence.")
            MiniBenefitCard(icon: "figure.walk.motion", title: "Try actions", text: "Use tiny experiments to shift your day.")
            MiniBenefitCard(icon: "chart.line.uptrend.xyaxis", title: "Build proof", text: "Track what helps, then repeat it.")
        }
    }

    private var truthCards: some View {
        VStack(spacing: 10) {
            ForEach(CBTTruth.allCases) { truth in
                Button {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        if revealedTruths.contains(truth) {
                            revealedTruths.remove(truth)
                        } else {
                            revealedTruths.insert(truth)
                        }
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: revealedTruths.contains(truth) ? "checkmark.seal.fill" : "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.selectedColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(truth.myth)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            if revealedTruths.contains(truth) {
                                Text(truth.reframe)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DSTheme.separator.opacity(0.18), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum CBTLoopStep: String, CaseIterable, Identifiable {
    case situation
    case thought
    case feeling
    case response

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .situation: return 1
        case .thought: return 2
        case .feeling: return 3
        case .response: return 4
        }
    }

    var icon: String {
        switch self {
        case .situation: return "bolt.fill"
        case .thought: return "bubble.left.and.bubble.right.fill"
        case .feeling: return "heart.fill"
        case .response: return "arrow.triangle.branch"
        }
    }

    var title: String {
        switch self {
        case .situation: return "Event"
        case .thought: return "Thought"
        case .feeling: return "Feeling"
        case .response: return "Response"
        }
    }

    var prompt: String {
        switch self {
        case .situation: return "What happened?"
        case .thought: return "What did your mind say it meant?"
        case .feeling: return "What showed up in your body?"
        case .response: return "What could you do on purpose?"
        }
    }

    var description: String {
        switch self {
        case .situation:
            return "Start with observable facts: who, what, where, and when. Clean facts give you a stable place to stand."
        case .thought:
            return "Catch the automatic story. CBT does not ask you to force positivity; it asks you to investigate accuracy."
        case .feeling:
            return "Emotions carry information, but they are not court verdicts. Rating intensity helps you see movement over time."
        case .response:
            return "Choose a next step: breathe, gather evidence, talk kindly to yourself, or test the thought with a small action."
        }
    }
}

private enum CBTTruth: String, CaseIterable, Identifiable {
    case positivity
    case past
    case quickFix

    var id: String { rawValue }

    var myth: String {
        switch self {
        case .positivity: return "Is CBT just positive thinking?"
        case .past: return "Does CBT ignore your past?"
        case .quickFix: return "Should it work instantly?"
        }
    }

    var reframe: String {
        switch self {
        case .positivity:
            return "No. It is balanced thinking: looking for the full picture, including hard facts and helpful facts."
        case .past:
            return "No. Your history matters. CBT focuses on the patterns that are active today so you can change what happens next."
        case .quickFix:
            return "It is a practice. Small repetitions teach your brain new routes, the same way physical training builds strength."
        }
    }
}

private struct MiniBenefitCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 32, height: 32)
                .background(themeManager.selectedColor.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DSTheme.separator.opacity(0.18), lineWidth: 0.8)
        }
    }
}
