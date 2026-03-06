import SwiftUI
import SwiftData

struct NewMoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var moodScore: Int = 5
    @State private var emotions: [String] = []
    @State private var newEmotion: String = ""
    @State private var notes: String = ""
    
    init(initialMoodScore: Int? = nil) {
        if let score = initialMoodScore {
            _moodScore = State(initialValue: score)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Mood Score
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mood Score (1-10)")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            
                            Stepper(value: $moodScore, in: 1...10) {
                                Text("\(moodScore)")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Theme.primaryColor)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadiusMedium)
                        }

                        if moodScore <= 3 {
                            DSCardContainer {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Want a 1-minute breathing reset first?")
                                        .font(DSTypography.body)
                                        .foregroundStyle(DSTheme.primaryText)

                                    Button("Start Breathing Reset") {
                                        BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
                                    }
                                    .buttonStyle(DSPrimaryButtonStyle())
                                }
                            }
                        }
                        
                        // Emotions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emotions")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    TextField("Add an emotion...", text: $newEmotion)
                                        .onSubmit { addEmotion() }
                                        .submitLabel(.done)
                                    
                                    Button(action: addEmotion) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(newEmotion.isEmpty ? Theme.secondaryText : Theme.primaryColor)
                                            .font(.title2)
                                    }
                                    .disabled(newEmotion.isEmpty)
                                }
                                .padding()
                                .background(Theme.toggleBackgroundColor(for: .light)) // neutral background
                                .cornerRadius(Theme.cornerRadiusSmall)
                                
                                if !emotions.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(emotions, id: \.self) { emotion in
                                                HStack(spacing: 4) {
                                                    Text(emotion)
                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    
                                                    Button {
                                                        emotions.removeAll { $0 == emotion }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 12))
                                                    }
                                                    .foregroundStyle(Theme.secondaryText)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Theme.primaryColor.opacity(0.15))
                                                .foregroundStyle(Theme.primaryColor)
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadiusMedium)
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                                        .stroke(Theme.toggleBackgroundColor(for: .light), lineWidth: 1)
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Mood")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
    }
    
    private func addEmotion() {
        let trimmed = newEmotion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !emotions.contains(trimmed) else { return }
        emotions.append(trimmed)
        newEmotion = ""
    }
    
    private func save() {
        do {
            let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try modelContext.cbtStore.insertMoodEntry(
                moodScore: moodScore,
                emotions: emotions,
                notes: n.isEmpty ? nil : n
            )
            dismiss()
        } catch {
            print("Failed to save mood entry: \(error)")
        }
    }
}
