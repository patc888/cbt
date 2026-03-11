import SwiftData
import SwiftUI

struct AddTimeBlockView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var category: TimeBlockCategory
    @State private var notes: String
    @State private var draftChecklistItems: [DraftChecklistItem]
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirmation = false

    private let block: TimeBlock?
    private let onSave: (Date) -> Void
    private let onDelete: ((Date) -> Void)?

    init(
        selectedDate: Date,
        block: TimeBlock? = nil,
        onSave: @escaping (Date) -> Void = { _ in },
        onDelete: ((Date) -> Void)? = nil
    ) {
        let calendar = Calendar.current
        let resolvedSelectedDate = block.map(\.startDate) ?? selectedDate
        let dayStart = calendar.startOfDay(for: resolvedSelectedDate)
        let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? resolvedSelectedDate
        let initialDuration = block.map {
            max(Int($0.endDate.timeIntervalSince($0.startDate) / 60), 15)
        } ?? 60

        _title = State(initialValue: block?.title ?? "")
        _selectedDate = State(initialValue: resolvedSelectedDate)
        _startTime = State(initialValue: block?.startDate ?? defaultStartTime)
        _durationMinutes = State(initialValue: initialDuration)
        _category = State(initialValue: block?.category ?? .custom)
        _notes = State(initialValue: block?.notes ?? "")
        _draftChecklistItems = State(initialValue: [])
        self.block = block
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        TimeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TimeSectionHeader(
                                    block == nil ? "Add Time Block" : "Edit Time Block",
                                    subtitle: block == nil
                                        ? "Create a planned block for the selected day"
                                        : "Update this planned block for the selected day"
                                )

                                VStack(alignment: .leading, spacing: 14) {
                                    TextField("Title", text: $title)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .padding(.bottom, 4)

                                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                                    Stepper(value: $durationMinutes, in: 15...720, step: 15) {
                                        LabeledContent("Duration", value: durationText)
                                    }

                                    Picker("Category", selection: $category) {
                                        ForEach(TimeBlockCategory.allCases) { category in
                                            Text(category.title).tag(category)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Notes")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)

                                        TextEditor(text: $notes)
                                            .frame(minHeight: 100)
                                            .background(Color.primary.opacity(0.03))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }

                        TimeCard {
                            if let block {
                                TimeBlockChecklistView(block: block)
                            } else {
                                DraftTimeBlockChecklistView(items: $draftChecklistItems)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        if block != nil {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Text("Delete Time Block")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                    Spacer()
                                    Image(systemName: "trash")
                                }
                                .foregroundStyle(.red)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .background(Color.red.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(block == nil ? "New Block" : "Edit Block")
            .timeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(block == nil ? "Save" : "Update") {
                        saveBlock()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .confirmationDialog(
                "Delete this time block?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteBlock()
                }
            } message: {
                Text("This removes the block from your schedule.")
            }
        }
    }

    private var durationText: String {
        "\(durationMinutes) min"
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveBlock() {
        do {
            if let block {
                try appEnvironment.scheduleRepository.updateBlock(
                    block,
                    title: title,
                    notes: notes,
                    date: selectedDate,
                    startTime: startTime,
                    durationMinutes: durationMinutes,
                    category: category,
                    in: modelContext
                )
                onSave(block.startDate)
            } else {
                let block = try appEnvironment.scheduleRepository.createBlock(
                    title: title,
                    notes: notes,
                    date: selectedDate,
                    startTime: startTime,
                    durationMinutes: durationMinutes,
                    category: category,
                    checklistItemTitles: draftChecklistItems.map(\.title),
                    in: modelContext
                )
                onSave(block.startDate)
            }
            dismiss()
        } catch {
            errorMessage = "Unable to save this time block right now."
            assertionFailure("Failed to save time block: \(error)")
        }
    }

    private func deleteBlock() {
        guard let block else {
            return
        }

        let deletedDate = block.startDate

        do {
            try appEnvironment.scheduleRepository.deleteBlock(block, in: modelContext)
            onDelete?(deletedDate)
            dismiss()
        } catch {
            errorMessage = "Unable to delete this time block right now."
            assertionFailure("Failed to delete time block: \(error)")
        }
    }
}

private struct DraftChecklistItem: Identifiable {
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

#Preview {
    AddTimeBlockView(selectedDate: .now)
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}

private struct DraftTimeBlockChecklistView: View {
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
                        .background(Circle().fill(Theme.primaryPurple))
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

private struct TimeBlockChecklistView: View {
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
                        .background(Circle().fill(Theme.primaryPurple))
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
        try? modelContext.save()
    }
}

private struct TimeBlockChecklistItemRow: View {
    @Binding var title: String
    let isCompleted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onCommitTitle: () -> Void

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
                .onSubmit(onCommitTitle)

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
    }
}
