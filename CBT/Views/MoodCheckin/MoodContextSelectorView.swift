import SwiftUI

struct MoodContextSelectorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedSensations: Set<String>
    @Binding var selectedContextTags: Set<String>
    let onNext: () -> Void

    private let sensations = [
        "tight chest", "racing heart", "fatigue", "restless", "tense shoulders",
        "headache", "stomach flutter", "heavy limbs", "shaky", "calm body"
    ]

    private let contextTags = [
        "Work", "Family", "Social", "Sleep", "Health"
    ]

    var body: some View {
        MoodStepScaffold(
            title: "What else is happening?",
            subtitle: "Add body cues and broader context so your tracker feels more complete.",
            icon: "person.crop.circle.badge.questionmark",
            accent: themeManager.selectedColor,
            action: onNext
        ) {
            MoodGlassPanel(accent: themeManager.selectedColor) {
                VStack(alignment: .leading, spacing: 24) {
                    selectionSection(
                        title: "Body sensations",
                        icon: "waveform.path.ecg",
                        options: sensations,
                        selection: $selectedSensations
                    )

                    selectionSection(
                        title: "Context",
                        icon: "tag",
                        options: contextTags,
                        selection: $selectedContextTags
                    )
                }
            }
        }
    }

    private func selectionSection(
        title: String,
        icon: String,
        options: [String],
        selection: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(DSTypography.sectionTitle)
                .foregroundStyle(DSTheme.primaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(options, id: \.self) { option in
                    selectionButton(option: option, selection: selection)
                }
            }
        }
    }

    private func selectionButton(
        option: String,
        selection: Binding<Set<String>>
    ) -> some View {
        let isSelected = selection.wrappedValue.contains(option)

        return MoodSelectionChip(
            title: option,
            icon: nil,
            isSelected: isSelected,
            accent: themeManager.selectedColor
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if isSelected {
                    selection.wrappedValue.remove(option)
                } else {
                    selection.wrappedValue.insert(option)
                }
            }
        }
    }
}
