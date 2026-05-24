import SwiftUI
import SwiftData
import os

struct MoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @State private var entries: [MoodEntry] = []
    @State private var showingNewEntry = false
    @State private var attemptingNewEntry = false


    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            if entries.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "face.smiling",
                    title: "Mood Check-Ins",
                    message: "Mood check-ins are quick snapshots of how you feel, so patterns can become easier to notice later.",
                    actionTitle: "Add Check-In",
                    actionSystemImage: "plus.circle.fill"
                ) {
                    HapticManager.shared.lightImpact()
                    attemptingNewEntry = true
                }
                .padding(.horizontal, 24)
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
            if !entries.isEmpty {
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
        }
        .sheet(isPresented: $showingNewEntry) {
            MoodCheckinView()
        }
        .withUsageGate(isAttemptingAction: $attemptingNewEntry) {
            showingNewEntry = true
        }
        .task {
            await refreshEntries()
        }
        .onChange(of: showingNewEntry) { _, isPresented in
            guard !isPresented else { return }
            Task { await refreshEntries() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshEntries() }
        }
    }
    
    @MainActor
    private func refreshEntries() async {
        entries = LaunchSafeFetch.moodEntries(from: modelContext)
    }

    private func softDelete(_ entry: MoodEntry) {
        do {
            try modelContext.cbtStore.softDelete(item: entry)
            Task { await refreshEntries() }
        } catch {
            AppLogger.make(category: "Data").error("Failed to delete entry: \(error.localizedDescription, privacy: .private)")
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

            let visibleTags = entry.emotions + entry.activityTags
            if !visibleTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(visibleTags, id: \.self) { tag in
                            TagChip(title: tag)
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
