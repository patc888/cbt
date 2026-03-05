import SwiftUI
import SwiftData

struct MoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<MoodEntry> { !$0.isDeleted },
        sort: \MoodEntry.createdAt,
        order: .reverse
    ) private var entries: [MoodEntry]
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingNewEntry = false
    
    var body: some View {
        ZStack {
            Theme.secondaryBackground.ignoresSafeArea()
            
            if entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.secondaryText)
                    Text("No mood check-ins yet.")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("Track how you feel to spot patterns.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        showingNewEntry = true
                    } label: {
                        Text("Add Check-in")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.primaryColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) {
                                MoodEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    softDelete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("")
        .navigationDestination(for: MoodEntry.self) { entry in
            MoodDetailView(entry: entry)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button {
                    HapticManager.shared.lightImpact()
                    showingNewEntry = true
                } label: {
                    Text("+ Mood")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.cardBackground)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.05 : 0), radius: colorScheme == .dark ? 2 : 0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingNewEntry) {
            MoodCheckinView()
        }
    }
    
    private func softDelete(_ entry: MoodEntry) {
        do {
            try modelContext.cbtStore.softDelete(item: entry)
        } catch {
            print("Failed to delete entry: \(error)")
        }
    }
}

fileprivate struct MoodEntryRow: View {
    let entry: MoodEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.primaryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mood Check-in")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Text("\(entry.moodScore)/10")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.primaryColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !entry.emotions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.emotions, id: \.self) { emotion in
                            TagChip(title: emotion)
                        }
                    }
                }
            }

            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
