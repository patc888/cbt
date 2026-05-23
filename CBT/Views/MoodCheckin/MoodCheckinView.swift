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
    @State private var notes: String = ""

    init(initialMood: MoodColor? = nil) {
        _selectedColor = State(initialValue: initialMood)
        _currentStep = State(initialValue: initialMood == nil ? 0 : 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                VStack {
                    // Progress Bar
                    ProgressBar(value: Double(currentStep + 1) / Double(totalSteps))
                        .padding(.horizontal)
                        .padding(.top, 8)
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

                        MoodNotesView(notes: $notes, onNext: nextStep)
                            .tag(4)

                        if let color = selectedColor, color.rawValue <= 2 {
                            MoodSuggestionsView(onNext: nextStep)
                                .tag(5)
                        }

                        MoodCheckinSummaryView(
                            color: selectedColor,
                            intensity: Int(intensity),
                            emotions: Array(selectedEmotions),
                            triggers: Array(selectedTriggers),
                            notes: notes,
                            onSave: saveCheckin
                        )
                        .tag(isLowMood ? 6 : 5)
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

    private var isLowMood: Bool {
        return (selectedColor?.rawValue ?? 5) <= 2
    }

    private var totalSteps: Int {
        isLowMood ? 7 : 6
    }

    private var titleForStep: String {
        switch currentStep {
        case 0: return "Mood"
        case 1: return "Intensity"
        case 2: return "Emotions"
        case 3: return "Triggers"
        case 4: return "Notes"
        case 5: return isLowMood ? "Support" : "Summary"
        case 6: return "Summary"
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
                notes: n.isEmpty ? nil : n,
                intensity: Int(intensity)
            )

            // Insert a MoodCheckIn record so that DailyPlanView can detect it.
            let checkin = MoodCheckIn(
                moodScore: selectedColor?.rawValue ?? 3,
                notes: n.isEmpty ? nil : n
            )
            modelContext.insert(checkin)

            HapticManager.shared.success()
            ReviewManager.shared.logSignificantAction()
            dismiss()
        } catch {
            AppLogger.make(category: "Data").error("Failed to save mood entry: \(error.localizedDescription, privacy: .private)")
        }
    }
}

private struct ProgressBar: View {
    @Environment(ThemeManager.self) private var themeManager
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.toggleBackgroundColor(for: .light))
                    .frame(height: 6)

                Capsule()
                    .fill(themeManager.selectedColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(value)), height: 6)
                    .animation(.spring(), value: value)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
