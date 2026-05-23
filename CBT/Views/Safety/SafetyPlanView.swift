import SwiftData
import SwiftUI

struct SafetyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \SafetyPlan.updatedAt, order: .reverse) private var safetyPlans: [SafetyPlan]

    private var activePlan: SafetyPlan? {
        safetyPlans.first
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    AppScreenHeadline(title: String(localized: "Safety Plan"))
                        .padding(.horizontal, DSSpacing.large)

                    if let activePlan {
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
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "Create a Safety Plan"),
                    subtitle: String(localized: "Keep warning signs, coping strategies, and trusted contacts ready for hard moments.")
                )

                DSPrimaryButton(title: String(localized: "Create Plan")) {
                    let plan = SafetyPlan()
                    modelContext.insert(plan)
                    try? modelContext.save()
                }
            }
        }
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

    @State private var contacts: [EmergencyContact]
    @State private var warningSigns: [String]
    @State private var copingStrategies: [String]
    @State private var showingDeleteConfirmation = false

    init(plan: SafetyPlan, onDelete: @escaping () -> Void) {
        self.plan = plan
        self.onDelete = onDelete
        _contacts = State(initialValue: plan.emergencyContacts)
        _warningSigns = State(initialValue: plan.personalWarningSigns)
        _copingStrategies = State(initialValue: plan.copingStrategies)
    }

    var body: some View {
        VStack(spacing: DSSpacing.large) {
            contactsSection
            warningSignsSection
            copingSection
            deleteSection
        }
        .padding(.horizontal, DSSpacing.large)
        .onDisappear(perform: save)
        .confirmationDialog(
            String(localized: "Delete Safety Plan?"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Safety Plan"), role: .destructive, action: onDelete)
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This removes your saved contacts, warning signs, and coping strategies."))
        }
    }

    private var contactsSection: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                DSSectionHeader(
                    title: String(localized: "Emergency Contacts"),
                    subtitle: String(localized: "People you trust and how to reach them.")
                ) {
                    addButton(title: String(localized: "Add Contact")) {
                        contacts.append(EmergencyContact())
                    }
                }

                if contacts.isEmpty {
                    emptyText(String(localized: "No emergency contacts yet."))
                } else {
                    VStack(spacing: DSSpacing.medium) {
                        ForEach($contacts) { $contact in
                            EmergencyContactEditor(contact: $contact) {
                                contacts.removeAll { $0.id == contact.id }
                            }
                        }
                    }
                }

                DSPrimaryButton(title: String(localized: "Save Safety Plan"), action: save)
            }
        }
    }

    private var warningSignsSection: some View {
        EditableStringListSection(
            title: String(localized: "Personal Warning Signs"),
            subtitle: String(localized: "Thoughts, feelings, body cues, or situations that tell you support may help."),
            emptyMessage: String(localized: "No warning signs yet."),
            addTitle: String(localized: "Add Sign"),
            placeholder: String(localized: "Warning sign"),
            values: $warningSigns,
            onSave: save
        )
    }

    private var copingSection: some View {
        EditableStringListSection(
            title: String(localized: "Coping Strategies"),
            subtitle: String(localized: "Actions that help you get through the next few minutes safely."),
            emptyMessage: String(localized: "No coping strategies yet."),
            addTitle: String(localized: "Add Strategy"),
            placeholder: String(localized: "Coping strategy"),
            values: $copingStrategies,
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
                    Label(String(localized: "Delete Safety Plan"), systemImage: "trash")
                }
                .buttonStyle(DSSecondaryButtonStyle())
            }
        }
    }

    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(themeManager.selectedColor)
                .clipShape(Circle())
        }
        .accessibilityLabel(title)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(DSTypography.body)
            .foregroundStyle(DSTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DSSpacing.small)
    }

    private func save() {
        plan.emergencyContacts = contacts
        plan.personalWarningSigns = warningSigns
        plan.copingStrategies = copingStrategies
        try? modelContext.save()
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
                } else {
                    VStack(spacing: DSSpacing.small) {
                        ForEach(values.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: DSSpacing.small) {
                                TextField(placeholder, text: $values[index], axis: .vertical)
                                    .lineLimit(1...4)
                                    .textFieldStyle(.roundedBorder)

                                Button(role: .destructive) {
                                    values.remove(at: index)
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
