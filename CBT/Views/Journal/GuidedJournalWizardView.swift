import SwiftUI
import SwiftData

struct JournalTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let prompts: [String]
    let icon: String
    let gradientColors: [Color]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: JournalTemplate, rhs: JournalTemplate) -> Bool {
        lhs.id == rhs.id
    }

    static let gratitude = JournalTemplate(
        id: "gratitude_reflection",
        name: "Gratitude Reflection",
        description: "Focus on the positive aspects of your day.",
        prompts: [
            "What made you smile today?",
            "Name a person you are thankful for."
        ],
        icon: "sun.max.fill",
        gradientColors: [.orange, .yellow]
    )

    static let impostorSyndrome = JournalTemplate(
        id: "impostor_syndrome_unpacker",
        name: "Impostor Syndrome Unpacker",
        description: "Examine self-doubt with objective facts.",
        prompts: [
            "What achievement are you downplaying right now?",
            "What objective, factual evidence proves you earned it?"
        ],
        icon: "brain.head.profile",
        gradientColors: [.purple, .indigo]
    )

    static let allTemplates: [JournalTemplate] = [.gratitude, .impostorSyndrome]
}

struct GuidedJournalWizardView: View {
    let template: JournalTemplate
    var onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isEditorFocused: Bool

    @State private var currentStepIndex: Int = 0
    @State private var responses: [String]
    @State private var isCompleted: Bool = false

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }
    
    private var secondaryAccent: Color {
        themeManager?.secondaryColor ?? .accentColor.opacity(0.8)
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
                    } else {
                        wizardContent
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .navigationTitle(template.name)
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
        VStack(spacing: 0) {
            progressView

            Spacer()

            VStack(spacing: 14) {
                // Step Badge
                Text("Step \(currentStepIndex + 1) of \(template.prompts.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())

                // Prompt
                Text(template.prompts[currentStepIndex])
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.primaryText)
                    .padding(.horizontal, 32)
                    .id(currentStepIndex) // Force re-render for animation
            }

            // Text Input Box
            TextEditor(text: $responses[currentStepIndex])
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(16)
                .frame(minHeight: 140, maxHeight: 200)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isEditorFocused ? accent.opacity(0.6) : Theme.secondaryText.opacity(0.12),
                            lineWidth: isEditorFocused ? 1.8 : 0.8
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
                .onAppear { isEditorFocused = true }

            Spacer()

            // Navigation Buttons
            HStack(spacing: 12) {
                if currentStepIndex > 0 {
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        isEditorFocused = false
                        currentStepIndex -= 1
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .premiumPressEffect()
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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: currentStepIndex < template.prompts.count - 1 ? "chevron.right" : "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        currentResponseTrimmed.isEmpty
                            ? accent.opacity(0.4)
                            : accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: currentResponseTrimmed.isEmpty ? Color.clear : accent.opacity(0.25), radius: 8, y: 4)
                }
                .disabled(currentResponseTrimmed.isEmpty)
                .buttonStyle(.plain)
                .premiumPressEffect()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
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

            VStack(spacing: 8) {
                Text("All Done!")
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(Theme.primaryText)

                Text("Your reflection has been saved.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: {
                HapticManager.shared.lightImpact()
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: accent.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .premiumPressEffect()
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Helpers

    private var currentResponseTrimmed: String {
        responses[currentStepIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEntry() {
        isEditorFocused = false
        let newEntry = FlexibleJournalEntry(
            templateType: template.name,
            responses: responses
        )
        modelContext.insert(newEntry)
        try? modelContext.save()
        AchievementService.shared.evaluateAchievements(in: modelContext)

        withAnimation {
            isCompleted = true
        }
        onSave?()
    }
}

#Preview {
    GuidedJournalWizardView(template: .gratitude)
        .modelContainer(for: FlexibleJournalEntry.self, inMemory: true)
}
