import SwiftData
import SwiftUI
import os

struct ReframeReviewDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager

    @State private var records: [ThoughtRecord] = []
    @State private var currentIndex = 0
    @State private var isShowingBalancedThought = false

    private var currentRecord: ThoughtRecord? {
        guard records.indices.contains(currentIndex) else { return nil }
        return records[currentIndex]
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            if records.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "rectangle.stack.badge.plus",
                    title: "Saved Reframes",
                    message: "Finish a thought record and save the balanced thought. Your first reframe will appear here for quick review.",
                    actionTitle: nil,
                    actionSystemImage: nil,
                    action: nil
                )
                .padding(.horizontal, 24)
            } else {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    deckHeader

                    if let currentRecord {
                        reviewCard(for: currentRecord)
                    }

                    controls
                }
                .padding(DSSpacing.large)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Saved Reframes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await refreshRecords()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshRecords() }
        }
    }

    private var deckHeader: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Text("\(currentIndex + 1) of \(records.count)")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)

            ProgressView(value: Double(currentIndex + 1), total: Double(records.count))
                .tint(themeManager.selectedColor)
                .accessibilityLabel("Reframe \(currentIndex + 1) of \(records.count)")
        }
    }

    private func reviewCard(for record: ThoughtRecord) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            VStack(alignment: .leading, spacing: DSSpacing.small) {
                Label("What would you tell yourself now?", systemImage: "quote.bubble")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.selectedColor)

                if !record.automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(record.automaticThought)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(DSTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !record.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(record.situation)
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: DSSpacing.small) {
                Text(isShowingBalancedThought ? "Saved balanced thought" : "Pause for your answer")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DSTheme.secondaryText)
                    .textCase(.uppercase)

                if isShowingBalancedThought {
                    Text(record.balancedThought)
                        .font(.system(.body, design: .rounded).italic())
                        .foregroundStyle(DSTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Take a breath, answer in your own words, then reveal the reframe you saved.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let lastReviewedAt = record.lastReviewedAt {
                Text("Reviewed \(lastReviewedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            } else if let dueDate = record.reframeFollowUpDueDate() {
                Text("Re-review \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            }

            if isShowingBalancedThought && (record.isReframeFollowUpDue() || record.balancedThoughtBeliefLater != nil) {
                followUpQuestion(for: record)
            }

            Button {
                toggleFavorite(record)
            } label: {
                Label(
                    record.isFavoriteReframe ? "Favorite Reframe" : "Mark as Favorite",
                    systemImage: record.isFavoriteReframe ? "star.fill" : "star"
                )
            }
            .buttonStyle(DSSecondaryButtonStyle(size: .medium))
        }
        .padding(DSSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .fill(DSTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .stroke(themeManager.selectedColor.opacity(0.18), lineWidth: 1)
        )
    }

    private func followUpQuestion(for record: ThoughtRecord) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Text("Does this thought still feel believable?")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(DSTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DSSpacing.small) {
                beliefButton("Not yet", value: 25, record: record)
                beliefButton("Somewhat", value: 60, record: record)
                beliefButton("Yes", value: 90, record: record)
            }
        }
        .padding(DSSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.selectedColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
    }

    private func beliefButton(_ title: String, value: Int, record: ThoughtRecord) -> some View {
        let isSelected = record.balancedThoughtBeliefLater == value

        return Button {
            recordBelief(value, for: record)
        } label: {
            Text(title)
                .font(DSTypography.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : themeManager.selectedColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous)
                        .fill(isSelected ? themeManager.selectedColor : themeManager.selectedColor.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value) percent believable")
    }

    private var controls: some View {
        VStack(spacing: DSSpacing.medium) {
            Button {
                toggleAnswer()
            } label: {
                Label(
                    isShowingBalancedThought ? "Hide Reframe" : "Reveal Reframe",
                    systemImage: isShowingBalancedThought ? "eye.slash" : "eye"
                )
            }
            .buttonStyle(DSPrimaryButtonStyle())

            HStack(spacing: DSSpacing.medium) {
                Button {
                    move(by: -1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .buttonStyle(DSSecondaryButtonStyle(size: .medium))
                .disabled(currentIndex == 0)

                Button {
                    markReviewedAndAdvance()
                } label: {
                    Label(
                        currentIndex == records.count - 1 ? "Review Again" : "Next",
                        systemImage: currentIndex == records.count - 1 ? "arrow.counterclockwise" : "chevron.right"
                    )
                }
                .buttonStyle(DSSecondaryButtonStyle(size: .medium))
            }
        }
    }

    @MainActor
    private func refreshRecords() async {
        do {
            let descriptor = FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { record in
                    record.isDeleted == false &&
                    record.isSavedReframe == true &&
                    !record.balancedThought.isEmpty
                },
                sortBy: [
                    SortDescriptor(\ThoughtRecord.lastReviewedAt, order: .forward),
                    SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)
                ]
            )
            records = try modelContext.fetch(descriptor).sorted { lhs, rhs in
                let lhsDue = lhs.isReframeFollowUpDue()
                let rhsDue = rhs.isReframeFollowUpDue()
                if lhsDue != rhsDue {
                    return lhsDue && !rhsDue
                }

                return (lhs.lastReviewedAt ?? .distantPast) < (rhs.lastReviewedAt ?? .distantPast)
            }
            currentIndex = min(currentIndex, max(records.count - 1, 0))
        } catch {
            AppLogger.make(category: "Data").error("Failed to fetch saved reframes: \(error.localizedDescription, privacy: .private)")
            records = []
        }
    }

    private func toggleAnswer() {
        HapticManager.shared.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingBalancedThought.toggle()
        }
    }

    private func markReviewedAndAdvance() {
        guard let currentRecord else { return }

        do {
            try modelContext.cbtStore.updateSavedReframe(currentRecord, isSaved: true, reviewedAt: Date())
            HapticManager.shared.lightImpact()
            move(by: 1, wraps: true)
        } catch {
            AppLogger.make(category: "Data").error("Failed to mark reframe reviewed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func toggleFavorite(_ record: ThoughtRecord) {
        do {
            try modelContext.cbtStore.updateFavoriteReframe(record, isFavorite: !record.isFavoriteReframe)
            HapticManager.shared.selection()
        } catch {
            AppLogger.make(category: "Data").error("Failed to update favorite reframe: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func move(by offset: Int, wraps: Bool = false) {
        guard !records.isEmpty else { return }

        let proposedIndex = currentIndex + offset
        if wraps {
            currentIndex = (proposedIndex + records.count) % records.count
        } else {
            currentIndex = min(max(proposedIndex, 0), records.count - 1)
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingBalancedThought = false
        }
    }
}
