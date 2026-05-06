import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.xeo.timeblocking", category: "TimeBlockChecklists")

struct DraftChecklistItem: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}


struct DraftTimeBlockChecklistView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var items: [DraftChecklistItem]
    @State private var newItemTitle = ""

    private var completedCount: Int {
        items.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TimeSectionHeader(
                "Checklist",
                subtitle: items.isEmpty
                    ? "Optional per-block checklist items"
                    : "\(completedCount) of \(items.count) completed"
            )

            HStack(spacing: 8) {
                TextField("Add checklist item", text: $newItemTitle)
                    #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(itemBackground)
                    .onSubmit(addItem)

                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.primaryAccent))
                }
                .buttonStyle(.plain)
                .disabled(trimmedNewItemTitle.isEmpty)
                .opacity(trimmedNewItemTitle.isEmpty ? 0.5 : 1)
            }

            if items.isEmpty {
                Text("No checklist items yet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach($items) { $item in
                        TimeBlockChecklistItemRow(
                            title: $item.title,
                            isCompleted: item.isCompleted,
                            onToggle: { toggle(itemID: item.id) },
                            onDelete: { delete(itemID: item.id) },
                            onCommitTitle: { commitTitle(for: item.id) }
                        )
                    }
                }
            }
        }
    }

    private var trimmedNewItemTitle: String {
        newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var itemBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Theme.backgroundColor.opacity(0.6))
    }

    private func addItem() {
        let trimmedTitle = trimmedNewItemTitle
        guard !trimmedTitle.isEmpty else {
            return
        }

        items.append(DraftChecklistItem(title: trimmedTitle))
        newItemTitle = ""
    }

    private func toggle(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        items[index].isCompleted.toggle()
    }

    private func delete(itemID: UUID) {
        items.removeAll { $0.id == itemID }
    }

    private func commitTitle(for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let trimmedTitle = items[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            delete(itemID: itemID)
            return
        }

        items[index].title = trimmedTitle
    }
}

struct TimeBlockChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var block: TimeBlock
    @State private var newItemTitle = ""

    private var sortedItems: [BlockChecklistItem] {
        (block.checklistItems ?? []).sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var completedCount: Int {
        sortedItems.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TimeSectionHeader(
                "Checklist",
                subtitle: sortedItems.isEmpty
                    ? "Optional per-block checklist items"
                    : "\(completedCount) of \(sortedItems.count) completed"
            )

            HStack(spacing: 8) {
                TextField("Add checklist item", text: $newItemTitle)
                    #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(itemBackground)
                    .onSubmit(addItem)

                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.primaryAccent))
                }
                .buttonStyle(.plain)
                .disabled(trimmedNewItemTitle.isEmpty)
                .opacity(trimmedNewItemTitle.isEmpty ? 0.5 : 1)
            }

            if sortedItems.isEmpty {
                Text("No checklist items yet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedItems) { item in
                        TimeBlockChecklistItemRow(
                            title: Binding(
                                get: { item.title },
                                set: { item.title = $0 }
                            ),
                            isCompleted: item.isCompleted,
                            onToggle: { toggle(item) },
                            onDelete: { delete(item) },
                            onCommitTitle: { commitTitle(for: item) }
                        )
                    }
                }
            }
        }
    }

    private var trimmedNewItemTitle: String {
        newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var itemBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Theme.backgroundColor.opacity(0.6))
    }

    private func addItem() {
        let trimmedTitle = trimmedNewItemTitle
        guard !trimmedTitle.isEmpty else {
            return
        }

        let item = BlockChecklistItem(
            title: trimmedTitle,
            sortOrder: sortedItems.count,
            updatedAt: .now,
            timeBlock: block
        )

        if block.checklistItems == nil {
            block.checklistItems = []
        }
        block.checklistItems?.append(item)
        block.updatedAt = .now
        modelContext.insert(item)
        saveChanges()
        newItemTitle = ""
    }

    private func toggle(_ item: BlockChecklistItem) {
        item.isCompleted.toggle()
        item.updatedAt = .now
        block.updatedAt = .now
        saveChanges()
    }

    private func delete(_ item: BlockChecklistItem) {
        guard let existingItems = block.checklistItems else {
            return
        }

        block.checklistItems = existingItems.filter { $0.id != item.id }
        normalizeSortOrder()
        block.updatedAt = .now
        modelContext.delete(item)
        saveChanges()
    }

    private func commitTitle(for item: BlockChecklistItem) {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            delete(item)
            return
        }

        if item.title != trimmedTitle {
            item.title = trimmedTitle
        }

        item.updatedAt = .now
        block.updatedAt = .now
        saveChanges()
    }

    private func normalizeSortOrder() {
        for (index, item) in sortedItems.enumerated() {
            item.sortOrder = index
            item.updatedAt = .now
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save checklist changes: \(error)")
        }
    }
}

struct TimeBlockChecklistItemRow: View {
    @Binding var title: String
    let isCompleted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onCommitTitle: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCompleted ? .green : Theme.secondaryText)
            }
            .buttonStyle(.plain)

            TextField("Checklist item", text: $title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(isCompleted ? Theme.secondaryText : Theme.primaryText)
                .strikethrough(isCompleted)
                .focused($isFocused)
                .onSubmit(onCommitTitle)
                .onChange(of: isFocused) { wasFocused, isFocused in
                    if wasFocused && !isFocused {
                        onCommitTitle()
                    }
                }

            Spacer(minLength: 8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCompleted ? .green.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .onDisappear(perform: onCommitTitle)
    }
}
