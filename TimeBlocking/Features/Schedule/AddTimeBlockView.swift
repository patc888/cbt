import SwiftData
import SwiftUI

struct TimeBlockEditorDraft {
    let title: String
    let selectedDate: Date
    let startTime: Date
    let durationMinutes: Int
    let category: TimeBlockCategory
    let notes: String

    init(
        title: String,
        selectedDate: Date,
        startTime: Date,
        durationMinutes: Int,
        category: TimeBlockCategory,
        notes: String
    ) {
        self.title = title
        self.selectedDate = selectedDate
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.category = category
        self.notes = notes
    }

    init(block: TimeBlock) {
        self.init(
            title: block.title,
            selectedDate: block.startDate,
            startTime: block.startDate,
            durationMinutes: max(Int(block.endDate.timeIntervalSince(block.startDate) / 60), 15),
            category: block.category,
            notes: block.notes ?? ""
        )
    }
}

struct AddTimeBlockView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var preferences: [AppPreferences]

    @State private var title: String
    @State private var selectedDate: Date
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var category: TimeBlockCategory
    @State private var notes: String
    @State private var draftChecklistItems: [DraftChecklistItem]
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirmation = false
    @State private var hasAppliedDefaultDuration = false
    @FocusState private var focusedField: EditorField?

    private let editingBlockID: UUID?
    private let onSave: (Date) -> Void
    private let onDelete: ((Date) -> Void)?

    private enum EditorField: Hashable {
        case title
    }

    init(
        selectedDate: Date,
        editingBlockID: UUID? = nil,
        initialDraft: TimeBlockEditorDraft? = nil,
        onSave: @escaping (Date) -> Void = { _ in },
        onDelete: ((Date) -> Void)? = nil
    ) {
        let calendar = Calendar.current
        let resolvedDraft = initialDraft
        let resolvedSelectedDate = resolvedDraft?.selectedDate ?? selectedDate
        let dayStart = calendar.startOfDay(for: resolvedSelectedDate)
        let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? resolvedSelectedDate
        let initialDuration = resolvedDraft?.durationMinutes ?? 60

        _title = State(initialValue: resolvedDraft?.title ?? "")
        _selectedDate = State(initialValue: resolvedSelectedDate)
        _startTime = State(initialValue: resolvedDraft?.startTime ?? defaultStartTime)
        _durationMinutes = State(initialValue: initialDuration)
        _category = State(initialValue: resolvedDraft?.category ?? .custom)
        _notes = State(initialValue: resolvedDraft?.notes ?? "")
        _draftChecklistItems = State(initialValue: [])
        self.editingBlockID = editingBlockID
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
                                    isEditing ? "Edit Time Block" : "Add Time Block",
                                    subtitle: isEditing
                                        ? "Update this planned block for the selected day"
                                        : "Create a one-off manual block for the selected day"
                                )

                                if isEditing && editingBlock == nil {
                                    Text("This time block is no longer available. Close this sheet and reopen the block from the schedule.")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.red)
                                }

                                VStack(alignment: .leading, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Title")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                            .padding(.leading, 4)

                                        TextField("Enter title...", text: $title)
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Theme.primaryText)
                                            #if os(iOS)
                                            .textInputAutocapitalization(.words)
                                            #endif
                                            .submitLabel(.done)
                                            .focused($focusedField, equals: .title)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.primary.opacity(0.06))
                                            )
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(
                                                        focusedField == .title ? Theme.primaryPurple.opacity(0.5) : Color.primary.opacity(0.08),
                                                        lineWidth: focusedField == .title ? 1.5 : 1
                                                    )
                                            }
                                    }

                                    Divider()
                                        .padding(.vertical, 4)

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
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                            .padding(.leading, 4)

                                        TextEditor(text: $notes)
                                            .frame(minHeight: 100)
                                            .padding(8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(Color.primary.opacity(0.04))
                                            )
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                            }
                                            #if os(iOS)
                                            .scrollContentBackground(.hidden)
                                            #endif
                                    }

                                    if !isEditing {
                                        Text("Use Templates for routines you want regenerated later. Manual blocks are for one-off plans and personal adjustments.")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                        }

                        TimeCard {
                            if let editingBlock {
                                TimeBlockChecklistView(block: editingBlock)
                            } else if isEditing {
                                Text("Checklist editing is unavailable because this block was removed.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
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

                        if isEditing {
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
                            .disabled(editingBlock == nil)
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
        }
        .navigationTitle(isEditing ? "Edit Block" : "New Block")
        .timeInlineNavigationTitle()
        .task(id: preferences.first?.updatedAt) {
            applyDefaultDurationIfNeeded()
        }
        .onAppear {
            guard !isEditing else {
                return
            }

            focusedField = .title
        }
        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Save") {
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

    private var isEditing: Bool {
        editingBlockID != nil
    }

    private var editingBlock: TimeBlock? {
        guard let editingBlockID else {
            return nil
        }

        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.id == editingBlockID
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private var durationText: String {
        "\(durationMinutes) min"
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSaveDisabled: Bool {
        trimmedTitle.isEmpty ||
        (isEditing && editingBlock == nil)
    }

    private func saveBlock() {
        do {
            if let editingBlockID {
                guard let block = fetchBlock(id: editingBlockID) else {
                    errorMessage = "This time block is no longer available."
                    return
                }

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
                Task {
                    await appEnvironment.syncReminder(for: block, using: modelContext)
                }
                onSave(block.startDate)
            } else {
                normalizeDraftChecklistItems()
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
                Task {
                    await appEnvironment.syncReminder(for: block, using: modelContext)
                }
                onSave(block.startDate)
            }
            dismiss()
        } catch {
            errorMessage = "Unable to save this time block right now."
            assertionFailure("Failed to save time block: \(error)")
        }
    }

    private func deleteBlock() {
        guard let editingBlockID, let block = fetchBlock(id: editingBlockID) else {
            errorMessage = "This time block is no longer available."
            return
        }

        let deletedDate = block.startDate
        let deletedBlockID = block.id

        do {
            try appEnvironment.scheduleRepository.deleteBlock(block, in: modelContext)
            Task {
                await appEnvironment.cancelReminder(forBlockID: deletedBlockID, using: modelContext)
            }
            onDelete?(deletedDate)
            dismiss()
        } catch {
            errorMessage = "Unable to delete this time block right now."
            assertionFailure("Failed to delete time block: \(error)")
        }
    }

    private func applyDefaultDurationIfNeeded() {
        guard !isEditing, !hasAppliedDefaultDuration else {
            return
        }

        durationMinutes = max(preferences.first?.defaultBlockDurationMinutes ?? durationMinutes, 15)
        hasAppliedDefaultDuration = true
    }

    private func fetchBlock(id: UUID) -> TimeBlock? {
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.id == id
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func normalizeDraftChecklistItems() {
        var normalizedItems: [DraftChecklistItem] = []

        for item in draftChecklistItems {
            let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else {
                continue
            }

            normalizedItems.append(
                DraftChecklistItem(
                    id: item.id,
                    title: trimmedTitle,
                    isCompleted: item.isCompleted
                )
            )
        }

        draftChecklistItems = normalizedItems
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
