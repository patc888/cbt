import SwiftUI

struct MoodTriggerSelector: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedTriggers: Set<String>
    let onNext: () -> Void
    
    private let triggers = [
        "Work", "Family", "Health", "Sleep", "Social",
        "Finances", "Weather", "News", "Exercise", "Food", "Nothing specific"
    ]

    private let icons: [String: String] = [
        "Work": "briefcase",
        "Family": "person.2",
        "Health": "cross.case",
        "Sleep": "bed.double",
        "Social": "bubble.left.and.bubble.right",
        "Finances": "creditcard",
        "Weather": "cloud.sun",
        "News": "newspaper",
        "Exercise": "figure.walk",
        "Food": "fork.knife",
        "Nothing specific": "circle"
    ]
    
    var body: some View {
        MoodStepScaffold(
            title: "What influenced this mood?",
            subtitle: "Capture the context around the feeling. It helps patterns stand out later.",
            icon: "arrow.triangle.branch",
            accent: themeManager.selectedColor,
            action: onNext
        ) {
            MoodGlassPanel(accent: themeManager.selectedColor) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach(triggers, id: \.self) { trigger in
                        let isSelected = selectedTriggers.contains(trigger)
                        
                        MoodSelectionChip(
                            title: trigger,
                            icon: icons[trigger],
                            isSelected: isSelected,
                            accent: themeManager.selectedColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if trigger == "Nothing specific" {
                                    if isSelected {
                                        selectedTriggers.remove(trigger)
                                    } else {
                                        selectedTriggers.removeAll()
                                        selectedTriggers.insert(trigger)
                                    }
                                } else {
                                    if isSelected {
                                        selectedTriggers.remove(trigger)
                                    } else {
                                        selectedTriggers.remove("Nothing specific")
                                        selectedTriggers.insert(trigger)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
