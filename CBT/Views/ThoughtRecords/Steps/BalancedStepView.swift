
import SwiftUI

struct BalancedStepView: View {
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
        Form {
            Section(header: Text("Balanced Thought")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("New Perspective")
                            .font(.system(.headline, design: .rounded).weight(.bold))
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
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Slider(value: $viewModel.intensityAfter, in: 0...100, step: 1)
                        .accessibilityLabel("Intensity after")
                        .accessibilityValue("\(Int(viewModel.intensityAfter)) percent")
                    Text("Intensity: \(Int(viewModel.intensityAfter))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Save this reframe for later", isOn: $viewModel.saveReframe)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.primaryText)

                    Toggle("Favorite this reframe", isOn: $viewModel.favoriteReframe)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                        .disabled(viewModel.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .onChange(of: viewModel.favoriteReframe) { _, isFavorite in
                            if isFavorite {
                                viewModel.saveReframe = true
                            }
                        }
                }
                .padding(.vertical, 4)
            }
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.hidden)
    }
}
