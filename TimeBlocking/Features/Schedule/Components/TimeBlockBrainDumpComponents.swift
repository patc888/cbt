import SwiftUI

struct BrainDumpCaptureSection: View {
    @Binding var brainDumpTitle: String
    @Binding var brainDumpNotes: String
    var editingBrainDumpItemID: UUID?
    var brainDumpItemsCount: Int
    var trimmedBrainDumpTitle: String
    var focusedField: FocusState<AddTimeBlockView.EditorField?>.Binding
    var saveAction: () -> Void
    var resetAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unscheduled Inbox")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryAccent)

                        Text(editingBrainDumpItemID == nil ? "Capture it now. Decide what it becomes later." : "Editing inbox item")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                    }

                    Spacer(minLength: 12)

                    Text(brainDumpItemsCount == 0 ? "Empty" : "\(brainDumpItemsCount) saved")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.primaryAccent.opacity(0.12), in: Capsule())
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
                        .focused(focusedField, equals: .brainDumpTitle)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    focusedField.wrappedValue == .brainDumpTitle ? Theme.primaryAccent.opacity(0.5) : Color.primary.opacity(0.08),
                                    lineWidth: focusedField.wrappedValue == .brainDumpTitle ? 1.5 : 1
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
                    .focused(focusedField, equals: .notes)
                }

                HStack(spacing: 12) {
                    Button(editingBrainDumpItemID == nil ? "Quick Save" : "Update Inbox Item") {
                        saveAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryAccent)
                    .disabled(trimmedBrainDumpTitle.isEmpty)

                    if editingBrainDumpItemID != nil {
                        Button("Cancel Edit") {
                            resetAction()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("No time, duration, category, or checklist required here. Brain Dump stays unscheduled until you convert it.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            focusedField.wrappedValue == .notes ? Theme.primaryAccent.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: focusedField.wrappedValue == .notes ? 1.5 : 1
                        )
                }

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct BrainDumpInboxSection: View {
    var brainDumpItems: [BrainDumpItem]
    var editingBrainDumpItemID: UUID?
    var startBlockConversion: (BrainDumpItem) -> Void
    var startRoutineConversion: (BrainDumpItem) -> Void
    var loadForEditing: (BrainDumpItem) -> Void
    var deleteItem: (BrainDumpItem) -> Void

    var body: some View {
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
                        BrainDumpInboxRow(
                            item: item,
                            isEditing: editingBrainDumpItemID == item.id,
                            startBlockConversion: startBlockConversion,
                            startRoutineConversion: startRoutineConversion,
                            loadForEditing: loadForEditing,
                            deleteItem: deleteItem
                        )
                    }
                }
            }
        }
    }
}

struct BrainDumpInboxRow: View {
    let item: BrainDumpItem
    let isEditing: Bool
    var startBlockConversion: (BrainDumpItem) -> Void
    var startRoutineConversion: (BrainDumpItem) -> Void
    var loadForEditing: (BrainDumpItem) -> Void
    var deleteItem: (BrainDumpItem) -> Void

    var body: some View {
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

                if isEditing {
                    Text("Editing")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Theme.primaryAccent.opacity(0.12), in: Capsule())
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 8) {
                Button("Schedule") {
                    startBlockConversion(item)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryAccent)

                Button("Routine") {
                    startRoutineConversion(item)
                }
                .buttonStyle(.bordered)

                Button(isEditing ? "Editing" : "Edit") {
                    loadForEditing(item)
                }
                .buttonStyle(.bordered)
                .disabled(isEditing)

                Button("Delete", role: .destructive) {
                    deleteItem(item)
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
}
