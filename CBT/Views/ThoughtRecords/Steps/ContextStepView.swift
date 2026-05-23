
import SwiftUI

struct ContextStepView: View {
    @Bindable var viewModel: NewThoughtRecordViewModel

    var body: some View {
        Form {
            Section(header: Text("Context (Required)")) {
                VStack(alignment: .leading) {
                    Text("Situation")
                        .font(.system(.headline, design: .rounded).weight(.bold))
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
                            .font(.system(.headline, design: .rounded).weight(.bold))
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
