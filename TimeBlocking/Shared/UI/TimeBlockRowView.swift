import SwiftData
import SwiftUI

struct TimeBlockRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: TimeBlock
    let onEdit: (() -> Void)?
    let dragCoordinateSpaceName: String?
    let isDragging: Bool
    let emphasizesDragAffordance: Bool
    let onDragBegan: ((CGPoint) -> Void)?
    let onDragChanged: ((CGPoint) -> Void)?
    let onDragEnded: ((CGPoint) -> Void)?

    @State private var hasStartedDragGesture = false

    init(
        block: TimeBlock,
        onEdit: (() -> Void)? = nil,
        dragCoordinateSpaceName: String? = nil,
        isDragging: Bool = false,
        emphasizesDragAffordance: Bool = false,
        onDragBegan: ((CGPoint) -> Void)? = nil,
        onDragChanged: ((CGPoint) -> Void)? = nil,
        onDragEnded: ((CGPoint) -> Void)? = nil
    ) {
        self.block = block
        self.onEdit = onEdit
        self.dragCoordinateSpaceName = dragCoordinateSpaceName
        self.isDragging = isDragging
        self.emphasizesDragAffordance = emphasizesDragAffordance
        self.onDragBegan = onDragBegan
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                toggleCompletion()
            } label: {
                Image(systemName: statusSymbol)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(block.status == .completed ? "Mark block as planned" : "Mark block as completed")

            TimeBlockRowDetailsView(block: block)

            Spacer(minLength: 0)

            if supportsDrag {
                dragHandle
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.primaryPurple.opacity(isDragging ? 0.08 : 0))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isDragging ? 0.26 : 1)
        .scaleEffect(isDragging ? 0.985 : 1)
        .contentShape(Rectangle())
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
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isDragging)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: emphasizesDragAffordance)
    }

    private var supportsDrag: Bool {
        dragCoordinateSpaceName != nil && onDragBegan != nil && onDragChanged != nil && onDragEnded != nil
    }

    private var dragHandle: some View {
        HStack(spacing: 6) {
            Image(systemName: isDragging ? "arrow.up.and.down.and.arrow.left.and.right" : "line.3.horizontal")
                .font(.system(size: 12, weight: .bold))

            Text(isDragging ? "Moving" : "Move")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(isDragging ? .white : Theme.primaryPurple)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            Capsule(style: .continuous)
                .fill(isDragging ? Theme.primaryPurple : Theme.primaryPurple.opacity(emphasizesDragAffordance ? 0.18 : 0.1))
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Theme.primaryPurple.opacity(isDragging ? 0.24 : (emphasizesDragAffordance ? 0.2 : 0.14)), lineWidth: 1)
        }
        .shadow(
            color: emphasizesDragAffordance && !isDragging ? Theme.primaryPurple.opacity(0.12) : .clear,
            radius: 10,
            x: 0,
            y: 6
        )
        .contentShape(Capsule())
        .highPriorityGesture(dragGesture)
        .accessibilityLabel("Drag to move block to another day")
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

    private var statusSymbol: String {
        switch block.status {
        case .planned:
            "circle"
        case .completed:
            "checkmark.circle.fill"
        case .cancelled:
            "minus.circle"
        }
    }

    private var statusColor: Color {
        switch block.status {
        case .planned:
            .secondary
        case .completed:
            .green
        case .cancelled:
            .red
        }
    }

    private func toggleCompletion() {
        block.status = block.status == .completed ? .planned : .completed
        block.updatedAt = .now
        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }
}

struct TimeBlockDragPreviewView: View {
    let block: TimeBlock
    let destinationDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: block.template == nil ? "calendar.badge.clock" : "square.stack.3d.up.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.primaryPurple))

                VStack(alignment: .leading, spacing: 6) {
                    Text(block.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(2)

                    Text(timeRangeText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    Label(block.category.title, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            if let destinationDate {
                HStack(spacing: 8) {
                    Label(destinationDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)

                    Spacer(minLength: 0)
                }
            } else {
                Text(block.template == nil ? "Drop onto a day to move this block." : "Drop onto a day to move this block. Moving it will make it manual.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                        .opacity(0.72)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusXLarge, style: .continuous)
                .strokeBorder(Theme.primaryPurple.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Theme.primaryPurple.opacity(0.18), radius: 22, x: 0, y: 14)
    }

    private var timeRangeText: String {
        let start = block.startDate.formatted(date: .omitted, time: .shortened)
        let end = block.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}

private struct TimeBlockRowDetailsView: View {
    let block: TimeBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.title)
                    .font(.headline)
                    .foregroundStyle(block.status == .cancelled ? .secondary : .primary)
                    .strikethrough(block.status == .completed)

                if block.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(timeRangeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(block.category.title, systemImage: "tag")
                .font(.caption)
                .foregroundStyle(.secondary)

            let checklistItems = block.checklistItems ?? []
            if !checklistItems.isEmpty {
                Label("\(checklistItems.filter(\.isCompleted).count)/\(checklistItems.count) checklist items", systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeRangeText: String {
        let start = block.startDate.formatted(date: .omitted, time: .shortened)
        let end = block.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}
