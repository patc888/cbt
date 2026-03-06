import SwiftUI

struct MoodCheckinSummaryView: View {
    @Environment(ThemeManager.self) private var themeManager
    let color: MoodColor?
    let intensity: Int
    let emotions: [String]
    let triggers: [String]
    let notes: String
    
    let onSave: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Ready to save?")
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .padding(.top, 24)
                
                DSCardContainer {
                    VStack(spacing: 24) {
                        HStack(spacing: 20) {
                            if let mood = color {
                                ZStack {
                                    Circle()
                                        .fill(mood.color(with: themeManager.selectedColor).opacity(0.15))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: mood.symbol)
                                        .font(.system(size: 32))
                                        .foregroundStyle(mood.color(with: themeManager.selectedColor))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mood.label)
                                        .font(DSTypography.pageTitle)
                                        .foregroundStyle(DSTheme.primaryText)
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "dial.low")
                                            .foregroundStyle(DSTheme.secondaryText)
                                        Text("Intensity: \(intensity)/10")
                                            .font(DSTypography.body.bold())
                                            .foregroundStyle(DSTheme.secondaryText)
                                    }
                                }
                                Spacer()
                            }
                        }
                        
                        if !emotions.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Emotions")
                                    .font(DSTypography.sectionTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(emotions, id: \.self) { emotion in
                                            TagChip(title: emotion)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if !triggers.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Triggers")
                                    .font(DSTypography.sectionTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(triggers, id: \.self) { trigger in
                                            TagChip(title: trigger)
                                        }
                                    }
                                }
                            }
                        }
                        
                        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedNotes.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Notes")
                                    .font(DSTypography.sectionTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                                
                                Text(trimmedNotes)
                                    .font(DSTypography.body)
                                    .foregroundStyle(DSTheme.secondaryText)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.large)
                
                Button(action: onSave) {
                    Text("Save Check-In")
                        .font(DSTypography.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .padding(.horizontal, DSSpacing.large)
                .padding(.bottom, DSSpacing.large)
            }
        }
    }
}
