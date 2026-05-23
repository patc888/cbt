
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
                            .font(.system(.headline, design: .rounded).weight(.bold))
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
                                ForEach(viewModel.distortions, id: \.self) { dist in
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
