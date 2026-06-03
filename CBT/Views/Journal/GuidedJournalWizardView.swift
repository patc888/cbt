import SwiftUI
import SwiftData

struct GuidedJournalWizardView: View {
    let template: JournalTemplate
    var onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \PersonalValue.createdAt) private var personalValues: [PersonalValue]
    @FocusState private var isEditorFocused: Bool

    @State private var currentStepIndex: Int = 0
    @State private var responses: [String]
    @State private var isCompleted: Bool = false
    @State private var showingReset = false

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }
    
    private var secondaryAccent: Color {
        themeManager?.secondaryColor ?? .accentColor.opacity(0.8)
    }

    private var currentStep: JournalPromptStep? {
        guard template.prompts.indices.contains(currentStepIndex) else { return nil }
        return template.prompts[currentStepIndex]
    }

    private var hasPrompts: Bool {
        !template.prompts.isEmpty && responses.indices.contains(currentStepIndex)
    }

    init(template: JournalTemplate, onSave: (() -> Void)? = nil) {
        self.template = template
        self.onSave = onSave
        self._responses = State(initialValue: Array(repeating: "", count: template.prompts.count))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                VStack(spacing: 24) {
                    if isCompleted {
                        completionView
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if !hasPrompts {
                        emptyTemplateView
                    } else {
                        wizardContent
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .navigationTitle(template.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundStyle(accent)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentStepIndex)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isCompleted)
            .sheet(isPresented: $showingReset) {
                NavigationStack {
                    BreathingResetView(
                        durationSeconds: 60,
                        pattern: .box,
                        autoStart: true,
                        showsDismissControl: true,
                        showControls: true,
                        hideBackground: false,
                        onComplete: nil,
                        onDismiss: { showingReset = false }
                    )
                }
                .dsSheetPresentation()
            }
        }
    }

    // MARK: - Progress Bar

    private var progressView: some View {
        HStack(spacing: 6) {
            ForEach(0..<template.prompts.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStepIndex ? accent : Theme.secondaryText.opacity(0.15))
                    .frame(height: 5)
                    .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Wizard Step

    private var wizardContent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    progressView

                    promptBlock
                        .padding(.top, 28)

                    editorBlock
                        .padding(.top, 24)

                    Spacer(minLength: 24)

                    wizardNavigationButtons
                        .padding(.top, 12)

                    notReadyActions
                        .padding(.top, 2)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var promptBlock: some View {
        VStack(spacing: 14) {
            Text("Step \(currentStepIndex + 1) of \(template.prompts.count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .textCase(.uppercase)
                .tracking(1.5)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(accent.opacity(0.12))
                .clipShape(Capsule())

            if let stepTitle = currentStep?.title,
               !stepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(stepTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(currentStep?.text ?? "")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .id(currentStepIndex)

            if let helperText = currentStep?.helperText ?? template.helperText,
               !helperText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(helperText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }
        }
    }

    private var editorBlock: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $responses[currentStepIndex])
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(16)
                .frame(minHeight: 140, maxHeight: 220)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isEditorFocused ? accent.opacity(0.6) : Theme.secondaryText.opacity(0.12),
                            lineWidth: isEditorFocused ? 1.8 : 0.8
                        )
                )

            if responses[currentStepIndex].isEmpty,
               let placeholder = currentStep?.placeholder,
               !placeholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
        .onAppear { isEditorFocused = true }
    }

    private var wizardNavigationButtons: some View {
        HStack(spacing: 12) {
            if currentStepIndex > 0 {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    isEditorFocused = false
                    currentStepIndex -= 1
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, tint: accent, hapticType: nil))
            }

            Button(action: {
                if currentStepIndex < template.prompts.count - 1 {
                    HapticManager.shared.selection()
                    isEditorFocused = false
                    currentStepIndex += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isEditorFocused = true
                    }
                } else {
                    HapticManager.shared.success()
                    saveEntry()
                }
            }) {
                HStack(spacing: 6) {
                    Text(currentStepIndex < template.prompts.count - 1 ? "Next" : "Save")
                    Image(systemName: currentStepIndex < template.prompts.count - 1 ? "chevron.right" : "checkmark")
                }
            }
            .disabled(currentResponseTrimmed.isEmpty)
            .buttonStyle(DSButtonStyle(variant: .primary, tint: accent, hapticType: nil))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var notReadyActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                notReadyButtons
            }

            VStack(spacing: 10) {
                notReadyButtons
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var notReadyButtons: some View {
        Button {
            skipDetails()
        } label: {
            Label("Skip details", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: accent, hapticType: nil))

        Button {
            HapticManager.shared.lightImpact()
            showingReset = true
        } label: {
            Label("Do a 60-second reset instead", systemImage: "wind")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: accent, hapticType: nil))

        Button {
            HapticManager.shared.lightImpact()
            dismiss()
        } label: {
            Label("Come back later", systemImage: "clock")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: accent, hapticType: nil))
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: template.gradientColors.map { $0.opacity(0.25) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: template.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }

            DSCardContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved.")
                        .font(DSTypography.cardTitle)
                        .foregroundStyle(Theme.primaryText)

                    Text("You don’t have to solve this right now.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: {
                HapticManager.shared.lightImpact()
                dismiss()
            }) {
                Label("Done for now", systemImage: "checkmark")
            }
            .buttonStyle(DSButtonStyle(variant: .primary, tint: accent, hapticType: nil))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var emptyTemplateView: some View {
        SupportiveEmptyStateView(
            systemImage: "pencil.and.list.clipboard",
            title: "Template Unavailable",
            message: "Close this template and choose another guided prompt to keep the reflection moving.",
            actionTitle: "Close",
            actionSystemImage: "xmark"
        ) {
            HapticManager.shared.lightImpact()
            dismiss()
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var currentResponseTrimmed: String {
        guard responses.indices.contains(currentStepIndex) else { return "" }
        return responses[currentStepIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEntry() {
        isEditorFocused = false
        let newEntry = FlexibleJournalEntry(
            templateType: template.storageKey,
            responses: responses,
            valueIDs: currentValueIDs
        )
        modelContext.insert(newEntry)
        try? modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)

        withAnimation {
            isCompleted = true
        }
        onSave?()
    }

    private func skipDetails() {
        isEditorFocused = false
        guard responses.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            HapticManager.shared.lightImpact()
            dismiss()
            return
        }

        HapticManager.shared.success()
        saveEntry()
    }

    private var currentValueIDs: [String] {
        guard let action = ValuesService.action(selectedValues: personalValues) else {
            return []
        }
        return [action.valueID]
    }
}

#Preview {
    GuidedJournalWizardView(template: .allTemplates.first ?? .preview)
        .modelContainer(for: FlexibleJournalEntry.self, inMemory: true)
}
