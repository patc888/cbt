import SwiftUI

struct MoodCheckinSummaryView: View {
    @Environment(ThemeManager.self) private var themeManager
    let color: MoodColor?
    let intensity: Int
    let emotions: [String]
    let triggers: [String]
    let sensations: [String]
    let contextTags: [String]
    let notes: String
    
    let onSave: () -> Void
    
    var body: some View {
        let accent = color?.color(with: themeManager.selectedColor) ?? themeManager.selectedColor

        MoodStepScaffold(
            title: "Ready to save?",
            subtitle: "Here is the shape of this moment before it joins your mood history.",
            icon: "checkmark.seal",
            accent: accent,
            actionTitle: "Save Check-In",
            action: onSave
        ) {
            MoodGlassPanel(accent: accent) {
                VStack(spacing: 24) {
                    if let mood = color {
                        HStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.14))
                                    .frame(width: 96, height: 96)
                                    .overlay(Circle().stroke(accent.opacity(0.22), lineWidth: 1))
                                
                                mood.iconView
                                    .font(.system(size: 48))
                                    .foregroundStyle(accent)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mood.label)
                                    .font(DSTypography.pageTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                
                                Label("Intensity: \(intensity)/10", systemImage: "dial.low")
                                    .font(DSTypography.body.bold())
                                    .foregroundStyle(DSTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                        
                    if !emotions.isEmpty {
                        SummaryChipSection(title: "Emotions", icon: "heart.text.square", items: emotions, accent: accent)
                    }
                        
                    if !triggers.isEmpty {
                        SummaryChipSection(title: "Triggers", icon: "arrow.triangle.branch", items: triggers, accent: accent)
                    }

                    if !sensations.isEmpty {
                        SummaryChipSection(title: "Sensations", icon: "waveform.path.ecg", items: sensations, accent: accent)
                    }

                    if !contextTags.isEmpty {
                        SummaryChipSection(title: "Context", icon: "tag", items: contextTags, accent: accent)
                    }
                        
                    let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedNotes.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notes", systemImage: "square.and.pencil")
                                .font(DSTypography.sectionTitle)
                                .foregroundStyle(DSTheme.primaryText)
                            
                            Text(trimmedNotes)
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.secondaryText)
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                                        .fill(DSTheme.elevatedFill.opacity(0.42))
                                )
                        }
                    }
                }
            }
        }
    }
}

private struct SummaryChipSection: View {
    let title: String
    let icon: String
    let items: [String]
    let accent: Color

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(DSTypography.sectionTitle)
                .foregroundStyle(DSTheme.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        TagChip(title: item)
                            .background(accent.opacity(0.001))
                    }
                }
            }
        }
    }
}
