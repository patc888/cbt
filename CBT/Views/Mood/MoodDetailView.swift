import SwiftUI
import SwiftData
import os

struct MoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    let entry: MoodEntry
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header: Score
                    VStack(spacing: 8) {
                        Text("\(entry.moodScore)")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.selectedColor)
                        
                        Text("Score")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.top, 24)
                    
                    if let intensity = entry.intensity {
                        MoodDetailMetricSection(
                            title: "Intensity",
                            value: "\(intensity)/10",
                            systemImage: "dial.low"
                        )
                    }

                    MoodDetailChipSection(title: "Emotions", items: entry.emotions)
                    MoodDetailChipSection(title: "Triggers", items: entry.triggers)
                    MoodDetailChipSection(title: "Activities", items: entry.activityTags)
                    MoodDetailChipSection(title: "Sensations", items: entry.sensations)
                    MoodDetailChipSection(title: "Context", items: entry.contextTags)
                    
                    // Notes
                    if let notes = entry.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                            
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(Theme.primaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusMedium)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(Theme.errorRed)
            }
        }
#else
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
#endif
        .alert("Delete Mood Check-in", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("Are you sure you want to delete this mood check-in?")
        }
    }
    
    private func deleteEntry() {
        HapticManager.shared.destructiveAction()
        do {
            try modelContext.cbtStore.softDelete(item: entry)
            dismiss()
        } catch {
            AppLogger.make(category: "Data").error("Failed to delete entry: \(error.localizedDescription, privacy: .private)")
        }
    }
}

private struct MoodDetailMetricSection: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 24)

            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Spacer()

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadiusMedium)
    }
}

private struct MoodDetailChipSection: View {
    let title: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            TagChip(title: item)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusMedium)
        }
    }
}
