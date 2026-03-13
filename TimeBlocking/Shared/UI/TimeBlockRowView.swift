import SwiftData
import SwiftUI

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
        switch block.category {
        case .focus: return Theme.primaryPurple
        case .personal: return Color(hex: "F59E0B")
        case .admin: return Color(hex: "0EA5E9")
        case .routine: return Color(hex: "10B981")
        case .custom: return Color(hex: "64748B")
        }
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
        let isCompleted = block.status == .completed

        ZStack {
            VStack(alignment: .leading, spacing: sortedChecklistItems.isEmpty || !isChecklistExpanded ? 0 : 16) {
                HStack(spacing: 16) {
                    // Icon Tile (Chores Style)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accentColor.opacity(isCompleted ? 0.3 : 1.0))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: categoryIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isCompleted ? .white.opacity(0.6) : .white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(block.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(isCompleted || fillProgress > 0.8 ? .secondary : .primary)
                                .lineLimit(1)
                                .strikethrough(isCompleted || fillProgress > 0.8)
                                .opacity(isCompleted || fillProgress > 0.8 ? 0.6 : 1.0)
                            
                            if block.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                            }
                        }

                        HStack(spacing: 6) {
                            Text(timeRangeText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            
                            if let conflictSummary {
                                Text("•")
                                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
                                Text(conflictSummary.badgeText)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    // Completion Control / Drag Handle Area
                    HStack(spacing: 12) {
                        if supportsDrag && !isCompleted {
                            dragHandle
                        }

                        Button {
                            handleComplete()
                        } label: {
                            ZStack {
                                if isCompleted || fillProgress > 0.9 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 28, weight: .black))
                                        .foregroundColor(.green)
                                        .matchedGeometryEffect(id: "status", in: animation)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Circle()
                                        .stroke(accentColor.opacity(0.4), lineWidth: 2)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(accentColor.opacity(0.8))
                                        )
                                        .matchedGeometryEffect(id: "status", in: animation)
                                }
                            }
                            .scaleEffect(fillProgress > 0.9 ? 1.15 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAnimating)
                    }
                }

                if !sortedChecklistItems.isEmpty && isChecklistExpanded {
                    inlineChecklist
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            isCompleted
                            ? (colorScheme == .dark ? Color.white.opacity(0.03) : Color.gray.opacity(0.04))
                            : (colorScheme == .light ? Color.white : Color(.secondarySystemGroupedBackground))
                        )
                    
                    if fillProgress > 0 {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(accentColor.opacity(0.12))
                            .scaleEffect(x: fillProgress, anchor: .leading)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isCompleted ? Color.primary.opacity(0.04) : accentColor.opacity(0.1), lineWidth: 1.5)
            }
            .scaleEffect(bounceScale)
            .opacity(isDragging ? 0.3 : 1)
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
        .contextMenu {
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                showConfetti = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            toggleCompletion()
            isAnimating = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showConfetti = false
                fillProgress = 0
            }
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
            assertionFailure("Failed to update block completion state: \(error)")
        }
    }

    private func saveChanges() {
        try? modelContext.save()
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

