import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.xeo.timeblocking", category: "TimeBlockRowView")

struct TimeBlockRowView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var block: TimeBlock
    let conflictSummary: ScheduleBlockConflictSummary?
    let onEdit: (() -> Void)?
    let isChecklistExpanded: Bool
    let onToggleChecklistExpansion: (() -> Void)?
    let dragCoordinateSpaceName: String?
    let isDragging: Bool
    let emphasizesDragAffordance: Bool
    let onDragBegan: ((CGPoint) -> Void)?
    let onDragChanged: ((CGPoint) -> Void)?
    let onDragEnded: ((CGPoint) -> Void)?

    @State private var fillProgress: CGFloat = 0
    @State private var isAnimating = false
    @State private var showConfetti = false
    @State private var bounceScale: CGFloat = 1.0
    @State private var hasStartedDragGesture = false
    @Namespace private var animation

    init(
        block: TimeBlock,
        conflictSummary: ScheduleBlockConflictSummary? = nil,
        onEdit: (() -> Void)? = nil,
        isChecklistExpanded: Bool = false,
        onToggleChecklistExpansion: (() -> Void)? = nil,
        dragCoordinateSpaceName: String? = nil,
        isDragging: Bool = false,
        emphasizesDragAffordance: Bool = false,
        onDragBegan: ((CGPoint) -> Void)? = nil,
        onDragChanged: ((CGPoint) -> Void)? = nil,
        onDragEnded: ((CGPoint) -> Void)? = nil
    ) {
        self.block = block
        self.conflictSummary = conflictSummary
        self.onEdit = onEdit
        self.isChecklistExpanded = isChecklistExpanded
        self.onToggleChecklistExpansion = onToggleChecklistExpansion
        self.dragCoordinateSpaceName = dragCoordinateSpaceName
        self.isDragging = isDragging
        self.emphasizesDragAffordance = emphasizesDragAffordance
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    private var accentColor: Color {
        Theme.color(for: block.category)
    }


    private var categoryIcon: String {
        switch block.category {
        case .focus: return "scope"
        case .personal: return "figure.walk"
        case .admin: return "tray.full.fill"
        case .routine: return "repeat"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    var body: some View {
        mainStack
    }

    private var mainStack: some View {
        ZStack {
            mainRowContent
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }


    private var mainRowContent: some View {
        VStack(alignment: .leading, spacing: sortedChecklistItems.isEmpty || !isChecklistExpanded ? 0 : 16) {
            rowHeader
            if !sortedChecklistItems.isEmpty && isChecklistExpanded {
                inlineChecklist
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(block.status == .completed ? 0 : (colorScheme == .dark ? 0.15 : 0)), radius: colorScheme == .dark ? 10 : 0, x: 0, y: colorScheme == .dark ? 4 : 0)
        .overlay { rowBorder }
        .scaleEffect(bounceScale)
        .opacity(isDragging ? 0.3 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: block.status == .completed)
    }

    private var rowHeader: some View {
        TimeBlockHeaderView(
            block: block,
            accentColor: accentColor,
            categoryIcon: categoryIcon,
            timeRangeText: timeRangeText,
            conflictSummary: conflictSummary,
            supportsDrag: supportsDrag,
            isDragging: isDragging,
            fillProgress: fillProgress,
            handleComplete: { handleComplete() },
            dragHandle: AnyView(dragHandle)
        )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(block.status == .completed ? Color.primary.opacity(0.04) : accentColor.opacity(0.12), lineWidth: 1.2)
    }






    private var rowBackground: some View {
        let isCompleted = block.status == .completed
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    isCompleted
                    ? (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    : (colorScheme == .light ? Color.white : Theme.cardBackground)
                )
            
            if fillProgress > 0 {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(accentColor.opacity(0.08))
                    .scaleEffect(x: fillProgress, anchor: .leading)
            }
        }
    }

    @ViewBuilder
    private var swipeActions: some View {
        Button(block.isPinned ? "Unpin" : "Pin") {
            block.isPinned.toggle()
            saveChanges()
        }
        .tint(.orange)

        Button(block.status == .completed ? "Planned" : "Complete") {
            toggleCompletion()
        }
        .tint(.green)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if let onEdit {
            Button("Edit", systemImage: "pencil") {
                onEdit()
            }
        }

        Button(block.isPinned ? "Unpin" : "Pin", systemImage: block.isPinned ? "pin.slash" : "pin") {
            block.isPinned.toggle()
            saveChanges()
        }

        Button(block.status == .completed ? "Mark as Planned" : "Mark as Completed", systemImage: "checkmark.circle") {
            toggleCompletion()
        }
    }


    private var sortedChecklistItems: [BlockChecklistItem] {
        (block.checklistItems ?? []).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var supportsDrag: Bool {
        block.status == .planned &&
        dragCoordinateSpaceName != nil &&
        onDragBegan != nil &&
        onDragChanged != nil &&
        onDragEnded != nil
    }

    private var inlineChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sortedChecklistItems) { item in
                Button {
                    toggleChecklistItem(item)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(item.isCompleted ? .green : Theme.secondaryText)

                        Text(item.title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(item.isCompleted ? Theme.secondaryText : Theme.primaryText)
                            .strikethrough(item.isCompleted)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(item.isCompleted ? .green.opacity(0.06) : Color.primary.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 0)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.secondaryText.opacity(0.5))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(
            minimumDistance: 2,
            coordinateSpace: .named(dragCoordinateSpaceName ?? "TimeBlockRowViewDragFallback")
        )
        .onChanged { value in
            guard supportsDrag else {
                return
            }

            if !hasStartedDragGesture {
                hasStartedDragGesture = true
                onDragBegan?(value.startLocation)
            }

            onDragChanged?(value.location)
        }
        .onEnded { value in
            guard hasStartedDragGesture else {
                return
            }

            onDragEnded?(value.location)
            hasStartedDragGesture = false
        }
    }

    private func handleComplete() {
        if block.status == .completed {
            toggleCompletion()
            return
        }
        
        guard !isAnimating else { return }
        
        isAnimating = true
        HapticManager.shared.success()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bounceScale = 1.05
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            fillProgress = 1.0
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }

            try? await Task.sleep(for: .milliseconds(50))
            withAnimation {
                showConfetti = true
            }

            try? await Task.sleep(for: .milliseconds(400))
            toggleCompletion()
            isAnimating = false

            try? await Task.sleep(for: .seconds(1.2))
            showConfetti = false
            fillProgress = 0
        }
    }

    private func toggleCompletion() {
        let nextStatus: TimeBlockStatus
        switch block.status {
        case .planned:
            nextStatus = .completed
        case .completed, .cancelled:
            nextStatus = .planned
        }

        do {
            try appEnvironment.scheduleRepository.setBlockStatus(
                block,
                to: nextStatus,
                in: modelContext
            )
            Task {
                await appEnvironment.syncReminder(for: block, using: modelContext)
            }
        } catch {
            logger.error("Failed to update block completion state: \(error)")
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save inline changes: \(error)")
        }
    }

    private func toggleChecklistItem(_ item: BlockChecklistItem) {
        item.isCompleted.toggle()
        item.updatedAt = .now
        block.updatedAt = .now
        saveChanges()
        if item.isCompleted {
            HapticManager.shared.lightImpact()
        }
    }
    
    private var timeRangeText: String {
        let start = block.startDate.formatted(date: .omitted, time: .shortened)
        let end = block.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}

