import SwiftUI
import SwiftData
import os

struct ThoughtRecordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @State private var records: [ThoughtRecord] = []
    @State private var showingNewRecord = false
    @State private var attemptingNewRecord = false

    private var recentReframes: [ThoughtRecord] {
        records
            .filter {
                !$0.displayReframe.isEmpty &&
                ($0.isSavedReframe || $0.isFavoriteReframe || $0.isComplete)
            }
            .prefix(5)
            .map { $0 }
    }

    private var favoriteReframes: [ThoughtRecord] {
        records.filter { $0.isFavoriteReframe && !$0.displayReframe.isEmpty }
    }

    private var dueReframeFollowUps: [ThoughtRecord] {
        records.filter { $0.isReframeFollowUpDue() }
    }

    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            if records.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "brain.head.profile",
                    title: "Thought Records",
                    message: "Try a guided thought record for one sticky thought. Capture the situation, emotion, evidence, and a steadier response.",
                    actionTitle: "Add Thought Record",
                    actionSystemImage: "plus.circle.fill"
                ) {
                    HapticManager.shared.lightImpact()
                    attemptingNewRecord = true
                }
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if !dueReframeFollowUps.isEmpty {
                            ThoughtRecordSectionHeader(title: "Follow-Up Due")
                            ForEach(dueReframeFollowUps) { record in
                                NavigationLink(value: record) {
                                    ReframeFollowUpRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !recentReframes.isEmpty {
                            ThoughtRecordSectionHeader(title: "Recent Reframes")
                            ForEach(recentReframes) { record in
                                NavigationLink(value: record) {
                                    ReframeRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !favoriteReframes.isEmpty {
                            ThoughtRecordSectionHeader(title: "Favorite Reframes")
                            ForEach(favoriteReframes) { record in
                                NavigationLink(value: record) {
                                    ReframeRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ThoughtRecordSectionHeader(title: "Thought Records")
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                ThoughtRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if !record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button {
                                        updateSavedReframe(record, isSaved: !record.isSavedReframe)
                                    } label: {
                                        Label(
                                            record.isSavedReframe ? "Remove from Reframes" : "Save Reframe",
                                            systemImage: record.isSavedReframe ? "bookmark.slash" : "bookmark"
                                        )
                                    }

                                    Button {
                                        updateFavoriteReframe(record, isFavorite: !record.isFavoriteReframe)
                                    } label: {
                                        Label(
                                            record.isFavoriteReframe ? "Remove Favorite" : "Favorite Reframe",
                                            systemImage: record.isFavoriteReframe ? "star.slash" : "star"
                                        )
                                    }
                                }

                                Button(role: .destructive) {
                                    softDelete(record)
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
        .navigationDestination(for: ThoughtRecord.self) { record in
            if record.isDraft || !record.isComplete {
                NewThoughtRecordFlowView(recordID: record.persistentModelID)
            } else {
                ThoughtRecordDetailView(record: record)
            }
        }
        .safeAreaInset(edge: .top) {
            if !records.isEmpty {
                HStack(spacing: 8) {
                    NavigationLink {
                        ReframeReviewDeckView()
                    } label: {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(
                        DSButtonStyle(
                            variant: .secondary,
                            size: .compact,
                            expands: false,
                            tint: themeManager.selectedColor,
                            hapticType: .light
                        )
                    )

                    Spacer()

                    ListActionPillButton(
                        title: "+ Thought",
                        color: themeManager.secondaryColor
                    ) {
                        attemptingNewRecord = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingNewRecord) {
            NewThoughtRecordFlowView()
                .dsSheetPresentation()
        }
        .withUsageGate(isAttemptingAction: $attemptingNewRecord) {
            showingNewRecord = true
        }
        .task {
            await refreshRecords()
        }
        .onChange(of: showingNewRecord) { _, isPresented in
            guard !isPresented else { return }
            Task { await refreshRecords() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshRecords() }
        }
    }
    
    @MainActor
    private func refreshRecords() async {
        records = LaunchSafeFetch.thoughtRecords(from: modelContext)
    }

    private func softDelete(_ record: ThoughtRecord) {
        do {
            try modelContext.cbtStore.softDelete(item: record)
            Task { await refreshRecords() }
        } catch {
            AppLogger.make(category: "Data").error("Failed to delete record: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func updateSavedReframe(_ record: ThoughtRecord, isSaved: Bool) {
        do {
            try modelContext.cbtStore.updateSavedReframe(record, isSaved: isSaved)
            HapticManager.shared.lightImpact()
            Task { await refreshRecords() }
        } catch {
            AppLogger.make(category: "Data").error("Failed to update saved reframe: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func updateFavoriteReframe(_ record: ThoughtRecord, isFavorite: Bool) {
        do {
            try modelContext.cbtStore.updateFavoriteReframe(record, isFavorite: isFavorite)
            HapticManager.shared.lightImpact()
            Task { await refreshRecords() }
        } catch {
            AppLogger.make(category: "Data").error("Failed to update favorite reframe: \(error.localizedDescription, privacy: .private)")
        }
    }
}

fileprivate struct ThoughtRecordRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let record: ThoughtRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeManager.secondaryColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(themeManager.secondaryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Thought Record")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Text(record.isDraft ? "Draft" : "\(record.intensityBefore)→\(record.intensityAfter)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.secondaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.secondaryColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !record.situation.isEmpty {
                Text(record.situation)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
            }

            if !record.automaticThought.isEmpty {
                Text("“\(record.automaticThought)”")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .italic()
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            if record.isSavedReframe {
                Label(record.isFavoriteReframe ? "Favorite reframe" : "Saved reframe", systemImage: record.isFavoriteReframe ? "star.fill" : "bookmark.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.secondaryColor)
            }

            let tags = record.emotions + record.distortions
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(tags.prefix(5)), id: \.self) { tag in
                            TagChip(title: tag)
                        }
                        if tags.count > 5 {
                            TagChip(title: "+\(tags.count - 5)")
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

fileprivate struct ThoughtRecordSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DSTypography.sectionTitle)
            .foregroundStyle(Theme.primaryText)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

fileprivate struct ReframeRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let record: ThoughtRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.isFavoriteReframe ? "star.fill" : "quote.bubble.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(themeManager.secondaryColor)
                .frame(width: 36, height: 36)
                .background(themeManager.secondaryColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(record.displayReframe)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .layoutPriority(1)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

fileprivate struct ReframeFollowUpRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let record: ThoughtRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 36, height: 36)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Does this thought still feel believable?")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.displayReframe)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let dueDate = record.reframeFollowUpDueDate() {
                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(DSTypography.caption)
                        .foregroundStyle(themeManager.selectedColor)
                }
            }
            .layoutPriority(1)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
