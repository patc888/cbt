import SwiftUI

struct MoodActivitySelectorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedActivityTags: Set<String>
    let onNext: () -> Void

    private let activityTags = [
        "Sleep", "Exercise", "Work", "School", "Social",
        "Family", "Dating", "Food", "Caffeine", "Alcohol",
        "Outdoors", "Screen Time", "Conflict", "Chores", "Rest",
        "Therapy", "Medication", "Meditation", "Travel", "Finances"
    ]

    private let icons: [String: String] = [
        "Sleep": "bed.double",
        "Exercise": "figure.walk",
        "Work": "briefcase",
        "School": "book.closed",
        "Social": "bubble.left.and.bubble.right",
        "Family": "person.2",
        "Dating": "heart",
        "Food": "fork.knife",
        "Caffeine": "cup.and.saucer",
        "Alcohol": "wineglass",
        "Outdoors": "tree",
        "Screen Time": "display",
        "Conflict": "exclamationmark.bubble",
        "Chores": "checkmark.circle",
        "Rest": "pause.circle",
        "Therapy": "cross.case",
        "Medication": "pills",
        "Meditation": "sparkles",
        "Travel": "airplane",
        "Finances": "creditcard"
    ]

    var body: some View {
        MoodStepScaffold(
            title: "What was part of your day?",
            subtitle: "Tap any activity tags that fit. Leaving this blank is okay.",
            icon: "square.grid.2x2",
            accent: themeManager.selectedColor,
            action: onNext
        ) {
            MoodGlassPanel(accent: themeManager.selectedColor) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach(activityTags, id: \.self) { tag in
                        let isSelected = selectedActivityTags.contains(tag)

                        MoodSelectionChip(
                            title: tag,
                            icon: icons[tag],
                            isSelected: isSelected,
                            accent: themeManager.selectedColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if isSelected {
                                    selectedActivityTags.remove(tag)
                                } else {
                                    selectedActivityTags.insert(tag)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
