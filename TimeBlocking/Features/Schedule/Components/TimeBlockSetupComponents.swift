import SwiftUI

struct TitleSetupSection: View {
    @Binding var title: String
    var currentSetupAccentColor: Color
    var selectedSetupIconSymbol: String
    var focusedField: FocusState<AddTimeBlockView.EditorField?>.Binding
    var continueToDetails: () -> Void

    var body: some View {
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
                .focused(focusedField, equals: .title)
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
                            focusedField.wrappedValue == .title ? currentSetupAccentColor.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: focusedField.wrappedValue == .title ? 1.5 : 1
                        )
                }
        }
    }
}

struct IconPickerSection: View {
    @Binding var selectedSetupIconSymbol: String
    @Binding var category: TimeBlockCategory
    @Binding var selectedSetupAccentID: String
    var currentSetupAccentColor: Color
    var setupIconOptions: [SetupIconOption]
    var selectedSetupAccentCategory: TimeBlockCategory?

    var body: some View {
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
                        if selectedSetupAccentCategory != option.category {
                            selectedSetupAccentID = AddTimeBlockView.defaultSetupAccentID(for: option.category)
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
}

struct ColorPickerSection: View {
    @Binding var selectedSetupAccentID: String
    @Binding var category: TimeBlockCategory
    @Binding var selectedSetupIconSymbol: String
    var setupAccentOptions: [SetupAccentOption]
    var selectedSetupIconCategory: TimeBlockCategory?

    var body: some View {
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
                        if selectedSetupIconCategory != option.category {
                            selectedSetupIconSymbol = AddTimeBlockView.defaultSetupIconSymbol(for: option.category)
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
}

struct SuggestionPickerSection: View {
    let trimmedTitle: String
    let suggestionSummaryText: String
    let suggestionGroups: [SuggestionGroup]
    let filteredSuggestions: [TimeBlockSuggestion]
    let applySuggestion: (TimeBlockSuggestion) -> Void

    var body: some View {
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
                    .strokeBorder(trimmedTitle == suggestion.title ? suggestion.category.tintColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: trimmedTitle == suggestion.title ? 1.5 : 1)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
