
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
