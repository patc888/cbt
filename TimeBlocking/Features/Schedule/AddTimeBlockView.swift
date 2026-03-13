import SwiftData
import SwiftUI

struct TimeBlockEditorDraft: Identifiable {
    let id: UUID
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
        self.id = UUID()
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

private struct TimeBlockSample: Identifiable {
    let id: String
    let title: String
    let category: TimeBlockCategory
    let durationMinutes: Int
    let notes: String

    init(
        title: String,
        category: TimeBlockCategory,
        durationMinutes: Int,
        notes: String
    ) {
        self.id = title
        self.title = title
        self.category = category
        self.durationMinutes = durationMinutes
        self.notes = notes
    }
}

struct AddTimeBlockView: View {
    enum EntryMode: String, CaseIterable, Identifiable {
        case standard = "New Block"
        case brainDump = "Brain Dump"
        case routines = "Routines"

        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .standard: return "plus.circle.fill"
            case .brainDump: return "text.badge.plus"
            case .routines: return "square.on.square"
            }
        }
    }

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var preferences: [AppPreferences]
    @Query(sort: \BrainDumpItem.updatedAt, order: .reverse) private var brainDumpItems: [BrainDumpItem]
    @Query(sort: \ScheduleTemplate.sortOrder) private var templates: [ScheduleTemplate]

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
    @State private var editingTemplate: ScheduleTemplate?
    @State private var isPresentingNewTemplateEditor = false
    @State private var brainDumpTitle: String
    @State private var brainDumpNotes: String
    @State private var editingBrainDumpItemID: UUID?
    @State private var convertingBrainDumpItem: BrainDumpItem?
    @State private var blockConversionDraft: TimeBlockEditorDraft?
    @State private var routineConversionDraft: TemplateEditorDraft?
    @FocusState private var focusedField: EditorField?

    @State private var selectedMode: EntryMode

    private let editingBlockID: UUID?
    private let initialEntryMode: EntryMode
    private let onSave: (Date) -> Void
    private let onDelete: ((Date) -> Void)?
    private let samples: [TimeBlockSample] = [
        TimeBlockSample(
            title: "Answer Emails",
            category: .admin,
            durationMinutes: 30,
            notes: "Reply to inbox items and clear quick follow-ups."
        ),
        TimeBlockSample(
            title: "Buy Groceries",
            category: .personal,
            durationMinutes: 45,
            notes: "Pick up the essentials for the next few days."
        ),
        TimeBlockSample(
            title: "Water the Plants",
            category: .personal,
            durationMinutes: 15,
            notes: "Do a quick pass through the house and water dry plants."
        ),
        TimeBlockSample(
            title: "Workout",
            category: .personal,
            durationMinutes: 60,
            notes: "Move your body and leave a little buffer for setup and cooldown."
        ),
        TimeBlockSample(
            title: "Deep Work",
            category: .focus,
            durationMinutes: 90,
            notes: "Protect this block for concentrated work with minimal interruptions."
        ),
        TimeBlockSample(
            title: "Clean Kitchen",
            category: .personal,
            durationMinutes: 30,
            notes: "Reset counters, dishes, and anything that makes the space feel calmer."
        ),
        TimeBlockSample(
            title: "Pay Bills",
            category: .admin,
            durationMinutes: 30,
            notes: "Review upcoming payments and take care of anything due soon."
        ),
        TimeBlockSample(
            title: "Walk the Dog",
            category: .personal,
            durationMinutes: 30,
            notes: "Get outside for a short walk and fresh air."
        )
    ]

    private enum EditorField: Hashable {
        case title
        case brainDumpTitle
        case notes
    }

    init(
        selectedDate: Date,
        editingBlockID: UUID? = nil,
        entryMode: EntryMode = .standard,
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
        _brainDumpTitle = State(initialValue: "")
        _brainDumpNotes = State(initialValue: "")
        _draftChecklistItems = State(initialValue: [])
        _selectedMode = State(initialValue: entryMode)
        self.editingBlockID = editingBlockID
        self.initialEntryMode = entryMode
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
                                    sectionTitle,
                                    subtitle: isEditing
                                        ? "Update this planned block for the selected day"
                                        : sectionSubtitle
                                )

                                if isEditing && editingBlock == nil {
                                    Text("This time block is no longer available. Close this sheet and reopen the block from the schedule.")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.red)
                                }

                                VStack(alignment: .leading, spacing: 16) {
                                    if !isEditing {
                                        Picker("Entry Mode", selection: $selectedMode) {
                                            ForEach(EntryMode.allCases) { mode in
                                                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .padding(.bottom, 8)
                                        
                                        Divider()
                                            .padding(.bottom, 16)
                                    }

                                    if selectedMode == .routines {
                                        routinesShortcutsSection
                                    } else if !isEditing && selectedMode == .brainDump {
                                        brainDumpCaptureSection
                                    } else {
                                        if !isEditing && selectedMode == .standard {
                                            samplePickerSection

                                            Divider()
                                                .padding(.vertical, 4)
                                        }

                                        if showsBrainDumpFirst {
                                            brainDumpSection

                                            Divider()
                                                .padding(.vertical, 4)

                                            schedulingSection
                                        } else {
                                            schedulingSection

                                            Divider()
                                                .padding(.vertical, 4)

                                            brainDumpSection
                                        }
                                    }

                                    if !isEditing && selectedMode != .brainDump {
                                        Text("Use Routines for plans you want regenerated later. Manual blocks are for one-off plans and personal adjustments.")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                        }

                        if selectedMode != .brainDump || isEditing {
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
        .navigationTitle(isEditing ? "Edit Block" : navigationTitle)
        .timeInlineNavigationTitle()
        .task(id: preferences.first?.updatedAt) {
            applyDefaultDurationIfNeeded()
        }
        .onAppear {
            guard !isEditing else {
                return
            }

            focusedField = selectedMode == .brainDump ? .brainDumpTitle : .title
        }
        .onChange(of: selectedMode) { _, newValue in
            guard !isEditing else {
                return
            }

            focusedField = newValue == .brainDump ? .brainDumpTitle : .title
        }
        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if selectedMode != .routines {
                        Button(saveButtonTitle) {
                            if !isEditing && selectedMode == .brainDump {
                                saveBrainDumpItem()
                            } else {
                                saveBlock()
                            }
                        }
                        .disabled(isSaveDisabled)
                    }
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
            .sheet(isPresented: $isPresentingNewTemplateEditor) {
                TemplateEditorView()
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
            .sheet(item: $blockConversionDraft) { draft in
                AddTimeBlockView(
                    selectedDate: draft.selectedDate,
                    entryMode: .standard,
                    initialDraft: draft,
                    onSave: { savedDate in
                        finalizeBrainDumpConversion(savedDate: savedDate)
                    }
                )
            }
            .sheet(item: $routineConversionDraft) { draft in
                TemplateEditorView(
                    initialDraft: draft,
                    onSave: {
                        finalizeBrainDumpConversion(savedDate: selectedDate)
                    }
                )
            }
        }
    }

    private var isEditing: Bool {
        editingBlockID != nil
    }

    private var showsBrainDumpFirst: Bool {
        !isEditing && initialEntryMode == .brainDump
    }

    private var navigationTitle: String {
        selectedMode == .brainDump ? "Brain Dump" : (selectedMode == .routines ? "Routines" : "New Block")
    }

    private var saveButtonTitle: String {
        if isEditing {
            return "Update"
        }

        return selectedMode == .brainDump ? "Quick Save" : "Save"
    }

    private var sectionTitle: String {
        if isEditing {
            return "Edit Time Block"
        }

        switch selectedMode {
        case .standard: return "Add Time Block"
        case .brainDump: return "Brain Dump"
        case .routines: return "Routines"
        }
    }

    private var sectionSubtitle: String {
        switch selectedMode {
        case .standard:
            return "Create a one-off manual block for the selected day"
        case .brainDump:
            return "Capture the thought first, then shape it into a block when you're ready."
        case .routines:
            return "View and manage your reusable blocks or jump to Routine settings."
        }
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

    private var trimmedBrainDumpTitle: String {
        brainDumpTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSaveDisabled: Bool {
        if !isEditing && selectedMode == .brainDump {
            return trimmedBrainDumpTitle.isEmpty
        }

        return trimmedTitle.isEmpty ||
        (isEditing && editingBlock == nil)
    }

    private var samplePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeSectionHeader(
                "Quick Start",
                subtitle: "Pick an example to prefill this block, then tweak anything you want."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(samples) { sample in
                        Button {
                            applySample(sample)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: sample.category.symbolName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(sample.category.tintColor)
                                    .frame(width: 30, height: 30)
                                    .background(sample.category.tintColor.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                        .lineLimit(1)

                                    Text(sample.category.title)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var brainDumpCaptureSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unscheduled Inbox")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryPurple)

                        Text(editingBrainDumpItemID == nil ? "Capture it now. Decide what it becomes later." : "Editing inbox item")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                    }

                    Spacer(minLength: 12)

                    Text(brainDumpItems.isEmpty ? "Empty" : "\(brainDumpItems.count) saved")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.primaryPurple.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.leading, 4)

                    TextField("What do you want to remember?", text: $brainDumpTitle, axis: .vertical)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1...3)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                        .focused($focusedField, equals: .brainDumpTitle)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    focusedField == .brainDumpTitle ? Theme.primaryPurple.opacity(0.5) : Color.primary.opacity(0.08),
                                    lineWidth: focusedField == .brainDumpTitle ? 1.5 : 1
                                )
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.leading, 4)

                    textEditorWithPlaceholder(
                        text: $brainDumpNotes,
                        placeholder: "Add context if it helps future-you.",
                        minHeight: 110
                    )
                    .focused($focusedField, equals: .notes)
                }

                HStack(spacing: 12) {
                    Button(editingBrainDumpItemID == nil ? "Quick Save" : "Update Inbox Item") {
                        saveBrainDumpItem()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryPurple)
                    .disabled(trimmedBrainDumpTitle.isEmpty)

                    if editingBrainDumpItemID != nil {
                        Button("Cancel Edit") {
                            resetBrainDumpComposer()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("No time, duration, category, or checklist required here. Brain Dump stays unscheduled until you convert it.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Divider()

            brainDumpInboxSection
        }
    }

    private var brainDumpInboxSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TimeSectionHeader(
                "Inbox",
                subtitle: brainDumpItems.isEmpty
                    ? "Saved captures will land here until you turn them into something scheduled."
                    : "Review captures, then schedule or routinize only the ones that deserve a spot."
            )

            if brainDumpItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nothing in the inbox yet.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Use the capture box above for fast unscheduled ideas. They will stay here until you delete or convert them.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(brainDumpItems) { item in
                        brainDumpInboxRow(item)
                    }
                }
            }
        }
    }

    private func brainDumpInboxRow(_ item: BrainDumpItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Captured \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 8)

                if editingBrainDumpItemID == item.id {
                    Text("Editing")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.primaryPurple.opacity(0.12), in: Capsule())
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 8) {
                Button("Schedule") {
                    startBlockConversion(for: item)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryPurple)

                Button("Routine") {
                    startRoutineConversion(for: item)
                }
                .buttonStyle(.bordered)

                Button(editingBrainDumpItemID == item.id ? "Editing" : "Edit") {
                    loadBrainDumpItemForEditing(item)
                }
                .buttonStyle(.bordered)
                .disabled(editingBrainDumpItemID == item.id)

                Button("Delete", role: .destructive) {
                    deleteBrainDumpItem(item)
                }
                .buttonStyle(.bordered)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var schedulingSection: some View {
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
        }
    }

    private var brainDumpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Brain Dump")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 4)

            TextEditor(text: $notes)
                .focused($focusedField, equals: .notes)
                .frame(minHeight: showsBrainDumpFirst ? 160 : 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            focusedField == .notes ? Theme.primaryPurple.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: focusedField == .notes ? 1.5 : 1
                        )
                }
                #if os(iOS)
                .scrollContentBackground(.hidden)
                #endif

            Text(
                showsBrainDumpFirst
                    ? "Start with loose notes, then add the title and timing when the idea is ready to place on your day."
                    : "Capture loose notes here while planning this block."
            )
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(Theme.secondaryText)
        }
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
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = "Unable to save this time block right now."
            assertionFailure("Failed to save time block: \(error)")
        }
    }

    private func saveBrainDumpItem() {
        let trimmedTitle = trimmedBrainDumpTitle
        let trimmedNotes = brainDumpNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        do {
            if let editingBrainDumpItemID, let item = fetchBrainDumpItem(id: editingBrainDumpItemID) {
                item.title = trimmedTitle
                item.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
                item.updatedAt = .now
            } else {
                let item = BrainDumpItem(
                    title: trimmedTitle,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    createdAt: .now,
                    updatedAt: .now
                )
                modelContext.insert(item)
            }

            try modelContext.save()
            errorMessage = nil
            resetBrainDumpComposer()
        } catch {
            errorMessage = "Unable to save this inbox item right now."
            assertionFailure("Failed to save brain dump item: \(error)")
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

    private func deleteBrainDumpItem(_ item: BrainDumpItem) {
        do {
            if editingBrainDumpItemID == item.id {
                resetBrainDumpComposer()
            }

            if convertingBrainDumpItem?.id == item.id {
                convertingBrainDumpItem = nil
                blockConversionDraft = nil
                routineConversionDraft = nil
            }

            modelContext.delete(item)
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to delete this inbox item right now."
            assertionFailure("Failed to delete brain dump item: \(error)")
        }
    }

    private func loadBrainDumpItemForEditing(_ item: BrainDumpItem) {
        editingBrainDumpItemID = item.id
        brainDumpTitle = item.title
        brainDumpNotes = item.notes ?? ""
        focusedField = .brainDumpTitle
    }

    private func resetBrainDumpComposer() {
        editingBrainDumpItemID = nil
        brainDumpTitle = ""
        brainDumpNotes = ""
        focusedField = .brainDumpTitle
    }

    private func startBlockConversion(for item: BrainDumpItem) {
        convertingBrainDumpItem = item
        blockConversionDraft = TimeBlockEditorDraft(
            title: item.title,
            selectedDate: selectedDate,
            startTime: startTime,
            durationMinutes: max(preferences.first?.defaultBlockDurationMinutes ?? durationMinutes, 15),
            category: .custom,
            notes: item.notes ?? ""
        )
    }

    private func startRoutineConversion(for item: BrainDumpItem) {
        convertingBrainDumpItem = item
        routineConversionDraft = TemplateEditorDraft(
            name: item.title,
            notes: item.notes ?? "",
            defaultStartTime: startTime,
            durationMinutes: max(preferences.first?.defaultBlockDurationMinutes ?? durationMinutes, 15),
            weekdayMask: weekdayMask(for: selectedDate),
            category: .routine
        )
    }

    private func finalizeBrainDumpConversion(savedDate: Date) {
        guard let item = convertingBrainDumpItem else {
            return
        }

        do {
            modelContext.delete(item)
            try modelContext.save()
            errorMessage = nil
            convertingBrainDumpItem = nil
            blockConversionDraft = nil
            routineConversionDraft = nil
            onSave(savedDate)
        } catch {
            errorMessage = "Saved the conversion, but could not remove the inbox item."
            assertionFailure("Failed to finalize brain dump conversion: \(error)")
        }
    }

    private func fetchBrainDumpItem(id: UUID) -> BrainDumpItem? {
        let descriptor = FetchDescriptor<BrainDumpItem>(
            predicate: #Predicate<BrainDumpItem> { item in
                item.id == id
            }
        )
        return try? modelContext.fetch(descriptor).first
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

    private func applySample(_ sample: TimeBlockSample) {
        title = sample.title
        category = sample.category
        durationMinutes = sample.durationMinutes
        notes = sample.notes
        focusedField = .title
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

    private func weekdayMask(for date: Date) -> Int {
        let weekdayIndex = Calendar.current.component(.weekday, from: date)
        return 1 << max(weekdayIndex - 1, 0)
    }

    @ViewBuilder
    private func textEditorWithPlaceholder(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            focusedField == .notes ? Theme.primaryPurple.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: focusedField == .notes ? 1.5 : 1
                        )
                }
                #if os(iOS)
                .scrollContentBackground(.hidden)
                #endif

            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 18)
                    .padding(.leading, 14)
                    .allowsHitTesting(false)
            }
        }
    }

    private var routinesShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manage Routines")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                
                Spacer()
                
                Button {
                    isPresentingNewTemplateEditor = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Theme.primaryPurple)
            }
            .padding(.horizontal, 4)

            if templates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.primaryPurple.opacity(0.4))
                    
                    Text("No routines yet")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    
                    Text("Create reusable blocks that help you plan future days faster.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(templates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                    
                                    Text("\(template.defaultDurationMinutes)m • \(template.category.title)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            Button {
                appEnvironment.appState.showTemplates()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open full Routine settings")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.primaryPurple.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}

private extension TimeBlockCategory {
    var symbolName: String {
        switch self {
        case .focus:
            "scope"
        case .personal:
            "figure.walk"
        case .admin:
            "tray.full.fill"
        case .routine:
            "repeat"
        case .custom:
            "square.grid.2x2.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .focus:
            Theme.primaryPurple
        case .personal:
            Color(hex: "F59E0B")
        case .admin:
            Color(hex: "0EA5E9")
        case .routine:
            Color(hex: "10B981")
        case .custom:
            Color(hex: "64748B")
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
