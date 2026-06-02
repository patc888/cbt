import SwiftUI

struct HelpFlow: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @State private var tree = SelfHelpDecisionTree.load()
    @State private var selectedOption: SelfHelpOption?

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                HelpFlowHeader(
                    title: selectedOption?.action.title ?? tree.prompt,
                    canGoBack: selectedOption != nil,
                    onBack: goBack
                )

                Group {
                    if let selectedOption {
                        actionView(for: selectedOption.action)
                    } else {
                        rootOptionsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Self-Help")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var rootOptionsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                Text(tree.prompt)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: DSSpacing.medium) {
                    ForEach(tree.options) { option in
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.easeInOut) {
                                selectedOption = option
                            }
                        } label: {
                            HStack(spacing: DSSpacing.medium) {
                                Image(systemName: iconName(for: option.action.type))
                                    .font(.system(size: 18, weight: .bold))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.label)
                                        .font(DSTypography.button)
                                    Text(option.action.title)
                                        .font(DSTypography.caption)
                                        .foregroundStyle(DSTheme.secondaryText)
                                }

                                Spacer(minLength: DSSpacing.small)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(DSButtonStyle(variant: .neutral, size: .large, expands: true, hapticType: nil))
                        .accessibilityLabel("\(option.label), \(option.action.title)")
                    }
                }
            }
            .dsScreenContent(maxWidth: 620, horizontalPadding: 20, bottomPadding: DSSpacing.xxLarge)
        }
    }

    @ViewBuilder
    private func actionView(for action: SelfHelpAction) -> some View {
        switch action.type {
        case .boxBreathing:
            BreathingResetView(
                durationSeconds: action.durationSeconds ?? 60,
                pattern: .box,
                autoStart: true,
                showsDismissControl: false,
                showControls: true,
                hideBackground: true,
                hideHeader: true,
                embeddedInFlow: true
            )
        case .thoughtReframing:
            HelpThoughtReframingForm(accent: accent)
        case .moodLiftPlan:
            HelpMoodLiftPlanForm(accent: accent)
        }
    }

    private func goBack() {
        HapticManager.shared.lightImpact()
        withAnimation(.easeInOut) {
            selectedOption = nil
        }
    }

    private func iconName(for actionType: SelfHelpActionType) -> String {
        switch actionType {
        case .boxBreathing: return "wind"
        case .thoughtReframing: return "brain.head.profile"
        case .moodLiftPlan: return "sun.max"
        }
    }
}

private struct HelpFlowHeader: View {
    let title: String
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        TopHeadlineView(
            title: title,
            leading: {
                if canGoBack {
                    Button {
                        onBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(DSSecondaryButtonStyle(size: .compact, expands: false))
                    .accessibilityLabel("Back")
                }
            }
        )
        .padding(.horizontal, 20)
        .padding(.bottom, DSSpacing.small)
    }
}

private struct HelpThoughtReframingForm: View {
    let accent: Color
    @State private var automaticThought = ""
    @State private var evidenceFor = ""
    @State private var evidenceAgainst = ""
    @State private var balancedThought = ""

    var body: some View {
        Form {
            Section("Thought") {
                HelpTextEditor(
                    title: "Automatic Thought",
                    prompt: "What went through your mind?",
                    text: $automaticThought,
                    minHeight: 82
                )
            }

            Section("Evidence") {
                HelpTextEditor(
                    title: "Evidence For",
                    prompt: "What facts support this thought?",
                    text: $evidenceFor,
                    minHeight: 78
                )

                HelpTextEditor(
                    title: "Evidence Against",
                    prompt: "What facts do not support it?",
                    text: $evidenceAgainst,
                    minHeight: 78
                )
            }

            Section("Reframe") {
                HelpTextEditor(
                    title: "Balanced Thought",
                    prompt: "What is a more balanced way to say this?",
                    text: $balancedThought,
                    minHeight: 96
                )
            }
        }
        .scrollContentBackground(.hidden)
        .tint(accent)
    }
}

private struct HelpMoodLiftPlanForm: View {
    let accent: Color
    @State private var selectedAction = "Step outside"
    @State private var tinyStep = ""
    @State private var supportPerson = ""

    private let actions = [
        "Step outside",
        "Text someone safe",
        "Take a shower",
        "Tidy one surface",
        "Play one song"
    ]

    var body: some View {
        Form {
            Section("Choose One Small Action") {
                Picker("Action", selection: $selectedAction) {
                    ForEach(actions, id: \.self) { action in
                        Text(action).tag(action)
                    }
                }
                #if os(iOS)
                .pickerStyle(.navigationLink)
                #endif
            }

            Section("Make It Easy") {
                HelpTextEditor(
                    title: "Tiny First Step",
                    prompt: "What is the smallest start?",
                    text: $tinyStep,
                    minHeight: 72
                )

                HelpTextEditor(
                    title: "Support",
                    prompt: "Who could you contact or be near?",
                    text: $supportPerson,
                    minHeight: 72
                )
            }

            Section {
                HStack(spacing: DSSpacing.medium) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                    Text(selectedAction)
                        .font(DSTypography.button)
                        .foregroundStyle(DSTheme.primaryText)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .tint(accent)
    }
}

private struct HelpTextEditor: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(DSTheme.primaryText)

            Text(prompt)
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)

            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .cbtInputSurface()
        }
        .padding(.vertical, 4)
    }
}

struct SelfHelpDecisionTree: Codable {
    let id: String
    let prompt: String
    let options: [SelfHelpOption]

    static func load(bundle: Bundle = .main) -> SelfHelpDecisionTree {
        guard
            let url = bundle.url(forResource: "SelfHelpDecisionTree", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let tree = try? JSONDecoder().decode(SelfHelpDecisionTree.self, from: data)
        else {
            return fallback
        }

        return tree
    }

    static let fallback = SelfHelpDecisionTree(
        id: "root",
        prompt: "How are you feeling?",
        options: [
            SelfHelpOption(
                id: "overwhelmed",
                label: "Overwhelmed",
                action: SelfHelpAction(type: .boxBreathing, title: "Box Breathing", durationSeconds: 60)
            ),
            SelfHelpOption(
                id: "anxious",
                label: "Anxious",
                action: SelfHelpAction(type: .thoughtReframing, title: "Thought Reframing", durationSeconds: nil)
            ),
            SelfHelpOption(
                id: "sad",
                label: "Sad",
                action: SelfHelpAction(type: .moodLiftPlan, title: "Mood Lift Plan", durationSeconds: nil)
            )
        ]
    )
}

struct SelfHelpOption: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let action: SelfHelpAction
}

struct SelfHelpAction: Codable, Equatable {
    let type: SelfHelpActionType
    let title: String
    let durationSeconds: Int?
}

enum SelfHelpActionType: String, Codable, Equatable {
    case boxBreathing
    case thoughtReframing
    case moodLiftPlan
}

#Preview {
    NavigationStack {
        HelpFlow()
            .environment(ThemeManager())
    }
}
