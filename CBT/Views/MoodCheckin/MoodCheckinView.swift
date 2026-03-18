import SwiftUI
import SwiftData

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
                    #if os(iOS)
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
                    #else
                    ToolbarItem {
                        Button {
                            withAnimation {
                                previousStep()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Previous step")
                    }
                    #endif
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
            ReviewManager.shared.logSignificantAction()
            dismiss()
        } catch {
            print("Failed to save mood entry: \(error)")
        }
    }
}

// Simple Progress Bar
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

enum MoodColor: Int, CaseIterable {
    case veryLow = 1
    case low = 2
    case neutral = 3
    case good = 4
    case great = 5
    
    func color(with themeColor: Color) -> Color {
        switch self {
        case .veryLow:
            #if os(macOS) || targetEnvironment(macCatalyst)
            // macOS can make low-opacity monochrome SF Symbols look "blank".
            return themeColor.opacity(0.55)
            #else
            return themeColor.opacity(0.3)
            #endif
        case .low:
            #if os(macOS) || targetEnvironment(macCatalyst)
            return themeColor.opacity(0.65)
            #else
            return themeColor.opacity(0.45)
            #endif
        case .neutral: return themeColor.opacity(0.6)
        case .good: return themeColor.opacity(0.8)
        case .great: return themeColor
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        ZStack {
            switch self {
            case .veryLow:
                #if os(macOS) || targetEnvironment(macCatalyst)
                Image(systemName: MoodColor.frownSymbolName(isFilled: false))
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #else
                Text("\u{2639}\u{FE0E}")
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #endif
            case .low:
                #if os(macOS) || targetEnvironment(macCatalyst)
                Image(systemName: MoodColor.frownSymbolName(isFilled: true))
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #else
                Text("\u{2639}\u{FE0E}")
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #endif
            case .neutral:
                Image(systemName: "face.smiling")
            case .good:
                Image(systemName: "face.smiling")
            case .great:
                Image(systemName: "face.smiling.fill")
            }
        }
    }

    private static func frownSymbolName(isFilled: Bool) -> String {
        // SF Symbols face variants differ across OS versions / SF Symbols packs.
        // Use availability checks so we don't end up with blank icons.
        let outlineCandidates: [String] = [
            "face.dashed",
            "face.meh",
            "face.sad",
            "face.frowning",
            "face.frown",
            "face.smiling.inverse",
            "face.angry",
        ]

        let filledCandidates: [String] = [
            "face.dashed.fill",
            "face.meh.fill",
            "face.sad.fill",
            "face.frowning.fill",
            "face.frown.fill",
            "face.smiling.inverse.fill",
            "face.angry.fill",
        ]

        let candidates = isFilled ? filledCandidates : outlineCandidates

        return candidates.first(where: { isSFIconAvailable($0) })
            ?? (isFilled ? "face.smiling.fill" : "face.smiling")
    }

    private static func isSFIconAvailable(_ name: String) -> Bool {
        #if os(macOS)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #else
        return UIImage(systemName: name) != nil
        #endif
    }

    // Maintained for backward compatibility if needed elsewhere
    var symbol: String {
        switch self {
        case .veryLow: return "face.smiling"
        case .low: return "face.smiling.fill"
        case .neutral: return "face.smiling"
        case .good: return "face.smiling"
        case .great: return "face.smiling.fill"
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
