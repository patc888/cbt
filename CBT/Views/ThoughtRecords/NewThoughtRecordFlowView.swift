import SwiftUI
import SwiftData

struct NewThoughtRecordFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    // Step 0: Situation & Auto Thought
    @State private var situation = ""
    @State private var automaticThought = ""
    
    // Step 1: Emotion & Intensity Before
    @State private var emotions: [String] = []
    @State private var currentEmotion = ""
    @State private var intensityBefore: Double = 50.0
    
    // Step 2: Distortions
    @State private var distortions: [String] = []
    @State private var currentDistortion = ""
    
    // Step 3: Evidence
    @State private var evidenceFor = ""
    @State private var evidenceAgainst = ""
    
    // Step 4: Balanced Thought & Intensity After
    @State private var balancedThought = ""
    @State private var intensityAfter: Double = 50.0
    
    @State private var currentStep = 0
    private let totalSteps = 5
    
    private var canSave: Bool {
        !situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Progress Header
                    ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                        .tint(themeManager.selectedColor)
                        .padding()
                        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
                    
                    TabView(selection: $currentStep) {
                        step0View.tag(0)
                        step1View.tag(1)
                        step2View.tag(2)
                        step3View.tag(3)
                        step4View.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                    
                    // Bottom Navigation
                    HStack {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .foregroundColor(themeManager.selectedColor)
                            .padding()
                            .accessibilityLabel("Go back to previous step")
                        } else {
                            Spacer().frame(width: 60)
                        }
                        
                        Spacer()
                        
                        if currentStep < totalSteps - 1 {
                            Button("Next") {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(themeManager.selectedColor)
                            .clipShape(Capsule())
                            .padding()
                            .accessibilityLabel("Go to next step")
                        } else {
                            Button("Save") {
                                saveRecord()
                            }
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(canSave ? themeManager.selectedColor : Color.gray)
                            .clipShape(Capsule())
                            .padding()
                            .disabled(!canSave)
                        }
                    }
                    .background(Theme.cardBackground.ignoresSafeArea(edges: .bottom))
                }
            }
            .navigationTitle("New Thought Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Steps
    
    private var step0View: some View {
        Form {
            Section(header: Text("Context (Required)")) {
                VStack(alignment: .leading) {
                    Text("Situation")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("What happened? Who were you with? Where were you?")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    TextEditor(text: $situation)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Automatic Thought")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        ContextualHelpButton(
                            title: "Automatic Thoughts",
                            message: "These are quick, reflexive thoughts that pop into your mind in response to a situation. They often feel like facts, but they can be biased or unhelpful."
                        )
                    }
                    Text("What went through your mind right before you felt this way?")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    TextEditor(text: $automaticThought)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private var step1View: some View {
        Form {
            Section(header: Text("Emotions & Intensity")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What did you feel?")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    HStack {
                        TextField("e.g. Anxious, Sad...", text: $currentEmotion)
                            .onSubmit { addEmotion() }
                            .accessibilityLabel("New emotion")
                        Button(action: addEmotion) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.selectedColor)
                        }
                        .accessibilityLabel("Add emotion")
                    }
                    
                    if !emotions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(emotions, id: \.self) { emotion in
                                    HStack {
                                        Text(emotion)
                                        Button {
                                            emotions.removeAll { $0 == emotion }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.toggleBackgroundColor(for: .light))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("How intense was the feeling? (0-100)")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Slider(value: $intensityBefore, in: 0...100, step: 1)
                        .accessibilityLabel("Intensity before")
                        .accessibilityValue("\(Int(intensityBefore)) percent")
                    Text("Intensity: \(Int(intensityBefore))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)

                if intensityBefore >= 70 {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Try a 1-minute breathing reset before continuing.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.primaryText)

                            Button("Start Breathing Reset") {
                                BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
                            }
                            .buttonStyle(DSPrimaryButtonStyle())
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private var step2View: some View {
        Form {
            Section(header: Text("Cognitive Distortions")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Any thinking traps?")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        ContextualHelpButton(
                            title: "Cognitive Distortions",
                            message: "Thinking traps are biased ways of looking at situations. Common ones include 'Catastrophizing' (expecting the worst) or 'Mind Reading' (assuming you know what others think)."
                        )
                    }
                    Text("e.g. All-or-nothing, Mind Reading, Catastrophizing")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    
                    HStack {
                        TextField("Add distortion...", text: $currentDistortion)
                            .onSubmit { addDistortion() }
                            .accessibilityLabel("New distortion")
                        Button(action: addDistortion) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.selectedColor)
                        }
                        .accessibilityLabel("Add distortion")
                    }
                    
                    if !distortions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(distortions, id: \.self) { dist in
                                    HStack {
                                        Text(dist)
                                        Button {
                                            distortions.removeAll { $0 == dist }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.toggleBackgroundColor(for: .light))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private var step3View: some View {
        Form {
            Section(header: Text("Evidence")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Evidence For")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        ContextualHelpButton(
                            title: "Evidence For",
                            message: "List objective facts that support your automatic thought. Avoid including interpretations or feelings; stick to what a video camera would record."
                        )
                    }
                    Text("What facts support your automatic thought?")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    TextEditor(text: $evidenceFor)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Evidence Against")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        ContextualHelpButton(
                            title: "Evidence Against",
                            message: "List facts that contradict or weaken your automatic thought. Look for exceptions or other pieces of information you might be overlooking."
                        )
                    }
                    Text("What facts do not support your automatic thought?")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    TextEditor(text: $evidenceAgainst)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private var step4View: some View {
        Form {
            Section(header: Text("Balanced Thought")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("New Perspective")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        ContextualHelpButton(
                            title: "Balanced Thoughts",
                            message: "A balanced thought takes both sides of the evidence into account. It's not just 'positive thinking'—it's more realistic and grounded in facts."
                        )
                    }
                    Text("Based on the evidence, what is a more balanced way to look at this?")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    TextEditor(text: $balancedThought)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("How intense is the feeling now? (0-100)")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Slider(value: $intensityAfter, in: 0...100, step: 1)
                        .accessibilityLabel("Intensity after")
                        .accessibilityValue("\(Int(intensityAfter)) percent")
                    Text("Intensity: \(Int(intensityAfter))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)
            }
            .padding(.bottom, 60) // Extra padding for the bottom bar visibility
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Actions
    
    private func addEmotion() {
        let clean = currentEmotion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, !emotions.contains(clean) {
            emotions.append(clean)
        }
        currentEmotion = ""
    }
    
    private func addDistortion() {
        let clean = currentDistortion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, !distortions.contains(clean) {
            distortions.append(clean)
        }
        currentDistortion = ""
    }
    
    private func saveRecord() {
        guard canSave else { return }
        
        do {
            try modelContext.cbtStore.insertThoughtRecord(
                situation: situation,
                automaticThought: automaticThought,
                emotions: emotions,
                distortions: distortions,
                evidenceFor: evidenceFor,
                evidenceAgainst: evidenceAgainst,
                balancedThought: balancedThought,
                intensityBefore: Int(intensityBefore),
                intensityAfter: Int(intensityAfter)
            )
            dismiss()
        } catch {
            print("Failed to save thought record: \(error)")
        }
    }
}
