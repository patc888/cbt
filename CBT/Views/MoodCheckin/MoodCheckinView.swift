import SwiftUI
import SwiftData

struct MoodCheckinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
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
                Theme.backgroundColor.ignoresSafeArea()
                
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
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Disable swiping so they use buttons to proceed
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                }
            }
            .navigationTitle(titleForStep)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
        withAnimation {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }
    
    private func previousStep() {
        withAnimation {
            if currentStep > 0 {
                currentStep -= 1
            }
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
            HapticManager.shared.success()
            dismiss()
        } catch {
            print("Failed to save mood entry: \(error)")
        }
    }
}

// Simple Progress Bar
private struct ProgressBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.toggleBackgroundColor(for: .light))
                    .frame(height: 6)
                
                Capsule()
                    .fill(Theme.primaryColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(value)), height: 6)
                    .animation(.spring(), value: value)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

enum MoodColor: Int, CaseIterable {
    case veryLow = 1
    case low = 2
    case neutral = 3
    case good = 4
    case great = 5
    
    var color: Color {
        switch self {
        case .veryLow: return .red
        case .low: return .orange
        case .neutral: return .yellow
        case .good: return .green
        case .great: return .blue
        }
    }
    
    var symbol: String {
        switch self {
        case .veryLow: return "face.frowning.fill"
        case .low: return "face.dashed"
        case .neutral: return "face.smiling"
        case .good: return "face.smiling.fill"
        case .great: return "star.fill"
        }
    }
    
    var label: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .neutral: return "Neutral"
        case .good: return "Good"
        case .great: return "Great"
        }
    }
}
