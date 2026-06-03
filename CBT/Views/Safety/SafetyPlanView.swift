import SwiftData
import SwiftUI

struct SafetyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SafetyPlan.updatedAt, order: .reverse) private var safetyPlans: [SafetyPlan]
    @State private var hasCompletedGroundingPreparation = false

    private var activePlan: SafetyPlan? {
        safetyPlans.first
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    AppScreenHeadline(title: String(localized: "Rough Patch Plan"))
                        .padding(.horizontal, DSSpacing.large)

                    CrisisSupportNoticeView(style: .full)
                        .padding(.horizontal, DSSpacing.large)

                    if !hasCompletedGroundingPreparation {
                        GroundingPreparationView(
                            title: String(localized: "Ground Before Safety Planning"),
                            message: String(localized: "Safety planning can bring up difficult details. You can take a 30-second breathing reset first, or continue straight to your plan."),
                            continueTitle: String(localized: "Open Rough Patch Plan")
                        ) {
                            hasCompletedGroundingPreparation = true
                        }
                        .padding(.horizontal, DSSpacing.large)
                    } else if let activePlan {
                        SafetyPlanEditor(plan: activePlan, onDelete: deleteActivePlan)
                    } else {
                        emptyState
                    }
                }
                .padding(.vertical, DSSpacing.large)
                .dsSettingsContentWidth()
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var emptyState: some View {
        SupportiveEmptyStateView(
            systemImage: "cross.case.fill",
            title: String(localized: "Rough Patch Plan"),
            message: String(localized: "Start by adding one warning sign and one grounding step you can use in a hard moment. This is not emergency care."),
            actionTitle: String(localized: "Create Rough Patch Plan"),
            actionSystemImage: "plus.circle.fill"
        ) {
            let plan = SafetyPlan()
            modelContext.insert(plan)
            try? modelContext.save()
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .padding(.horizontal, DSSpacing.large)
    }

    private func deleteActivePlan() {
        guard let activePlan else { return }
        modelContext.delete(activePlan)
        try? modelContext.save()
    }
}

private struct SafetyPlanEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    let plan: SafetyPlan
    let onDelete: () -> Void

    private let toolkitService = CopingToolkitService.shared
    private let toolkitStore = CopingToolkitStore()

    @State private var contacts: [EmergencyContact]
    @State private var warningSigns: [String]
    @State private var copingStrategies: [String]
    @State private var groundingSteps: [String]
    @State private var safePlaces: [String]
    @State private var reminders: [String]
    @State private var makesItWorse: [String]
    @State private var privacySafeDisplayEnabled: Bool
    @State private var showingDeleteConfirmation = false

    init(plan: SafetyPlan, onDelete: @escaping () -> Void) {
        self.plan = plan
        self.onDelete = onDelete
        _contacts = State(initialValue: plan.emergencyContacts)
        _warningSigns = State(initialValue: plan.personalWarningSigns)
        _copingStrategies = State(initialValue: plan.copingStrategies)
        _groundingSteps = State(initialValue: plan.groundingSteps)
        _safePlaces = State(initialValue: plan.safePlaces)
        _reminders = State(initialValue: plan.reminders)
        _makesItWorse = State(initialValue: plan.makesItWorse)
        _privacySafeDisplayEnabled = State(initialValue: plan.privacySafeDisplayEnabled)
    }

    var body: some View {
        VStack(spacing: DSSpacing.large) {
            supportNotice
            privacySection
            warningSignsSection
            copingSection
            toolkitSuggestionsSection
            groundingSection
            contactsSection
            safePlacesSection
            remindersSection
            makesItWorseSection
            deleteSection
        }
        .padding(.horizontal, DSSpacing.large)
        .onDisappear(perform: save)
        .confirmationDialog(
            String(localized: "Delete Rough Patch Plan?"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Rough Patch Plan"), role: .destructive, action: onDelete)
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This removes your saved rough patch plan details."))
        }
    }

    private var supportNotice: some View {
        CrisisSupportNoticeView(style: .compact)
    }

    private var privacySection: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                DSSectionHeader(
                    title: String(localized: "Privacy Display"),
                    subtitle: String(localized: "Keep sensitive details tucked away until you open this plan.")
                )

                Toggle(isOn: $privacySafeDisplayEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Privacy-safe summaries"))
                            .font(DSTypography.listLabel)
                            .foregroundStyle(DSTheme.primaryText)
                        Text(String(localized: "Home, widgets, lock screen, and shortcuts should use generic wording instead of your plan details."))
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .onChange(of: privacySafeDisplayEnabled) { _, _ in save() }
            }
        }
    }

    private var contactsSection: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "Trusted Contacts"),
                    subtitle: String(localized: "People you may want to reach when extra support would help.")
                ) {
                    addButton(title: String(localized: "Add Contact")) {
                        contacts.append(EmergencyContact())
                    }
                }

                if contacts.isEmpty {
                    emptyText(String(localized: "Supportive people are optional. Add one person you would feel okay reaching out to."))
                } else {
                    VStack(spacing: DSSpacing.medium) {
                        ForEach($contacts) { $contact in
                            EmergencyContactEditor(contact: $contact) {
                                contacts.removeAll { $0.id == contact.id }
                            }
                        }
                    }
                }

                DSPrimaryButton(title: String(localized: "Save Rough Patch Plan"), action: save)
            }
        }
    }

    private var warningSignsSection: some View {
        EditableStringListSection(
            title: String(localized: "Warning Signs"),
            subtitle: String(localized: "Thoughts, feelings, body cues, or situations that tell you support may help."),
            emptyMessage: String(localized: "Warning signs are personal cues. Add one sign you want your future self to notice."),
            addTitle: String(localized: "Add Sign"),
            placeholder: String(localized: "Warning sign"),
            values: $warningSigns,
            onSave: save
        )
    }

    private var copingSection: some View {
        EditableStringListSection(
            title: String(localized: "Helpful Actions"),
            subtitle: String(localized: "Helpful coping tools that may make the next few minutes easier."),
            emptyMessage: String(localized: "Helpful actions can be small. Add one grounding step, breath practice, or supportive action."),
            addTitle: String(localized: "Add Action"),
            placeholder: String(localized: "Helpful action"),
            values: $copingStrategies,
            onSave: save
        )
    }

    private var toolkitSuggestionsSection: some View {
        let suggestions = suggestedToolkitTools

        return DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "When I'm Spiraling"),
                    subtitle: String(localized: "Build this plan from tools you have saved or recently used.")
                )

                if suggestions.isEmpty {
                    emptyText(String(localized: "Tools you save from the Coping Toolkit will appear here as quick additions."))
                } else {
                    VStack(spacing: DSSpacing.small) {
                        ForEach(suggestions) { tool in
                            DSListRow(
                                icon: tool.systemImage,
                                iconColor: themeManager.selectedColor,
                                title: tool.title,
                                subtitle: "\(tool.kind) - \(tool.durationLabel)"
                            ) {
                                Button {
                                    addToolToCopingStrategies(tool)
                                } label: {
                                    Label(String(localized: "Add"), systemImage: "plus")
                                }
                                .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.selectedColor, hapticType: .light))
                                .accessibilityLabel(String(localized: "Add \(tool.title) to helpful actions"))
                            }
                            .padding(DSSpacing.medium)
                            .background(DSTheme.elevatedFill)
                            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var suggestedToolkitTools: [CopingToolkitTool] {
        let saved = toolkitService.copingPlanTools(using: toolkitStore, limit: 6)
        let recent = toolkitService.recentlyUsed(using: toolkitStore, limit: 6)
        var seen = Set<String>()

        return (saved + recent).filter { tool in
            guard seen.insert(tool.id).inserted else { return false }
            return !copingStrategies.contains(where: { normalizedStrategy($0) == normalizedStrategy(tool.title) })
        }
    }

    private var groundingSection: some View {
        EditableStringListSection(
            title: String(localized: "Grounding Steps"),
            subtitle: String(localized: "Simple steps that bring attention back to the room, body, breath, or present moment."),
            emptyMessage: String(localized: "Grounding can be brief. Add one step you can follow when things feel intense."),
            addTitle: String(localized: "Add Step"),
            placeholder: String(localized: "Grounding step"),
            values: $groundingSteps,
            onSave: save
        )
    }

    private var safePlacesSection: some View {
        EditableStringListSection(
            title: String(localized: "Safe Places"),
            subtitle: String(localized: "Places that usually feel steadier, calmer, or easier to be in."),
            emptyMessage: String(localized: "Add one place where you can usually pause or feel more settled."),
            addTitle: String(localized: "Add Place"),
            placeholder: String(localized: "Safe place"),
            values: $safePlaces,
            onSave: save
        )
    }

    private var remindersSection: some View {
        EditableStringListSection(
            title: String(localized: "Reminders"),
            subtitle: String(localized: "Words your future self may want nearby during a hard moment."),
            emptyMessage: String(localized: "Add a kind, realistic reminder you would want to read later."),
            addTitle: String(localized: "Add Reminder"),
            placeholder: String(localized: "Reminder"),
            values: $reminders,
            onSave: save
        )
    }

    private var makesItWorseSection: some View {
        EditableStringListSection(
            title: String(localized: "Usually Makes It Worse"),
            subtitle: String(localized: "Patterns, places, topics, or actions that tend to raise distress."),
            emptyMessage: String(localized: "Add one thing you may want to avoid or handle gently when you are already overloaded."),
            addTitle: String(localized: "Add Item"),
            placeholder: String(localized: "Usually makes it worse"),
            values: $makesItWorse,
            onSave: save
        )
    }

    private var deleteSection: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                DSSectionHeader(
                    title: String(localized: "Plan Management"),
                    subtitle: String(localized: "Delete this plan and start over.")
                )

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label(String(localized: "Delete Rough Patch Plan"), systemImage: "trash")
                }
                .buttonStyle(DSSecondaryButtonStyle())
            }
        }
    }

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .buttonStyle(DSButtonStyle(variant: .primary, size: .icon(36), expands: false, tint: themeManager.selectedColor, hapticType: .light))
        .accessibilityLabel(title)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(DSTypography.body)
            .foregroundStyle(DSTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DSSpacing.small)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        plan.emergencyContacts = contacts
        plan.personalWarningSigns = warningSigns
        plan.copingStrategies = copingStrategies
        plan.groundingSteps = groundingSteps
        plan.safePlaces = safePlaces
        plan.reminders = reminders
        plan.makesItWorse = makesItWorse
        plan.privacySafeDisplayEnabled = privacySafeDisplayEnabled
        plan.updatedAt = Date()
        try? modelContext.save()
    }

    private func addToolToCopingStrategies(_ tool: CopingToolkitTool) {
        guard !copingStrategies.contains(where: { normalizedStrategy($0) == normalizedStrategy(tool.title) }) else { return }
        copingStrategies.insert(tool.title, at: 0)
        save()
        HapticManager.shared.success()
    }

    private func normalizedStrategy(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct CrisisSupportNoticeView: View {
    enum Style {
        case compact
        case full
    }

    @Environment(ThemeManager.self) private var themeManager

    let style: Style
    var planActionTitle: String = String(localized: "Open Rough Patch Plan")
    var onOpenPlan: (() -> Void)?

    private var message: String {
        switch style {
        case .compact:
            return String(localized: "This app is self-help, not medical care or emergency support. If you might harm yourself or someone else, or you are in immediate danger, contact local emergency services now. In the U.S. call or text 988 for crisis support.")
        case .full:
            return String(localized: "CBT is a self-help tool. It is not medical care, therapy, diagnosis, treatment, or emergency support. If you might harm yourself or someone else, or you are in immediate danger, contact local emergency services now. In the U.S. call or text 988 for crisis support.")
        }
    }

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                HStack(alignment: .top, spacing: DSSpacing.medium) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .padding(.top, 2)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Not Medical Care"))
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(DSTheme.primaryText)

                        Text(message)
                            .font(style == .full ? DSTypography.body : DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    actionRow
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        actionRowContent
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: DSSpacing.small) {
            actionRowContent
        }
    }

    @ViewBuilder
    private var actionRowContent: some View {
        if let onOpenPlan {
            Button {
                HapticManager.shared.selection()
                onOpenPlan()
            } label: {
                Label(planActionTitle, systemImage: "lifepreserver.fill")
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.selectedColor, hapticType: .light))
        }

        if let emergencyURL = URL(string: "tel:911") {
            Link(destination: emergencyURL) {
                Label(String(localized: "Call 911"), systemImage: "phone.badge.waveform.fill")
            }
            .buttonStyle(DSButtonStyle(variant: .destructive, size: .compact, expands: false, tint: themeManager.selectedColor))
        }

        if let callURL = URL(string: "tel:988") {
            Link(destination: callURL) {
                Label(String(localized: "Call 988"), systemImage: "phone.fill")
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.selectedColor))
        }

        if let textURL = URL(string: "sms:988") {
            Link(destination: textURL) {
                Label(String(localized: "Text 988"), systemImage: "message.fill")
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: false, tint: themeManager.selectedColor))
        }
    }
}

private struct EmergencyContactEditor: View {
    @Binding var contact: EmergencyContact
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            TextField(String(localized: "Name"), text: $contact.name)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)

            TextField(String(localized: "Relationship"), text: $contact.relationship)
                .textFieldStyle(.roundedBorder)

            TextField(String(localized: "Phone Number"), text: $contact.phoneNumber)
                .textContentType(.telephoneNumber)
                #if os(iOS)
                .keyboardType(.phonePad)
                #endif
                .textFieldStyle(.roundedBorder)

            TextField(String(localized: "Notes"), text: $contact.notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "Remove Contact"), systemImage: "minus.circle")
            }
            .font(DSTypography.caption)
        }
        .padding(DSSpacing.medium)
        .background(DSTheme.elevatedFill)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
    }
}

private struct EditableStringListSection: View {
    @Environment(ThemeManager.self) private var themeManager

    let title: String
    let subtitle: String
    let emptyMessage: String
    let addTitle: String
    let placeholder: String
    @Binding var values: [String]
    let onSave: () -> Void

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(title: title, subtitle: subtitle) {
                    Button {
                        values.append("")
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(themeManager.selectedColor)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(addTitle)
                }

                if values.isEmpty {
                    Text(emptyMessage)
                        .font(DSTypography.body)
                        .foregroundStyle(DSTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DSSpacing.small)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: DSSpacing.small) {
                        ForEach(values.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: DSSpacing.small) {
                                TextField(placeholder, text: Binding(
                                    get: { index < values.count ? values[index] : "" },
                                    set: { if index < values.count { values[index] = $0 } }
                                ), axis: .vertical)
                                    .lineLimit(1...4)
                                    .textFieldStyle(.roundedBorder)

                                Button(role: .destructive) {
                                    if index < values.count {
                                        values.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 22))
                                }
                                .accessibilityLabel(String(localized: "Remove Item"))
                            }
                        }
                    }
                }

                DSPrimaryButton(title: String(localized: "Save"), action: onSave)
            }
        }
    }
}
