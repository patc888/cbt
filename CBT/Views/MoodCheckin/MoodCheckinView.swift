import SwiftUI
import SwiftData
import os

#if os(macOS)
import AppKit
#endif

struct MoodCheckinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var currentStep: Int = 0

    // Captured Data
    @State private var selectedColor: MoodColor?
    @State private var intensity: Double = 5.0
    @State private var selectedEmotions: Set<String> = []
    @State private var selectedTriggers: Set<String> = []
    @State private var selectedSensations: Set<String> = []
    @State private var selectedContextTags: Set<String> = []
    @State private var notes: String = ""

    init(initialMood: MoodColor? = nil) {
        _selectedColor = State(initialValue: initialMood)
        _currentStep = State(initialValue: initialMood == nil ? 0 : 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    MoodCheckinProgressHeader(
                        title: titleForStep,
                        step: currentStep + 1,
                        totalSteps: totalSteps,
                        accent: accentColor
                    )
                    .padding(.horizontal, DSSpacing.large)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
                    .accessibilityValue(titleForStep)

                    TabView(selection: $currentStep) {
                        MoodColorSelector(selectedColor: $selectedColor, onNext: nextStep)
                            .tag(0)

                        MoodIntensitySelector(intensity: $intensity, selectedColor: selectedColor, onNext: nextStep)
                            .tag(1)

                        EmotionSelectorView(selectedEmotions: $selectedEmotions, onNext: nextStep)
                            .tag(2)

                        MoodTriggerSelector(selectedTriggers: $selectedTriggers, onNext: nextStep)
                            .tag(3)

                        MoodContextSelectorView(
                            selectedSensations: $selectedSensations,
                            selectedContextTags: $selectedContextTags,
                            onNext: nextStep
                        )
                        .tag(4)

                        MoodNotesView(notes: $notes, onNext: nextStep)
                            .tag(5)

                        if let color = selectedColor, color.rawValue <= 2 {
                            MoodSuggestionsView(onNext: nextStep)
                                .tag(6)
                        }

                        MoodCheckinSummaryView(
                            color: selectedColor,
                            intensity: Int(intensity),
                            emotions: Array(selectedEmotions),
                            triggers: Array(selectedTriggers),
                            sensations: Array(selectedSensations),
                            contextTags: Array(selectedContextTags),
                            notes: notes,
                            onSave: saveCheckin
                        )
                        .tag(isLowMood ? 7 : 6)
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #endif
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                }
            }
            .navigationTitle(titleForStep)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    #if targetEnvironment(macCatalyst)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .accessibilityLabel("Cancel")
                    #else
                    Button("Cancel") { dismiss() }
                    #endif
                }
                if currentStep > 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation {
                                previousStep()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Previous step")
                    }
                }
            }
        }
        #if targetEnvironment(macCatalyst)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 520, idealHeight: 520)
        #endif
    }

    private var accentColor: Color {
        selectedColor?.color(with: themeManager.selectedColor) ?? themeManager.selectedColor
    }

    private var isLowMood: Bool {
        return (selectedColor?.rawValue ?? 5) <= 2
    }

    private var totalSteps: Int {
        isLowMood ? 8 : 7
    }

    private var titleForStep: String {
        switch currentStep {
        case 0: return "Mood"
        case 1: return "Intensity"
        case 2: return "Emotions"
        case 3: return "Triggers"
        case 4: return "Context"
        case 5: return "Notes"
        case 6: return isLowMood ? "Support" : "Summary"
        case 7: return "Summary"
        default: return ""
        }
    }

    private func nextStep() {
        HapticManager.shared.selection()
        guard currentStep < totalSteps - 1 else { return }
        withAnimation {
            currentStep = min(totalSteps - 1, currentStep + 1)
        }
    }

    private func previousStep() {
        HapticManager.shared.selection()
        guard currentStep > 0 else { return }
        withAnimation {
            currentStep = max(0, currentStep - 1)
        }
    }

    private func saveCheckin() {
        do {
            let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try modelContext.cbtStore.insertMoodEntry(
                moodScore: selectedColor?.rawValue ?? 3,
                emotions: Array(selectedEmotions),
                triggers: Array(selectedTriggers),
                sensations: Array(selectedSensations),
                contextTags: Array(selectedContextTags),
                notes: n.isEmpty ? nil : n,
                intensity: Int(intensity)
            )

            // Insert a MoodCheckIn record so that DailyPlanView can detect it.
            let checkin = MoodCheckIn(
                moodScore: selectedColor?.rawValue ?? 3,
                notes: n.isEmpty ? nil : n
            )
            modelContext.insert(checkin)
            try modelContext.save()
            AchievementService.shared.evaluateAchievements(in: modelContext)

            HapticManager.shared.success()
            ReviewManager.shared.logSignificantAction()
            dismiss()
        } catch {
            AppLogger.make(category: "Data").error("Failed to save mood entry: \(error.localizedDescription, privacy: .private)")
        }
    }
}

private struct ProgressBar: View {
    let value: Double
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DSTheme.separator.opacity(0.45))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.72), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * CGFloat(value)), height: 8)
                    .animation(.spring(), value: value)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

private struct MoodCheckinProgressHeader: View {
    let title: String
    let step: Int
    let totalSteps: Int
    let accent: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(DSTheme.primaryText)

                Spacer()

                Text("\(step) / \(totalSteps)")
                    .font(DSTypography.caption)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.12), in: Capsule())
            }

            ProgressBar(value: Double(step) / Double(totalSteps), accent: accent)
        }
    }
}

struct MoodStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let actionTitle: String
    let isActionEnabled: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        actionTitle: String = "Continue",
        isActionEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.actionTitle = actionTitle
        self.isActionEnabled = isActionEnabled
        self.action = action
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    MoodStepHero(title: title, subtitle: subtitle, icon: icon, accent: accent)
                        .padding(.top, 18)

                    content()

                    Button(actionTitle) {
                        action()
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(!isActionEnabled)
                    .opacity(isActionEnabled ? 1.0 : 0.48)
                    .padding(.bottom, DSSpacing.large)
                }
                .padding(.horizontal, DSSpacing.large)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height)
            }
        }
    }
}

private struct MoodStepHero: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(accent.opacity(0.22), lineWidth: 1)
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DSTypography.body)
                    .foregroundStyle(DSTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MoodGlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(DSSpacing.large)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .fill(DSTheme.cardBackground.opacity(colorScheme == .dark ? 0.82 : 0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.12), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: accent.opacity(colorScheme == .dark ? 0.16 : 0.09), radius: 22, y: 10)
    }
}

struct MoodSelectionChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.lightImpact()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 16)
                }

                Text(title)
                    .font(DSTypography.body.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isSelected ? Color.white : DSTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                    .fill(isSelected ? accent : DSTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.22) : DSTheme.separator.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? accent.opacity(0.22) : .clear, radius: 12, y: 6)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Removes \(title)" : "Adds \(title)")
    }
}
