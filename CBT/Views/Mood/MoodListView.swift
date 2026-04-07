import SwiftUI
import SwiftData
import os

struct MoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \MoodEntry.createdAt,
        order: .reverse
    ) private var entries: [MoodEntry]
    
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingNewEntry = false
    @State private var attemptingNewEntry = false

    private var activeEntries: [MoodEntry] {
        entries.filter { !$0.isDeleted }
    }
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            if activeEntries.isEmpty {
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
                        attemptingNewEntry = true
                    } label: {
                        Text("Add Check-in")
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(themeManager.selectedColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(activeEntries) { entry in
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
                ListActionPillButton(
                    title: "+ Mood",
                    color: themeManager.selectedColor
                ) {
                    attemptingNewEntry = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingNewEntry) {
            MoodCheckinView()
        }
        .withUsageGate(isAttemptingAction: $attemptingNewEntry) {
            showingNewEntry = true
        }
    }
    
    private func softDelete(_ entry: MoodEntry) {
        do {
            try modelContext.cbtStore.softDelete(item: entry)
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "CBT", category: "Data").error("Failed to delete entry: \(error)")
        }
    }
}

fileprivate struct MoodEntryRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let entry: MoodEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeManager.selectedColor.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Group {
                        if let validColor = MoodColor(rawValue: entry.moodScore) {
                            validColor.iconView
                        } else {
                            Image(systemName: "face.smiling")
                        }
                    }
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
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
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.selectedColor.opacity(0.12))
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
