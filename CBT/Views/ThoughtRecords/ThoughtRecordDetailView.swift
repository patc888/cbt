import SwiftUI
import SwiftData
import os

struct ThoughtRecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let record: ThoughtRecord
    @State private var showingDeleteConfirmation = false
    @State private var isSavedReframe = false
    @State private var isFollowUpDue = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header (Date and Intentsity)
                HStack(alignment: .center) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    
                    HStack(spacing: 8) {
                        IntensityBadge(title: "Before", intensity: record.intensityBefore)
                        IntensityBadge(title: "After", intensity: record.intensityAfter)
                    }
                }

                NavigationLink {
                    CognitiveSandboxView(record: record)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Open Cognitive Sandbox")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // Content
                DetailSection(title: "Situation") {
                    Text(record.situation)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
                
                DetailSection(title: "Automatic Thought") {
                    Text("“\(record.automaticThought)”")
                        .font(.body)
                        .italic()
                        .foregroundStyle(Theme.primaryText)
                }
                
                // Tags
                let tags = record.emotions + record.distortions
                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emotions & Distortions")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                TagChip(title: tag)
                            }
                        }
                    }
                }
                
                DetailSection(title: "Evidence For") {
                    Text(record.evidenceFor)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
                
                DetailSection(title: "Evidence Against") {
                    Text(record.evidenceAgainst)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }
                
                DetailSection(title: "Balanced Thought") {
                    Text(record.balancedThought)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                }

                if isFollowUpDue {
                    reframeFollowUpCard
                }

                followUpSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
        }
        .background(ThemedBackground().ignoresSafeArea())
        .navigationTitle("Thought Record Detail")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        updateSavedReframe()
                    } label: {
                        Image(systemName: isSavedReframe ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(isSavedReframe ? "Remove saved reframe" : "Save reframe")
                }
            }

            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .confirmationDialog(
            "Delete Thought Record?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteRecord()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            isSavedReframe = record.isSavedReframe
            isFollowUpDue = record.isReframeFollowUpDue()
        }
    }

    private var reframeFollowUpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Does this thought still feel believable?", systemImage: "questionmark.bubble.fill")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(record.displayReframe)
                .font(.system(.body, design: .rounded).italic())
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                beliefButton("Not yet", value: 25)
                beliefButton("Somewhat", value: 60)
                beliefButton("Yes", value: 90)
            }
        }
        .padding(Theme.paddingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.selectedColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var followUpSection: some View {
        let hasFollowUp = record.reviewDueAt != nil ||
            record.lastReviewedAt != nil ||
            record.balancedThoughtBeliefLater != nil ||
            !record.linkedExperimentIDs.isEmpty ||
            !record.relapsePatterns.isEmpty ||
            record.isFavoriteReframe

        if hasFollowUp {
            DetailSection(title: "Follow-up") {
                VStack(alignment: .leading, spacing: 10) {
                    if let reviewDueAt = record.reviewDueAt {
                        followUpRow(
                            icon: "calendar.badge.clock",
                            title: "Re-review",
                            value: reviewDueAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    if let lastReviewedAt = record.lastReviewedAt {
                        followUpRow(
                            icon: "checkmark.circle",
                            title: "Reviewed",
                            value: lastReviewedAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    if let belief = record.balancedThoughtBeliefLater {
                        followUpRow(
                            icon: "checklist.checked",
                            title: "Believable later",
                            value: "\(belief)%"
                        )
                    }

                    if !record.linkedExperimentIDs.isEmpty {
                        followUpRow(
                            icon: "figure.step.training",
                            title: "Experiment",
                            value: "Exposure ladder linked"
                        )
                    }

                    if !record.relapsePatterns.isEmpty {
                        followUpRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Pattern",
                            value: record.relapsePatterns.joined(separator: ", ")
                        )
                    }

                    if record.isFavoriteReframe {
                        followUpRow(
                            icon: "star.fill",
                            title: "Favorite situation",
                            value: record.followUpSituationLabel
                        )
                    }
                }
            }
        }
    }

    private func followUpRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                Text(value)
                    .font(.body)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func beliefButton(_ title: String, value: Int) -> some View {
        let isSelected = record.balancedThoughtBeliefLater == value

        return Button {
            markReframeFollowUpReviewed(belief: value)
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
    
    private func deleteRecord() {
        HapticManager.shared.destructiveAction()
        do {
            try modelContext.cbtStore.softDelete(item: record)
            dismiss()
        } catch {
            AppLogger.make(category: "Data").error("Failed to delete record: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func updateSavedReframe() {
        let nextValue = !isSavedReframe
        do {
            try modelContext.cbtStore.updateSavedReframe(record, isSaved: nextValue)
            isSavedReframe = nextValue
            isFollowUpDue = record.isReframeFollowUpDue()
            HapticManager.shared.lightImpact()
        } catch {
            AppLogger.make(category: "Data").error("Failed to update saved reframe: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func markReframeFollowUpReviewed(belief: Int) {
        do {
            try modelContext.cbtStore.recordBalancedThoughtBelief(record, belief: belief)
            isFollowUpDue = false
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to mark reframe follow-up reviewed: \(error.localizedDescription, privacy: .private)")
        }
    }
}

fileprivate struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
            content
                .padding(.horizontal, 4)
        }
    }
}

fileprivate struct IntensityBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let intensity: Int
    
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)
            Text("\(intensity)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.toggleBackgroundColor(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// A simple FlowLayout for displaying tags
fileprivate struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return size(for: rows, proposal: proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y: CGFloat = bounds.minY
        
        for row in rows {
            var x: CGFloat = bounds.minX
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            
            for index in row {
                let view = subviews[index]
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            
            y += rowHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let width = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentRowWidth: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width > width, !rows[rows.count - 1].isEmpty {
                rows.append([index])
                currentRowWidth = size.width + spacing
            } else {
                rows[rows.count - 1].append(index)
                currentRowWidth += size.width + spacing
            }
        }
        return rows
    }
    
    private func size(for rows: [[Int]], proposal: ProposedViewSize) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        
        for row in rows {
            height += rowHeight(for: row, proposal: proposal)
        }
        
        height += CGFloat(max(0, rows.count - 1)) * spacing
        
        return CGSize(width: width, height: height)
    }
    
    private func rowHeight(for row: [Int], proposal: ProposedViewSize) -> CGFloat {
        // Just approximation, as height for subview can be accessed fully in layout 
        // This simple layout ignores height variation, assuming all chips have same height
        return 30
    }
}
