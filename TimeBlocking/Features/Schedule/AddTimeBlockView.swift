import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.xeo.timeblocking", category: "AddTimeBlockView")

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


struct AddTimeBlockView: View {
    enum EntryMode: String, CaseIterable, Identifiable {
        case standard = "New Block"
        case brainDump = "Brain Dump"
        case routines = "Routine"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .standard: return "plus.circle.fill"
            case .brainDump: return "text.badge.plus"
            case .routines: return "square.on.square"
            }
        }

        var setupDescription: String {
            switch self {
            case .standard:
                return "One-off scheduled block"
            case .brainDump:
                return "Save it unscheduled first"
            case .routines:
                return "Reusable planning pattern"
            }
        }

        var modeTint: Color {
            switch self {
            case .standard:
                return Theme.primaryAccent
            case .brainDump:
                return Theme.primaryAccent
            case .routines:
                return Color(hex: "10B981")
            }
        }
    }

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var preferences: [AppPreferences]
    @Query(sort: \BrainDumpItem.updatedAt, order: .reverse) private var brainDumpItems: [BrainDumpItem]
    @Query(sort: \ScheduleTemplate.sortOrder) private var templates: [ScheduleTemplate]
    @Query private var allBlocks: [TimeBlock]

    @State private var showingSubscription = false

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
    @State private var isShowingDetailsScreen: Bool
    @State private var selectedSetupIconSymbol: String
    @State private var selectedSetupAccentID: String

    private let editingBlockID: UUID?
    private let initialEntryMode: EntryMode
    private let onSave: (Date) -> Void
    private let onDelete: ((Date) -> Void)?
    private let startsWithSetupScreen: Bool

    enum EditorField: Hashable {
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
        _isShowingDetailsScreen = State(initialValue: false)
        let initialCategory = resolvedDraft?.category ?? .custom
        _selectedSetupIconSymbol = State(initialValue: AddTimeBlockView.defaultSetupIconSymbol(for: initialCategory))
        _selectedSetupAccentID = State(initialValue: AddTimeBlockView.defaultSetupAccentID(for: initialCategory))
        self.startsWithSetupScreen = entryMode == .standard &&
            editingBlockID == nil &&
            (resolvedDraft?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        self.editingBlockID = editingBlockID
        self.initialEntryMode = entryMode
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                if startsWithSetupScreen {
                    setupChooserScreen
                } else {
                    blockEditorScreen
                }
            }
            .navigationDestination(isPresented: $isShowingDetailsScreen) {
                blockEditorScreen
            }
        }
        .task(id: preferences.first?.updatedAt) {
            applyDefaultDurationIfNeeded()
        }
        .onAppear {
            guard !isEditing else {
                return
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                focusedField = selectedMode == .brainDump ? .brainDumpTitle : .title
            }
        }
        .onChange(of: selectedMode) { _, newValue in
            guard !isEditing else {
                return
            }

            focusedField = newValue == .brainDump ? .brainDumpTitle : .title
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
        .timeSubscriptionPresentation(isPresented: $showingSubscription)
    }

    private var isEditing: Bool {
        editingBlockID != nil
    }

    private var showsBrainDumpFirst: Bool {
        !isEditing && initialEntryMode == .brainDump
    }

    private var showsEntryModePicker: Bool {
        !isEditing && !startsWithSetupScreen
    }

    private var navigationTitle: String {
        selectedMode == .brainDump ? "Brain Dump" : (selectedMode == .routines ? "Routines" : "New Block")
    }

    private var editorNavigationTitle: String {
        if isEditing {
            return "Edit Block"
        }

        return startsWithSetupScreen ? "Block Details" : navigationTitle
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

    private var setupChooserScreen: some View {
        SetupChooserScreen(
            selectedMode: $selectedMode,
            dismissAction: dismiss.callAsFunction,
            heroSection: { setupHeroSection },
            switcherSection: { setupModeSwitcherSection },
            standardContent: {
                VStack(alignment: .leading, spacing: 20) {
                    titleSetupSection
                    iconPickerSection
                    colorPickerSection
                    suggestionPickerSection

                    Button("Continue") {
                        continueToDetails()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentSetupAccentColor)
                    .controlSize(.large)
                    .disabled(trimmedTitle.isEmpty)
                }
            },
            brainDumpContent: {
                ChooserModeIntroCard(
                    title: "Capture it before it disappears",
                    subtitle: "Brain Dump stays unscheduled. Save the thought now, then turn it into a block or routine later.",
                    icon: "text.badge.plus",
                    tint: Theme.primaryAccent
                )

                brainDumpCaptureSection
            },
            routinesContent: {
                ChooserModeIntroCard(
                    title: "Build reusable planning patterns",
                    subtitle: "Routines help recurring blocks regenerate later, so this stays separate from one-off schedule edits.",
                    icon: "square.on.square",
                    tint: Color(hex: "10B981")
                )

                routinesShortcutsSection
            }
        )
    }

    private var blockEditorScreen: some View {
        BlockEditorScreen(
            sectionTitle: sectionTitle,
            subtitle: isEditing
                ? "Update this planned block for the selected day"
                : sectionSubtitle,
            isEditing: isEditing,
            isBlockMissing: isEditing && editingBlock == nil,
            showsEntryModePicker: showsEntryModePicker,
            selectedMode: $selectedMode,
            showsBrainDumpFirst: showsBrainDumpFirst,
            errorMessage: errorMessage,
            isShowingDeleteConfirmation: $isShowingDeleteConfirmation,
            editorNavigationTitle: editorNavigationTitle,
            startsWithSetupScreen: startsWithSetupScreen,
            saveButtonTitle: saveButtonTitle,
            isSaveDisabled: isSaveDisabled,
            dismissAction: dismiss.callAsFunction,
            saveBrainDumpAction: saveBrainDumpItem,
            saveBlockAction: saveBlock,
            routinesContent: { routinesShortcutsSection },
            brainDumpCaptureContent: { brainDumpCaptureSection },
            brainDumpContent: { brainDumpSection },
            schedulingContent: { schedulingSection },
            checklistContent: {
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
        )
    }

    private var titleSetupSection: some View {
        TitleSetupSection(
            title: $title,
            currentSetupAccentColor: currentSetupAccentColor,
            selectedSetupIconSymbol: selectedSetupIconSymbol,
            focusedField: $focusedField,
            continueToDetails: continueToDetails
        )
    }

    private var iconPickerSection: some View {
        IconPickerSection(
            selectedSetupIconSymbol: $selectedSetupIconSymbol,
            category: $category,
            selectedSetupAccentID: $selectedSetupAccentID,
            currentSetupAccentColor: currentSetupAccentColor,
            setupIconOptions: setupIconOptions,
            selectedSetupAccentCategory: selectedSetupAccent?.category
        )
    }

    private var colorPickerSection: some View {
        ColorPickerSection(
            selectedSetupAccentID: $selectedSetupAccentID,
            category: $category,
            selectedSetupIconSymbol: $selectedSetupIconSymbol,
            setupAccentOptions: setupAccentOptions,
            selectedSetupIconCategory: selectedSetupIcon?.category
        )
    }

    private var suggestionPickerSection: some View {
        SuggestionPickerSection(
            trimmedTitle: trimmedTitle,
            suggestionSummaryText: suggestionSummaryText,
            suggestionGroups: suggestionGroups,
            filteredSuggestions: filteredSuggestions,
            applySuggestion: applySuggestion
        )
    }

    private var suggestionSummaryText: String {
        if trimmedTitle.isEmpty {
            return "\(suggestions.count) realistic ideas ready to use."
        }

        return filteredSuggestions.isEmpty
            ? "No exact matches, but you can keep your custom title and continue."
            : "\(filteredSuggestions.count) suggestions match \"\(trimmedTitle)\"."
    }

    private var filteredSuggestions: [TimeBlockSuggestion] {
        guard !trimmedTitle.isEmpty else {
            return suggestions
        }

        let query = trimmedTitle.localizedLowercase
        return suggestions.filter { suggestion in
            suggestion.title.localizedLowercase.contains(query) ||
            suggestion.category.title.localizedLowercase.contains(query) ||
            suggestion.notes.localizedLowercase.contains(query)
        }
    }


    private var brainDumpCaptureSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            BrainDumpCaptureSection(
                brainDumpTitle: $brainDumpTitle,
                brainDumpNotes: $brainDumpNotes,
                editingBrainDumpItemID: editingBrainDumpItemID,
                brainDumpItemsCount: brainDumpItems.count,
                trimmedBrainDumpTitle: trimmedBrainDumpTitle,
                focusedField: $focusedField,
                saveAction: saveBrainDumpItem,
                resetAction: resetBrainDumpComposer
            )

            Divider()

            BrainDumpInboxSection(
                brainDumpItems: brainDumpItems.map { $0 },
                editingBrainDumpItemID: editingBrainDumpItemID,
                startBlockConversion: startBlockConversion,
                startRoutineConversion: startRoutineConversion,
                loadForEditing: loadBrainDumpItemForEditing,
                deleteItem: deleteBrainDumpItem
            )
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
                                focusedField == .title ? Theme.primaryAccent.opacity(0.5) : Color.primary.opacity(0.08),
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
                            focusedField == .notes ? Theme.primaryAccent.opacity(0.5) : Color.primary.opacity(0.08),
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
        // Enforce 10-block limit for non-premium users
        let isPremium = preferences.first?.isPremium ?? false
        if !isPremium && !isEditing && allBlocks.count >= 10 {
            HapticManager.shared.warning()
            showingSubscription = true
            return
        }

        do {
            if let editingBlockID {
                guard let block = fetchBlock(id: editingBlockID) else {
                    errorMessage = String(localized: "This time block is no longer available.")
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
            HapticManager.shared.success()
            dismiss()
        } catch {
            errorMessage = String(localized: "Unable to save this time block right now.")
            logger.error("Failed to save time block: \(error)")
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
            HapticManager.shared.success()
            resetBrainDumpComposer()
        } catch {
            errorMessage = String(localized: "Unable to save this inbox item right now.")
            logger.error("Failed to save brain dump item: \(error)")
        }
    }

    private func deleteBlock() {
        guard let editingBlockID, let block = fetchBlock(id: editingBlockID) else {
            errorMessage = String(localized: "This time block is no longer available.")
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
            errorMessage = String(localized: "Unable to delete this time block right now.")
            logger.error("Failed to delete time block: \(error)")
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
            errorMessage = String(localized: "Unable to delete this inbox item right now.")
            logger.error("Failed to delete brain dump item: \(error)")
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
            HapticManager.shared.lightImpact()
            onSave(savedDate)
        } catch {
            errorMessage = String(localized: "Saved the conversion, but could not remove the inbox item.")
            logger.error("Failed to finalize brain dump conversion: \(error)")
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

    private func applySuggestion(_ suggestion: TimeBlockSuggestion) {
        title = suggestion.title
        category = suggestion.category
        durationMinutes = suggestion.durationMinutes
        selectedSetupIconSymbol = Self.defaultSetupIconSymbol(for: suggestion.category)
        selectedSetupAccentID = Self.defaultSetupAccentID(for: suggestion.category)
        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes = suggestion.notes
        }
        focusedField = .title
    }

    private func continueToDetails() {
        guard !trimmedTitle.isEmpty else {
            return
        }

        HapticManager.shared.lightImpact()
        isShowingDetailsScreen = true
        focusedField = .title
    }

    private var selectedSetupIcon: SetupIconOption? {
        setupIconOptions.first { $0.symbolName == selectedSetupIconSymbol }
    }

    private var selectedSetupAccent: SetupAccentOption? {
        setupAccentOptions.first { $0.id == selectedSetupAccentID }
    }

    private var currentSetupAccentColor: Color {
        selectedSetupAccent?.tintColor ?? category.tintColor
    }

    private var currentChooserTint: Color {
        selectedMode == .standard ? currentSetupAccentColor : selectedMode.modeTint
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

    private var setupHeroSection: some View {
        SetupHeroSection(
            selectedMode: selectedMode,
            category: category,
            selectedSetupIconSymbol: selectedSetupIconSymbol,
            currentSetupAccentColor: currentSetupAccentColor,
            currentChooserTint: currentChooserTint
        )
    }

    private var setupModeSwitcherSection: some View {
        SetupModeSwitcherSection(selectedMode: $selectedMode)
    }







    private var routinesShortcutsSection: some View {
        RoutinesShortcutsSection(
            isPresentingNewTemplateEditor: $isPresentingNewTemplateEditor,
            templates: templates.map { $0 },
            editingTemplate: $editingTemplate,
            onOpenFullSettings: {
                appEnvironment.appState.showTemplates()
                dismiss()
            }
        )
    }
}





#Preview {
    AddTimeBlockView(selectedDate: .now)
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}
