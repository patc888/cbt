import SwiftUI
import SwiftData

struct GuidedPromptCard: Identifiable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let placeholder: String
    let icon: String
}

struct GuidedPromptFlow: Identifiable, Hashable {
    let kind: DailyCheckInKind
    let cards: [GuidedPromptCard]

    var id: String { kind.rawValue }

    var title: String { kind.title }

    var subtitle: String {
        switch kind {
        case .morningIntentions:
            return String(localized: "A quick prompt-card flow to choose how you want to meet the day.")
        case .eveningReflection:
            return String(localized: "A 2-minute flow: one win, one hard thing, one tomorrow anchor.")
        }
    }

    var icon: String {
        switch kind {
        case .morningIntentions:
            return "sun.max.fill"
        case .eveningReflection:
            return "moon.stars.fill"
        }
    }

    static func flow(for kind: DailyCheckInKind) -> GuidedPromptFlow {
        switch kind {
        case .morningIntentions:
            return GuidedPromptFlow(kind: kind, cards: [
                GuidedPromptCard(
                    id: "intention",
                    title: String(localized: "Intention"),
                    prompt: String(localized: "What is one intention you want to carry today?"),
                    placeholder: String(localized: "Today I want to..."),
                    icon: "target"
                ),
                GuidedPromptCard(
                    id: "support",
                    title: String(localized: "Support"),
                    prompt: String(localized: "What would make that intention easier to follow?"),
                    placeholder: String(localized: "I can support myself by..."),
                    icon: "hand.raised.fill"
                ),
                GuidedPromptCard(
                    id: "next_step",
                    title: String(localized: "Next Step"),
                    prompt: String(localized: "What is the smallest first step?"),
                    placeholder: String(localized: "My first step is..."),
                    icon: "arrow.forward.circle.fill"
                )
            ])
        case .eveningReflection:
            return GuidedPromptFlow(kind: kind, cards: [
                GuidedPromptCard(
                    id: "win",
                    title: String(localized: "One Win"),
                    prompt: String(localized: "What is one win from today?"),
                    placeholder: String(localized: "One win was..."),
                    icon: "checkmark.seal.fill"
                ),
                GuidedPromptCard(
                    id: "hard_thing",
                    title: String(localized: "One Hard Thing"),
                    prompt: String(localized: "What is one hard thing you carried today?"),
                    placeholder: String(localized: "One hard thing was..."),
                    icon: "heart.text.square.fill"
                ),
                GuidedPromptCard(
                    id: "tomorrow_anchor",
                    title: String(localized: "Tomorrow Anchor"),
                    prompt: String(localized: "What is one anchor for tomorrow?"),
                    placeholder: String(localized: "Tomorrow I can anchor around..."),
                    icon: "sunrise.fill"
                )
            ])
        }
    }
}

struct GuidedPromptView: View {
    let flow: GuidedPromptFlow
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \PersonalValue.createdAt) private var personalValues: [PersonalValue]
    @FocusState private var isEditorFocused: Bool

    @State private var currentIndex = 0
    @State private var responses: [String]
    @State private var dragOffset: CGSize = .zero
    @State private var isCompleted = false

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var currentResponse: String {
        guard responses.indices.contains(currentIndex) else { return "" }
        return responses[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(flow: GuidedPromptFlow, onSave: (() -> Void)? = nil) {
        self.flow = flow
        self.onSave = onSave
        self._responses = State(initialValue: Array(repeating: "", count: flow.cards.count))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                if isCompleted {
                    completionView
                } else {
                    promptContent
                }
            }
            .navigationTitle(flow.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundStyle(accent)
                }
            }
        }
    }

    private var promptContent: some View {
        VStack(spacing: 18) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ZStack {
                ForEach((0..<min(3, flow.cards.count - currentIndex)).reversed(), id: \.self) { offset in
                    let index = currentIndex + offset
                    if flow.cards.indices.contains(index) {
                        promptCard(flow.cards[index], index: index, isTop: offset == 0)
                            .offset(x: offset == 0 ? dragOffset.width : 0, y: offset == 0 ? dragOffset.height : CGFloat(offset * 14))
                            .rotationEffect(offset == 0 ? .degrees(Double(dragOffset.width / 28)) : .zero)
                            .scaleEffect(1 - CGFloat(offset) * 0.045)
                            .zIndex(Double(-offset))
                    }
                }
            }
            .frame(minHeight: 390, maxHeight: 460)
            .padding(.horizontal, 4)

            controls
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: flow.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(flow.title)
                        .font(DSTypography.sectionHeader)
                        .foregroundStyle(Theme.primaryText)
                    Text(flow.subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 6) {
                ForEach(flow.cards.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? accent : Theme.secondaryText.opacity(0.16))
                        .frame(height: 5)
                }
            }
        }
    }

    private func promptCard(_ card: GuidedPromptCard, index: Int, isTop: Bool) -> some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(card.title, systemImage: card.icon)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    Spacer()
                    Text("\(index + 1)/\(flow.cards.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Text(card.prompt)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $responses[index])
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(Theme.backgroundColor.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isEditorFocused && isTop ? accent.opacity(0.5) : Theme.secondaryText.opacity(0.12), lineWidth: 0.8)
                        )

                    if responses[index].isEmpty {
                        Text(card.placeholder)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.secondaryText.opacity(0.7))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                Text(String(localized: "Swipe the card or use Next when you're ready."))
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .gesture(isTop ? swipeGesture : nil)
        .onAppear {
            guard isTop else { return }
            isEditorFocused = true
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.lightImpact()
                goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentIndex == 0)
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(52), expands: false, tint: accent, hapticType: nil))

            Button {
                HapticManager.shared.selection()
                advanceOrSave()
            } label: {
                Label(currentIndex == flow.cards.count - 1 ? String(localized: "Save") : String(localized: "Next"), systemImage: currentIndex == flow.cards.count - 1 ? "checkmark" : "chevron.right")
            }
            .disabled(currentResponse.isEmpty)
            .buttonStyle(DSButtonStyle(variant: .primary, size: .large, tint: accent, hapticType: nil))
        }
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(accent)

            DSCardContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Saved."))
                        .font(DSTypography.cardTitle)
                        .foregroundStyle(Theme.primaryText)

                    Text(String(localized: "You don’t have to solve this right now."))
                        .font(DSTypography.body)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)

            Spacer()
            Button {
                HapticManager.shared.lightImpact()
                dismiss()
            } label: {
                Label(String(localized: "Done for now"), systemImage: "checkmark")
            }
            .buttonStyle(DSButtonStyle(variant: .primary, size: .large, tint: accent, hapticType: nil))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(reduceMotion ? .none : .interactiveSpring(response: 0.3, dampingFraction: 0.85)) {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 110
                guard abs(value.translation.width) > threshold || abs(value.translation.height) > threshold else {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                    return
                }

                advanceOrSave()
            }
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        isEditorFocused = false
        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.82)) {
            currentIndex -= 1
            dragOffset = .zero
        }
        refocusEditor()
    }

    private func advanceOrSave() {
        guard !currentResponse.isEmpty else { return }

        if currentIndex < flow.cards.count - 1 {
            isEditorFocused = false
            withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.82)) {
                currentIndex += 1
                dragOffset = .zero
            }
            refocusEditor()
        } else {
            saveEntry()
        }
    }

    private func refocusEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isEditorFocused = true
        }
    }

    private func saveEntry() {
        isEditorFocused = false
        modelContext.insert(FlexibleJournalEntry(
            templateType: flow.title,
            responses: responses,
            valueIDs: currentValueIDs
        ))
        try? modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)
        onSave?()
        withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.86)) {
            isCompleted = true
        }
    }

    private var currentValueIDs: [String] {
        guard let action = ValuesService.action(selectedValues: personalValues) else {
            return []
        }
        return [action.valueID]
    }
}

#Preview {
    GuidedPromptView(flow: .flow(for: .morningIntentions))
        .modelContainer(for: FlexibleJournalEntry.self, inMemory: true)
}
