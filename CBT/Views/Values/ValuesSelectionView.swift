import SwiftUI
import SwiftData

struct ValuesSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \PersonalValue.createdAt) private var selectedValues: [PersonalValue]

    @State private var customValueName = ""
    @State private var errorMessage: String?

    private var activeValues: [PersonalValue] {
        selectedValues.filter { !$0.isDeleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Personal Values")
                        .font(DSTypography.pageTitle)
                        .foregroundStyle(Theme.primaryText)

                    Text("Pick a few qualities you want to keep close. You can change these anytime.")
                        .font(DSTypography.body)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 138), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(ValuesService.defaultValues) { value in
                        valueChip(
                            title: value.name,
                            isSelected: isSelected(value.id)
                        ) {
                            toggleDefaultValue(value)
                        }
                    }
                }

                customValueField

                if !activeValues.isEmpty {
                    selectedSummary
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.warningOrange)
                }
            }
            .padding(20)
            .responsiveMaxWidth()
        }
        .background {
            ThemedBackground().ignoresSafeArea()
        }
        .navigationTitle("Values")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var customValueField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Your Own")
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)

            HStack(spacing: 8) {
                TextField("Custom value", text: $customValueName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addCustomValue)

                Button {
                    addCustomValue()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(DSButtonStyle(variant: .primary, size: .compact, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel("Add custom value")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var selectedSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected")
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)

            ForEach(activeValues) { value in
                HStack(spacing: 10) {
                    Image(systemName: value.isCustom ? "sparkle" : "checkmark.circle.fill")
                        .foregroundStyle(themeManager.selectedColor)
                        .accessibilityHidden(true)

                    Text(value.name)
                        .font(DSTypography.body)
                        .foregroundStyle(Theme.primaryText)

                    Spacer()

                    Button {
                        removeValue(value)
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(value.name)")
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func valueChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Text(title)
                    .lineLimit(2)
            }
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: isSelected, selectedColor: themeManager.selectedColor, size: .medium))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func isSelected(_ valueID: String) -> Bool {
        activeValues.contains { $0.valueID == valueID }
    }

    private func toggleDefaultValue(_ value: ValueDefinition) {
        HapticManager.shared.selection()
        if let selected = activeValues.first(where: { $0.valueID == value.id }) {
            removeValue(selected)
            return
        }

        do {
            _ = try ValuesService.selectDefaultValue(value, in: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = "That value could not be saved. Please try again."
        }
    }

    private func addCustomValue() {
        do {
            _ = try ValuesService.addCustomValue(named: customValueName, in: modelContext)
            customValueName = ""
            errorMessage = nil
            HapticManager.shared.success()
        } catch {
            errorMessage = "That value could not be saved. Please try again."
        }
    }

    private func removeValue(_ value: PersonalValue) {
        value.isDeleted = true
        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "That value could not be updated. Please try again."
        }
    }
}
