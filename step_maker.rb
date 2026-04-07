require "fileutils"

# Steps
steps = {
  "ContextStepView" => %Q{
import SwiftUI

struct ContextStepView: View {
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
        Form {
            Section(header: Text("Context (Required)")) {
                VStack(alignment: .leading) {
                    Text("Situation")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("What happened? Who were you with? Where were you?")
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                    TextEditor(text: $viewModel.situation)
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
                    TextEditor(text: $viewModel.automaticThought)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
},
  "EmotionStepView" => %Q{
import SwiftUI

struct EmotionStepView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
        Form {
            Section(header: Text("Emotions & Intensity")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What did you feel?")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    HStack {
                        TextField("e.g. Anxious, Sad...", text: $viewModel.currentEmotion)
                            .textFieldStyle(.plain)
                            .cbtInputSurface()
                            .onSubmit { viewModel.addEmotion() }
                            .accessibilityLabel("New emotion")
                        Button(action: { viewModel.addEmotion() }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.selectedColor)
                        }
                        .accessibilityLabel("Add emotion")
                    }

                    presetChips(
                        title: "Common feelings",
                        items: viewModel.feelingPresets,
                        selections: viewModel.emotions,
                        accessibilityPrefix: "Feeling",
                        toggle: { viewModel.toggleEmotion($0) }
                    )
                    
                    if !viewModel.emotions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.emotions, id: \\.self) { emotion in
                                    HStack {
                                        Text(emotion)
                                        Button {
                                            viewModel.emotions.removeAll { $0 == emotion }
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
                    Slider(value: $viewModel.intensityBefore, in: 0...100, step: 1)
                        .accessibilityLabel("Intensity before")
                        .accessibilityValue("\\(Int(viewModel.intensityBefore)) percent")
                    Text("Intensity: \\(Int(viewModel.intensityBefore))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)

                if viewModel.intensityBefore >= 70 {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Try a 1-minute breathing reset before continuing.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.primaryText)

                            Button("Start Breathing Reset") {
                                viewModel.showBreathing = true
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
                ForEach(items, id: \\.self) { item in
                    let isSelected = viewModel.contains(item, in: selections)
                    
                    Button {
                        toggle(item)
                    } label: {
                        EmotionChip(title: item, isSelected: isSelected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\\(accessibilityPrefix): \\(item)")
                    .accessibilityHint(isSelected ? "Double tap to remove" : "Double tap to add")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}
},
  "DistortionStepView" => %Q{
import SwiftUI

struct DistortionStepView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
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
                        TextField("Add distortion...", text: $viewModel.currentDistortion)
                            .textFieldStyle(.plain)
                            .cbtInputSurface()
                            .onSubmit { viewModel.addDistortion() }
                            .accessibilityLabel("New distortion")
                        Button(action: { viewModel.addDistortion() }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.selectedColor)
                        }
                        .accessibilityLabel("Add distortion")
                    }

                    presetChips(
                        title: "Common thinking traps",
                        items: viewModel.distortionPresets,
                        selections: viewModel.distortions,
                        accessibilityPrefix: "Thinking trap",
                        toggle: { viewModel.toggleDistortion($0) }
                    )
                    
                    if !viewModel.distortions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.distortions, id: \\.self) { dist in
                                    HStack {
                                        Text(dist)
                                        Button {
                                            viewModel.distortions.removeAll { $0 == dist }
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
                ForEach(items, id: \\.self) { item in
                    let isSelected = viewModel.contains(item, in: selections)
                    
                    Button {
                        toggle(item)
                    } label: {
                        EmotionChip(title: item, isSelected: isSelected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\\(accessibilityPrefix): \\(item)")
                    .accessibilityHint(isSelected ? "Double tap to remove" : "Double tap to add")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}
},
  "EvidenceStepView" => %Q{
import SwiftUI

struct EvidenceStepView: View {
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
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
                    TextEditor(text: $viewModel.evidenceFor)
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
                    TextEditor(text: $viewModel.evidenceAgainst)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
},
  "BalancedStepView" => %Q{
import SwiftUI

struct BalancedStepView: View {
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
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
                    TextEditor(text: $viewModel.balancedThought)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .cbtInputSurface()
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("How intense is the feeling now? (0-100)")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Slider(value: $viewModel.intensityAfter, in: 0...100, step: 1)
                        .accessibilityLabel("Intensity after")
                        .accessibilityValue("\\(Int(viewModel.intensityAfter)) percent")
                    Text("Intensity: \\(Int(viewModel.intensityAfter))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)
            }
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.hidden)
    }
}
}
}

steps.each do |k, v|
  File.write("CBT/Views/ThoughtRecords/Steps/#{k}.swift", v)
end
