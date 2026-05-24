import SwiftUI

struct EmotionSelectorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedEmotions: Set<String>
    let onNext: () -> Void
    
    private let emotions = [
        "Anxious", "Stressed", "Sad", "Angry", "Lonely", "Excited",
        "Happy", "Calm", "Grateful", "Frustrated", "Tired", "Overwhelmed"
    ]

    private let icons: [String: String] = [
        "Anxious": "waveform.path.ecg",
        "Stressed": "bolt",
        "Sad": "cloud.rain",
        "Angry": "flame",
        "Lonely": "person",
        "Excited": "sparkles",
        "Happy": "sun.max",
        "Calm": "leaf",
        "Grateful": "heart",
        "Frustrated": "exclamationmark.bubble",
        "Tired": "moon",
        "Overwhelmed": "square.grid.2x2"
    ]
    
    var body: some View {
        MoodStepScaffold(
            title: "What specific emotions do you feel?",
            subtitle: "Select every word that fits. Mixed feelings belong here too.",
            icon: "heart.text.square",
            accent: themeManager.selectedColor,
            action: onNext
        ) {
            MoodGlassPanel(accent: themeManager.selectedColor) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(emotions, id: \.self) { emotion in
                        let isSelected = selectedEmotions.contains(emotion)
                        
                        MoodSelectionChip(
                            title: emotion,
                            icon: icons[emotion],
                            isSelected: isSelected,
                            accent: themeManager.selectedColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if isSelected {
                                    selectedEmotions.remove(emotion)
                                } else {
                                    selectedEmotions.insert(emotion)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
