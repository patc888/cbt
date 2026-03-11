import Foundation
import SwiftData
import SwiftUI

struct TemplatesView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Query(sort: \ScheduleTemplate.sortOrder) private var templates: [ScheduleTemplate]
    @State private var editingTemplate: ScheduleTemplate?

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TimeCard {
                        VStack(alignment: .leading, spacing: 16) {
                            TimeSectionHeader("Routines & Templates", subtitle: "Reusable schedule structures for future block generation")

                            if templates.isEmpty {
                                ContentUnavailableView(
                                    "No Templates Yet",
                                    systemImage: "square.on.square",
                                    description: Text("Create reusable schedule templates that can generate planned blocks on the weekdays you choose.")
                                )
                                .padding(.vertical, 20)

                                Button(action: { appEnvironment.appState.isPresentingAddModal = true }) {
                                    HStack {
                                        Text("Create Template")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                        Spacer()
                                        Image(systemName: "plus")
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 20)
                                    .background(Theme.primaryPurple.gradient)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(templates) { template in
                                        Button {
                                            editingTemplate = template
                                        } label: {
                                            VStack(alignment: .leading, spacing: 10) {
                                                HStack(alignment: .top, spacing: 12) {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(template.name)
                                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                                            .foregroundStyle(Theme.primaryText)

                                                        Text("\(template.defaultDurationMinutes) minutes at \(timeText(for: template))")
                                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                                            .foregroundStyle(Theme.secondaryText)
                                                    }

                                                    Spacer(minLength: 12)

                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundStyle(.tertiary)
                                                        .padding(.top, 4)
                                                }

                                                HStack(spacing: 8) {
                                                    templateBadge(template.category.title, tint: Theme.primaryPurple)

                                                    let maskSummary = weekdaySummary(for: template.weekdayMask)
                                                    if !maskSummary.isEmpty {
                                                        templateBadge(maskSummary, tint: .secondary)
                                                    }
                                                }

                                                if let notes = template.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(.system(size: 12, design: .rounded))
                                                        .foregroundStyle(Theme.secondaryText)
                                                        .lineLimit(2)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)

                                        if template.id != templates.last?.id {
                                            Divider().padding(.vertical, 12)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TimeCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TimeSectionHeader("Generation", subtitle: "How templates are used")

                            Text("Templates continue to drive block generation through the existing repository flow. Editing a template changes future generated blocks only.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .padding()
                .padding(.top, 64) // Offset for custom header
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: Binding(
            get: { appEnvironment.appState.isPresentingAddModal },
            set: { appEnvironment.appState.isPresentingAddModal = $0 }
        )) {
            TemplateEditorView()
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(template: template)
        }
    }

    private func timeText(for template: ScheduleTemplate) -> String {
        let hour = template.defaultStartHour
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func templateBadge(_ text: String, tint: Color) -> some View {
        return Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func weekdaySummary(for mask: Int) -> String {
        let selectedDays = TemplateWeekday.allCases
            .filter { mask & $0.bitmask != 0 }
            .map(\.shortTitle)

        if selectedDays.count == TemplateWeekday.allCases.count {
            return "Every day"
        }

        return selectedDays.joined(separator: ", ")
    }
}

private struct TemplateEditorView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var notes: String
    @State private var defaultStartTime: Date
    @State private var durationMinutes: Int
    @State private var weekdayMask: Int
    @State private var category: TimeBlockCategory
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirmation = false

    private let template: ScheduleTemplate?

    init(template: ScheduleTemplate? = nil) {
        let calendar = Calendar.current
        let defaultDate = calendar.date(bySettingHour: template?.defaultStartHour ?? 8, minute: 0, second: 0, of: .now) ?? .now

        _name = State(initialValue: template?.name ?? "")
        _notes = State(initialValue: template?.notes ?? "")
        _defaultStartTime = State(initialValue: defaultDate)
        _durationMinutes = State(initialValue: max(template?.defaultDurationMinutes ?? 60, 15))
        _weekdayMask = State(initialValue: template?.weekdayMask ?? 0)
        _category = State(initialValue: template?.category ?? .routine)
        self.template = template
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TimeCard {
                        TimeSectionHeader(
                            template == nil ? "New Template" : "Edit Template",
                            subtitle: "Reusable defaults for schedule generation"
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Template Name", text: $name)

                            Picker("Start Time", selection: $defaultStartTime) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(hourLabel(for: hour)).tag(date(forHour: hour))
                                }
                            }

                            Stepper(value: $durationMinutes, in: 15...720, step: 15) {
                                LabeledContent("Duration", value: "\(durationMinutes) min")
                            }

                            Picker("Category", selection: $category) {
                                ForEach(TimeBlockCategory.allCases) { category in
                                    Text(category.title).tag(category)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Weekdays")
                                    .font(.subheadline.weight(.medium))

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                                    ForEach(TemplateWeekday.allCases) { weekday in
                                        Button {
                                            toggle(weekday)
                                        } label: {
                                            Text(weekday.shortTitle)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(isSelected(weekday) ? Theme.primaryPurple.opacity(0.18) : Color.secondary.opacity(0.1))
                                                )
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(isSelected(weekday) ? Theme.primaryPurple : Color.secondary.opacity(0.18), lineWidth: 1)
                                                }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(isSelected(weekday) ? Theme.primaryPurple : .primary)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.subheadline.weight(.medium))

                                TextEditor(text: $notes)
                                    .frame(minHeight: 120)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if template != nil {
                        Button("Delete Template", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .timeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(template == nil ? "Save" : "Update") {
                        saveTemplate()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .confirmationDialog(
                "Delete this template?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteTemplate()
                }
            } message: {
                Text("This removes the template, but does not delete blocks already generated from it.")
            }
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weekdayMask == 0
    }

    private func hourLabel(for hour: Int) -> String {
        let labelDate = date(forHour: hour)
        return labelDate.formatted(date: .omitted, time: .shortened)
    }

    private func date(forHour hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }

    private func isSelected(_ weekday: TemplateWeekday) -> Bool {
        weekdayMask & weekday.bitmask != 0
    }

    private func toggle(_ weekday: TemplateWeekday) {
        if isSelected(weekday) {
            weekdayMask &= ~weekday.bitmask
        } else {
            weekdayMask |= weekday.bitmask
        }
    }

    private func saveTemplate() {
        do {
            if let template {
                try appEnvironment.scheduleRepository.updateTemplate(
                    template,
                    name: name,
                    notes: notes,
                    defaultStartTime: defaultStartTime,
                    durationMinutes: durationMinutes,
                    weekdayMask: weekdayMask,
                    category: category,
                    in: modelContext
                )
            } else {
                try appEnvironment.scheduleRepository.createTemplate(
                    name: name,
                    notes: notes,
                    defaultStartTime: defaultStartTime,
                    durationMinutes: durationMinutes,
                    weekdayMask: weekdayMask,
                    category: category,
                    in: modelContext
                )
            }

            dismiss()
        } catch {
            errorMessage = "Unable to save this template right now."
            assertionFailure("Failed to save template: \(error)")
        }
    }

    private func deleteTemplate() {
        guard let template else {
            return
        }

        do {
            try appEnvironment.scheduleRepository.deleteTemplate(template, in: modelContext)
            dismiss()
        } catch {
            errorMessage = "Unable to delete this template right now."
            assertionFailure("Failed to delete template: \(error)")
        }
    }
}

private enum TemplateWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var bitmask: Int {
        return 1 << (rawValue - 1)
    }
}
