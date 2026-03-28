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

private struct TimeBlockSuggestion: Identifiable {
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

private struct SetupIconOption: Identifiable {
    let id: String
    let symbolName: String
    let title: String
    let category: TimeBlockCategory
}

private struct SetupAccentOption: Identifiable {
    let id: String
    let title: String
    let tintColor: Color
    let category: TimeBlockCategory
}

private struct SuggestionGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let suggestions: [TimeBlockSuggestion]
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
                return Theme.primaryPurple
            case .brainDump:
                return Theme.primaryPurple
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

            focusedField = selectedMode == .brainDump ? .brainDumpTitle : .title
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                setupHeroSection

                TimeCard {
                    VStack(alignment: .leading, spacing: 24) {
                        setupModeSwitcherSection

                        Divider()

                        switch selectedMode {
                        case .standard:
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
                        case .brainDump:
                            chooserModeIntroCard(
                                title: "Capture it before it disappears",
                                subtitle: "Brain Dump stays unscheduled. Save the thought now, then turn it into a block or routine later.",
                                icon: "text.badge.plus",
                                tint: Theme.primaryPurple
                            )

                            brainDumpCaptureSection
                        case .routines:
                            chooserModeIntroCard(
                                title: "Build reusable planning patterns",
                                subtitle: "Routines help recurring blocks regenerate later, so this stays separate from one-off schedule edits.",
                                icon: "square.on.square",
                                tint: Color(hex: "10B981")
                            )

                            routinesShortcutsSection
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .navigationTitle("Add")
        .timeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private var blockEditorScreen: some View {
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
                            if showsEntryModePicker {
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
        .navigationTitle(editorNavigationTitle)
        .timeInlineNavigationTitle()
        .toolbar {
            if !startsWithSetupScreen {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    }

    private var titleSetupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(currentSetupAccentColor.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: selectedSetupIconSymbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(currentSetupAccentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("New Block Setup")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Choose a clear title, visual style, and starter idea before opening the full editor.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Text("Title")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 4)

            TextField("What is this block?", text: $title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
                .submitLabel(.continue)
                .focused($focusedField, equals: .title)
                .onSubmit(continueToDetails)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            focusedField == .title ? currentSetupAccentColor.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: focusedField == .title ? 1.5 : 1
                        )
                }
        }
    }

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeSectionHeader(
                "Icon",
                subtitle: "Choose a visual that matches the kind of block you are creating."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                ForEach(setupIconOptions) { option in
                    Button {
                        selectedSetupIconSymbol = option.symbolName
                        if category != option.category {
                            category = option.category
                        }
                        if selectedSetupAccent?.category != option.category {
                            selectedSetupAccentID = Self.defaultSetupAccentID(for: option.category)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(option.symbolName == selectedSetupIconSymbol ? currentSetupAccentColor.opacity(0.16) : Color.primary.opacity(0.05))
                                    .frame(width: 40, height: 40)

                                Image(systemName: option.symbolName)
                                .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(option.symbolName == selectedSetupIconSymbol ? currentSetupAccentColor : Theme.secondaryText)
                            }

                            Text(option.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(option.symbolName == selectedSetupIconSymbol ? currentSetupAccentColor.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(option.symbolName == selectedSetupIconSymbol ? currentSetupAccentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: option.symbolName == selectedSetupIconSymbol ? 1.5 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeSectionHeader(
                "Color",
                subtitle: "Pick from a wider palette while keeping the existing block category system underneath."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 12)], spacing: 12) {
                ForEach(setupAccentOptions) { option in
                    Button {
                        selectedSetupAccentID = option.id
                        if category != option.category {
                            category = option.category
                        }
                        if selectedSetupIcon?.category != option.category {
                            selectedSetupIconSymbol = Self.defaultSetupIconSymbol(for: option.category)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(option.tintColor)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(option.id == selectedSetupAccentID ? 0.9 : 0), lineWidth: 2)
                                        .padding(4)
                                }

                            Text(option.title)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(option.id == selectedSetupAccentID ? option.tintColor.opacity(0.14) : Color.primary.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(option.id == selectedSetupAccentID ? option.tintColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: option.id == selectedSetupAccentID ? 1.5 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var suggestionPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeSectionHeader(
                "Suggestions",
                subtitle: "Structured starter options inspired by the Chores quick-select pattern. Tap one to prefill this block."
            )

            Text(suggestionSummaryText)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            if trimmedTitle.isEmpty {
                VStack(spacing: 14) {
                    ForEach(suggestionGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(group.title)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)

                                    Text(group.subtitle)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }

                                Spacer(minLength: 0)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(group.suggestions) { suggestion in
                                        suggestionPresetChip(suggestion)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredSuggestions) { suggestion in
                        suggestionMatchRow(suggestion)
                    }

                    if filteredSuggestions.isEmpty {
                        Text("No exact match yet. Keep your custom title and continue into the full editor.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                            )
                    }
                }
            }
        }
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

    private var suggestionGroups: [SuggestionGroup] {
        [
            SuggestionGroup(
                id: "focus",
                title: "Focus Blocks",
                subtitle: "Protected work and meaningful progress",
                suggestions: suggestions.filter { $0.category == .focus }.prefix(6).map { $0 }
            ),
            SuggestionGroup(
                id: "admin",
                title: "Life Admin",
                subtitle: "Small tasks that deserve a home on the calendar",
                suggestions: suggestions.filter { $0.category == .admin }.prefix(6).map { $0 }
            ),
            SuggestionGroup(
                id: "personal",
                title: "Personal Time",
                subtitle: "Health, errands, and home rhythms",
                suggestions: suggestions.filter { $0.category == .personal }.prefix(6).map { $0 }
            ),
            SuggestionGroup(
                id: "routine",
                title: "Repeatable Anchors",
                subtitle: "Reliable planning rituals and resets",
                suggestions: suggestions.filter { $0.category == .routine }.prefix(6).map { $0 }
            )
        ]
    }

    private var suggestions: [TimeBlockSuggestion] {
        [
            TimeBlockSuggestion(title: "Deep Work Sprint", category: .focus, durationMinutes: 90, notes: "Protect a stretch for concentrated work with notifications off."),
            TimeBlockSuggestion(title: "Write Project Proposal", category: .focus, durationMinutes: 60, notes: "Draft the key sections and leave time for a quick review."),
            TimeBlockSuggestion(title: "Code Review", category: .focus, durationMinutes: 45, notes: "Review open pull requests and leave clear feedback."),
            TimeBlockSuggestion(title: "Product Planning", category: .focus, durationMinutes: 60, notes: "Clarify priorities, goals, and next milestones."),
            TimeBlockSuggestion(title: "Study Session", category: .focus, durationMinutes: 75, notes: "Focus on one subject and capture takeaways while they are fresh."),
            TimeBlockSuggestion(title: "Write Newsletter", category: .focus, durationMinutes: 60, notes: "Outline, draft, and polish the next issue."),
            TimeBlockSuggestion(title: "Portfolio Work", category: .focus, durationMinutes: 90, notes: "Make visible progress on a meaningful long-term project."),
            TimeBlockSuggestion(title: "Client Meeting Prep", category: .focus, durationMinutes: 45, notes: "Review agenda, goals, and questions before the call."),
            TimeBlockSuggestion(title: "Mock Interview", category: .focus, durationMinutes: 60, notes: "Practice answers and tighten your stories."),
            TimeBlockSuggestion(title: "Design Exploration", category: .focus, durationMinutes: 75, notes: "Generate options before narrowing down."),
            TimeBlockSuggestion(title: "Research Competitors", category: .focus, durationMinutes: 60, notes: "Compare positioning, features, and useful patterns."),
            TimeBlockSuggestion(title: "Write Documentation", category: .focus, durationMinutes: 45, notes: "Capture the process clearly while it is still fresh."),
            TimeBlockSuggestion(title: "Prepare Presentation", category: .focus, durationMinutes: 90, notes: "Build the deck and tighten the flow."),
            TimeBlockSuggestion(title: "Interview Candidate", category: .focus, durationMinutes: 60, notes: "Give yourself time for notes and scorecard follow-up."),
            TimeBlockSuggestion(title: "Budget Review", category: .admin, durationMinutes: 30, notes: "Check spending, upcoming bills, and anything unusual."),
            TimeBlockSuggestion(title: "Inbox Zero", category: .admin, durationMinutes: 30, notes: "Reply, archive, delegate, and clear quick follow-ups."),
            TimeBlockSuggestion(title: "Pay Bills", category: .admin, durationMinutes: 20, notes: "Handle anything due soon and confirm payments went through."),
            TimeBlockSuggestion(title: "Calendar Reset", category: .admin, durationMinutes: 20, notes: "Review upcoming commitments and update your plan."),
            TimeBlockSuggestion(title: "Admin Catch-Up", category: .admin, durationMinutes: 45, notes: "Knock out forms, docs, and little tasks that pile up."),
            TimeBlockSuggestion(title: "Call Insurance", category: .admin, durationMinutes: 30, notes: "Handle policy questions or claim follow-up."),
            TimeBlockSuggestion(title: "Submit Expense Report", category: .admin, durationMinutes: 25, notes: "Attach receipts and get reimbursement moving."),
            TimeBlockSuggestion(title: "Tax Prep", category: .admin, durationMinutes: 60, notes: "Gather documents and make progress before deadlines creep in."),
            TimeBlockSuggestion(title: "Schedule Appointments", category: .admin, durationMinutes: 20, notes: "Book the calls and visits you have been postponing."),
            TimeBlockSuggestion(title: "Plan Travel", category: .admin, durationMinutes: 45, notes: "Confirm logistics, bookings, and timing."),
            TimeBlockSuggestion(title: "Organize Files", category: .admin, durationMinutes: 30, notes: "Clean up folders so future-you can find things quickly."),
            TimeBlockSuggestion(title: "Return Calls", category: .admin, durationMinutes: 25, notes: "Clear missed calls and quick follow-ups."),
            TimeBlockSuggestion(title: "Renew Prescriptions", category: .admin, durationMinutes: 20, notes: "Handle pharmacy refills before they become urgent."),
            TimeBlockSuggestion(title: "Meal Prep", category: .personal, durationMinutes: 90, notes: "Prep food that makes the next few days easier."),
            TimeBlockSuggestion(title: "Workout", category: .personal, durationMinutes: 60, notes: "Leave a little setup and cooldown time around the session."),
            TimeBlockSuggestion(title: "Walk the Dog", category: .personal, durationMinutes: 30, notes: "Fresh air, movement, and a reliable reset."),
            TimeBlockSuggestion(title: "Buy Groceries", category: .personal, durationMinutes: 45, notes: "Pick up essentials and anything needed for the week."),
            TimeBlockSuggestion(title: "School Pickup", category: .personal, durationMinutes: 30, notes: "Buffer for traffic and handoff timing."),
            TimeBlockSuggestion(title: "Family Time", category: .personal, durationMinutes: 90, notes: "Protect a stretch for connection without multitasking."),
            TimeBlockSuggestion(title: "Doctor Appointment", category: .personal, durationMinutes: 60, notes: "Include travel, check-in, and follow-up notes."),
            TimeBlockSuggestion(title: "Meditation", category: .personal, durationMinutes: 15, notes: "A small reset block to slow down and breathe."),
            TimeBlockSuggestion(title: "House Cleaning", category: .personal, durationMinutes: 60, notes: "A focused reset that makes the space feel calmer."),
            TimeBlockSuggestion(title: "Laundry", category: .personal, durationMinutes: 45, notes: "Start, switch, and fold if time allows."),
            TimeBlockSuggestion(title: "Cook Dinner", category: .personal, durationMinutes: 60, notes: "Prep, cook, and give yourself a little cleanup time."),
            TimeBlockSuggestion(title: "Coffee with Friend", category: .personal, durationMinutes: 60, notes: "Protect time for connection without rushing."),
            TimeBlockSuggestion(title: "Pick Up Prescription", category: .personal, durationMinutes: 20, notes: "Quick errand with just enough travel buffer."),
            TimeBlockSuggestion(title: "Stretch Break", category: .personal, durationMinutes: 15, notes: "A short recovery block to reset posture and energy."),
            TimeBlockSuggestion(title: "Nap", category: .personal, durationMinutes: 30, notes: "Short rest block to recharge without drifting too long."),
            TimeBlockSuggestion(title: "Journal", category: .personal, durationMinutes: 20, notes: "Capture thoughts, feelings, and loose reflections."),
            TimeBlockSuggestion(title: "Morning Routine", category: .routine, durationMinutes: 45, notes: "Anchor the day with a repeatable start."),
            TimeBlockSuggestion(title: "Evening Reset", category: .routine, durationMinutes: 30, notes: "Tidy up, close loops, and set up tomorrow."),
            TimeBlockSuggestion(title: "Weekly Review", category: .routine, durationMinutes: 60, notes: "Reflect on the week and plan the next one."),
            TimeBlockSuggestion(title: "Daily Planning", category: .routine, durationMinutes: 15, notes: "Pick priorities and shape the day with intention."),
            TimeBlockSuggestion(title: "Desk Reset", category: .routine, durationMinutes: 10, notes: "Clear the workspace so the next block starts clean."),
            TimeBlockSuggestion(title: "Reading Time", category: .routine, durationMinutes: 30, notes: "Consistent reading block for growth or enjoyment."),
            TimeBlockSuggestion(title: "Practice Guitar", category: .routine, durationMinutes: 30, notes: "Keep the streak alive with a focused practice block."),
            TimeBlockSuggestion(title: "Water the Plants", category: .routine, durationMinutes: 15, notes: "A quick home reset task that is easy to forget."),
            TimeBlockSuggestion(title: "Team Standup", category: .routine, durationMinutes: 15, notes: "A recurring quick sync to align on the day."),
            TimeBlockSuggestion(title: "Email Triage", category: .routine, durationMinutes: 20, notes: "A contained pass through messages instead of constant checking."),
            TimeBlockSuggestion(title: "Shut Down Workday", category: .routine, durationMinutes: 20, notes: "Close tabs, capture loose ends, and plan tomorrow."),
            TimeBlockSuggestion(title: "Plan Tomorrow", category: .routine, durationMinutes: 15, notes: "Pick the key blocks before the next day starts."),
            TimeBlockSuggestion(title: "Language Practice", category: .routine, durationMinutes: 25, notes: "Small repeatable practice adds up over time."),
            TimeBlockSuggestion(title: "Read with Kids", category: .routine, durationMinutes: 20, notes: "A repeatable family block that is easy to treasure."),
            TimeBlockSuggestion(title: "Medication Reminder", category: .routine, durationMinutes: 10, notes: "A recurring health-support block with zero friction."),
            TimeBlockSuggestion(title: "Tidy Living Room", category: .routine, durationMinutes: 15, notes: "A light reset that keeps the house from drifting."),
            TimeBlockSuggestion(title: "Catch Up on Messages", category: .custom, durationMinutes: 25, notes: "Texts, DMs, and loose replies in one contained block."),
            TimeBlockSuggestion(title: "Brainstorm Ideas", category: .custom, durationMinutes: 45, notes: "Capture possibilities first, then sort them later."),
            TimeBlockSuggestion(title: "Life Admin", category: .custom, durationMinutes: 45, notes: "A flexible bucket for all the little things that need attention."),
            TimeBlockSuggestion(title: "Transition Buffer", category: .custom, durationMinutes: 15, notes: "Leave breathing room between heavier commitments."),
            TimeBlockSuggestion(title: "Personal Project", category: .custom, durationMinutes: 60, notes: "Move a self-directed project forward without overplanning."),
            TimeBlockSuggestion(title: "Errands Run", category: .custom, durationMinutes: 60, notes: "Bundle nearby stops into one efficient outing."),
            TimeBlockSuggestion(title: "Reset and Recenter", category: .custom, durationMinutes: 20, notes: "Short block to breathe, tidy, and get back on track."),
            TimeBlockSuggestion(title: "Open Space", category: .custom, durationMinutes: 30, notes: "A flexible block for whatever needs your attention most.")
        ]
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

    private var setupIconOptions: [SetupIconOption] {
        [
            SetupIconOption(id: "scope", symbolName: "scope", title: "Focus", category: .focus),
            SetupIconOption(id: "laptopcomputer", symbolName: "laptopcomputer", title: "Laptop", category: .focus),
            SetupIconOption(id: "doc.text.fill", symbolName: "doc.text.fill", title: "Write", category: .focus),
            SetupIconOption(id: "chart.bar.fill", symbolName: "chart.bar.fill", title: "Plan", category: .focus),
            SetupIconOption(id: "lightbulb.fill", symbolName: "lightbulb.fill", title: "Ideas", category: .focus),
            SetupIconOption(id: "tray.full.fill", symbolName: "tray.full.fill", title: "Admin", category: .admin),
            SetupIconOption(id: "calendar.badge.clock", symbolName: "calendar.badge.clock", title: "Calendar", category: .admin),
            SetupIconOption(id: "envelope.fill", symbolName: "envelope.fill", title: "Email", category: .admin),
            SetupIconOption(id: "creditcard.fill", symbolName: "creditcard.fill", title: "Bills", category: .admin),
            SetupIconOption(id: "folder.fill", symbolName: "folder.fill", title: "Files", category: .admin),
            SetupIconOption(id: "figure.walk", symbolName: "figure.walk", title: "Walk", category: .personal),
            SetupIconOption(id: "heart.fill", symbolName: "heart.fill", title: "Health", category: .personal),
            SetupIconOption(id: "cart.fill", symbolName: "cart.fill", title: "Errands", category: .personal),
            SetupIconOption(id: "dumbbell.fill", symbolName: "dumbbell.fill", title: "Workout", category: .personal),
            SetupIconOption(id: "fork.knife", symbolName: "fork.knife", title: "Meals", category: .personal),
            SetupIconOption(id: "repeat", symbolName: "repeat", title: "Repeat", category: .routine),
            SetupIconOption(id: "sunrise.fill", symbolName: "sunrise.fill", title: "Morning", category: .routine),
            SetupIconOption(id: "moon.stars.fill", symbolName: "moon.stars.fill", title: "Evening", category: .routine),
            SetupIconOption(id: "alarm.fill", symbolName: "alarm.fill", title: "Habit", category: .routine),
            SetupIconOption(id: "checkmark.circle.fill", symbolName: "checkmark.circle.fill", title: "Reset", category: .routine),
            SetupIconOption(id: "square.grid.2x2.fill", symbolName: "square.grid.2x2.fill", title: "General", category: .custom),
            SetupIconOption(id: "sparkles", symbolName: "sparkles", title: "Fresh", category: .custom),
            SetupIconOption(id: "flag.fill", symbolName: "flag.fill", title: "Priority", category: .custom),
            SetupIconOption(id: "bookmark.fill", symbolName: "bookmark.fill", title: "Keep", category: .custom),
            SetupIconOption(id: "bolt.fill", symbolName: "bolt.fill", title: "Quick", category: .custom)
        ]
    }

    private var setupAccentOptions: [SetupAccentOption] {
        [
            SetupAccentOption(id: "focus-violet", title: "Violet", tintColor: Theme.primaryPurple, category: .focus),
            SetupAccentOption(id: "focus-indigo", title: "Indigo", tintColor: Color(hex: "6366F1"), category: .focus),
            SetupAccentOption(id: "admin-sky", title: "Sky", tintColor: Color(hex: "0EA5E9"), category: .admin),
            SetupAccentOption(id: "admin-cobalt", title: "Cobalt", tintColor: Color(hex: "2563EB"), category: .admin),
            SetupAccentOption(id: "personal-amber", title: "Amber", tintColor: Color(hex: "F59E0B"), category: .personal),
            SetupAccentOption(id: "personal-coral", title: "Coral", tintColor: Color(hex: "F97316"), category: .personal),
            SetupAccentOption(id: "routine-mint", title: "Mint", tintColor: Color(hex: "10B981"), category: .routine),
            SetupAccentOption(id: "routine-teal", title: "Teal", tintColor: Color(hex: "14B8A6"), category: .routine),
            SetupAccentOption(id: "custom-slate", title: "Slate", tintColor: Color(hex: "64748B"), category: .custom),
            SetupAccentOption(id: "custom-stone", title: "Stone", tintColor: Color(hex: "78716C"), category: .custom)
        ]
    }

    private static func defaultSetupIconSymbol(for category: TimeBlockCategory) -> String {
        switch category {
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

    private static func defaultSetupAccentID(for category: TimeBlockCategory) -> String {
        switch category {
        case .focus:
            "focus-violet"
        case .personal:
            "personal-amber"
        case .admin:
            "admin-sky"
        case .routine:
            "routine-mint"
        case .custom:
            "custom-slate"
        }
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    currentChooserTint.opacity(0.22),
                                    currentChooserTint.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)

                    Image(systemName: selectedMode.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(currentChooserTint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Add to your day")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Start with a clean chooser, then continue into the right flow for a block, Brain Dump, or routine.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            HStack(spacing: 8) {
                setupStatPill(label: selectedMode.rawValue, icon: selectedMode.icon, tint: currentChooserTint)
                if selectedMode == .standard {
                    setupStatPill(label: category.title, icon: selectedSetupIconSymbol, tint: currentSetupAccentColor)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var setupModeSwitcherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeSectionHeader(
                "Create",
                subtitle: "Choose what you want the add flow to start with. New Block stays selected by default."
            )

            HStack(spacing: 10) {
                ForEach(EntryMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14, weight: .bold))
                                Spacer(minLength: 0)
                                if selectedMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }

                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .bold, design: .rounded))

                            Text(mode.setupDescription)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(2)
                        }
                        .foregroundStyle(selectedMode == mode ? Color.white : Theme.primaryText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedMode == mode ? mode.modeTint : Color.primary.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(selectedMode == mode ? mode.modeTint.opacity(0.2) : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chooserModeIntroCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
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

    private func setupStatPill(label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private func suggestionPresetChip(_ suggestion: TimeBlockSuggestion) -> some View {
        Button {
            applySuggestion(suggestion)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(suggestion.category.tintColor.opacity(0.14))
                        .frame(width: 30, height: 30)

                    Image(systemName: suggestion.category.symbolName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(suggestion.category.tintColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    Text("\(suggestion.durationMinutes)m")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(title == suggestion.title ? suggestion.category.tintColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: title == suggestion.title ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func suggestionMatchRow(_ suggestion: TimeBlockSuggestion) -> some View {
        Button {
            applySuggestion(suggestion)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(suggestion.category.tintColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: suggestion.category.symbolName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(suggestion.category.tintColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(suggestion.notes)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(suggestion.durationMinutes)m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text(suggestion.category.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(suggestion.category.tintColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(suggestion.category.tintColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(title == suggestion.title ? suggestion.category.tintColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: title == suggestion.title ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
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

    var colorLabel: String {
        switch self {
        case .focus:
            "Purple"
        case .personal:
            "Amber"
        case .admin:
            "Blue"
        case .routine:
            "Green"
        case .custom:
            "Slate"
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
