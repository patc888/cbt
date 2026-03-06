import SwiftUI
import SwiftData

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
                    
                    // Emtions
                    if !entry.emotions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emotions")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(entry.emotions, id: \.self) { emotion in
                                        TagChip(title: emotion)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusMedium)
                    }
                    
                    // Notes
                    if let notes = entry.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)
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
        do {
            try modelContext.cbtStore.softDelete(item: entry)
            dismiss()
        } catch {
            print("Failed to delete entry: \(error)")
        }
    }
}
