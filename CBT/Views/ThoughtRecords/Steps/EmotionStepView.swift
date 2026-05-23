
import SwiftUI

struct EmotionStepView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
        Form {
            Section(header: Text("Emotions & Intensity")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What did you feel?")
                        .font(.system(.headline, design: .rounded).weight(.bold))
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
                                ForEach(viewModel.emotions, id: \.self) { emotion in
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
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Slider(value: $viewModel.intensityBefore, in: 0...100, step: 1)
                        .accessibilityLabel("Intensity before")
                        .accessibilityValue("\(Int(viewModel.intensityBefore)) percent")
                    Text("Intensity: \(Int(viewModel.intensityBefore))")
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
                ForEach(items, id: \.self) { item in
                    let isSelected = viewModel.contains(item, in: selections)
                    
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
