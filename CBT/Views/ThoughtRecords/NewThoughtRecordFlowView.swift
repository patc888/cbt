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
    private let feelingPresets = ["Anxious", "Sad", "Angry", "Overwhelmed", "Embarrassed", "Guilty", "Lonely", "Frustrated"]
    private let distortionPresets = ["All-or-Nothing Thinking", "Mind Reading", "Catastrophizing", "Overgeneralization", "Emotional Reasoning", "Labeling", "Should Statements"]
    
    @State private var showBreathing = false
    
    private var canSave: Bool {
        !situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        Text("Step \(currentStep + 1) of \(totalSteps)")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)

                        ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                            .tint(themeManager.selectedColor)
                            .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
                    }
                    .padding(.horizontal, DSSpacing.large)
                    .padding(.top, DSSpacing.large)
                    .padding(.bottom, DSSpacing.small)
                    
                    TabView(selection: $currentStep) {
                        step0View.tag(0)
                        step1View.tag(1)
                        step2View.tag(2)
                        step3View.tag(3)
                        step4View.tag(4)
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #endif
                    .animation(.easeInOut, value: currentStep)
                    
                    // Bottom Navigation
                    HStack(spacing: DSSpacing.medium) {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .buttonStyle(DSSecondaryButtonStyle())
                            .accessibilityLabel("Go back to previous step")
                        }
                        
                        Spacer()
                        
                        if currentStep < totalSteps - 1 {
                            let canProceed = currentStep != 0 || canSave
                            Button("Next") {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                            .buttonStyle(DSPrimaryButtonStyle())
                            .disabled(!canProceed)
                            .accessibilityLabel("Go to next step")
                        } else {
                            Button("Save") {
                                saveRecord()
                            }
                            .buttonStyle(DSPrimaryButtonStyle())
                            .disabled(!canSave)
                        }
                    }
                    .padding(.horizontal, DSSpacing.large)
                    .padding(.top, DSSpacing.small)
                    .padding(.bottom, DSSpacing.large)
                    .background(DSTheme.cardBackground.ignoresSafeArea(edges: .bottom))
                }
            }
            .navigationTitle("New Thought Record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showBreathing) {
                NavigationStack {
                    BreathingResetView(
                        durationSeconds: 60,
                        pattern: .box,
                        autoStart: true,
                        showsDismissControl: true,
                        showControls: true,
                        hideBackground: false,
                        onComplete: nil,
                        onDismiss: { showBreathing = false }
                    )
                }
            }
            #else
            .sheet(isPresented: $showBreathing) {
                NavigationStack {
                    BreathingResetView(
                        durationSeconds: 60,
                        pattern: .box,
                        autoStart: true,
                        showsDismissControl: true,
                        showControls: true,
                        hideBackground: false,
                        onComplete: nil,
                        onDismiss: { showBreathing = false }
                    )
                }
            }
            #endif
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
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    TextEditor(text: $situation)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
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
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    TextEditor(text: $automaticThought)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
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
                            .textFieldStyle(.plain)
                            .cbtInputSurface()
                            .onSubmit { addEmotion() }
                            .accessibilityLabel("New emotion")
                        Button(action: addEmotion) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.selectedColor)
                        }
                        .accessibilityLabel("Add emotion")
                    }

                    presetChips(
                        title: "Common feelings",
                        items: feelingPresets,
                        selections: emotions,
                        accessibilityPrefix: "Feeling",
                        toggle: toggleEmotion
                    )
                    
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
                                showBreathing = true
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
                            .textFieldStyle(.plain)
                            .cbtInputSurface()
                            .onSubmit { addDistortion() }
                            .accessibilityLabel("New distortion")
                        Button(action: addDistortion) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.selectedColor)
                        }
                        .accessibilityLabel("Add distortion")
                    }

                    presetChips(
                        title: "Common thinking traps",
                        items: distortionPresets,
                        selections: distortions,
                        accessibilityPrefix: "Thinking trap",
                        toggle: toggleDistortion
                    )
                    
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
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    TextEditor(text: $evidenceFor)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
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
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    TextEditor(text: $evidenceAgainst)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
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
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    TextEditor(text: $balancedThought)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
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
        if !clean.isEmpty, !contains(clean, in: emotions) {
            emotions.append(clean)
        }
        currentEmotion = ""
    }
    
    private func addDistortion() {
        let clean = currentDistortion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, !contains(clean, in: distortions) {
            distortions.append(clean)
        }
        currentDistortion = ""
    }

    private func toggleEmotion(_ emotion: String) {
        toggleItem(emotion, in: &emotions)
    }
    
    private func toggleDistortion(_ distortion: String) {
        toggleItem(distortion, in: &distortions)
    }
    
    private func toggleItem(_ item: String, in items: inout [String]) {
        if let index = items.firstIndex(where: { matches($0, item) }) {
            items.remove(at: index)
        } else {
            items.append(item)
        }
    }
    
    private func contains(_ item: String, in items: [String]) -> Bool {
        items.contains(where: { matches($0, item) })
    }
    
    private func matches(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
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

    @ViewBuilder
    private func presetChips(
        title: String,
        items: [String],
        selections: [String],
        accessibilityPrefix: String,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isSelected = contains(item, in: selections)
                    
                    Button {
                        toggle(item)
                    } label: {
                        EmotionChip(title: item, isSelected: isSelected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(accessibilityPrefix): \(item)")
                    .accessibilityHint(isSelected ? "Double tap to remove" : "Double tap to add")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}
