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


    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            if records.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "brain.head.profile",
                    title: "Thought Records",
                    message: "Thought records help you slow down one difficult moment and look for a more balanced response.",
                    actionTitle: "Add Thought Record",
                    actionSystemImage: "plus.circle.fill"
                ) {
                    HapticManager.shared.lightImpact()
                    attemptingNewRecord = true
                }
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                ThoughtRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
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
            ThoughtRecordDetailView(record: record)
        }
        .safeAreaInset(edge: .top) {
            if !records.isEmpty {
                HStack {
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

                Text("\(record.intensityBefore)→\(record.intensityAfter)")
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
