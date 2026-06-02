import SwiftUI
import SwiftData

// MARK: - Template Picker

struct GuidedJournalPickerView: View {
    private static let allCategory = "All"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @State private var selectedTemplate: JournalTemplate?
    @State private var pastEntries: [FlexibleJournalEntry] = []
    @State private var searchText = ""
    @State private var selectedCategory = Self.allCategory

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var templates: [JournalTemplate] {
        JournalTemplate.allTemplates
    }

    private var categoryOptions: [String] {
        let available = Set(templates.map(\.category))
        let ordered = JournalTemplate.categoryOrder.filter { available.contains($0) }
        let extras = available.subtracting(Set(ordered)).sorted()
        return [Self.allCategory] + ordered + extras
    }

    private var filteredTemplates: [JournalTemplate] {
        templates.filter(matchesCurrentFilters)
    }

    private var recommendedTemplates: [JournalTemplate] {
        filteredTemplates.filter(\.isRecommended)
    }

    private var recentlyUsedTemplates: [JournalTemplate] {
        var seenIDs = Set<String>()

        return pastEntries.compactMap { entry in
            guard let template = JournalTemplate.template(matching: entry.templateType),
                  matchesCurrentFilters(template),
                  seenIDs.insert(template.id).inserted
            else {
                return nil
            }
            return template
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                searchAndFilters

                if !recentlyUsedTemplates.isEmpty {
                    templateCarouselSection(
                        title: String(localized: "Recently Used"),
                        templates: recentlyUsedTemplates
                    )
                }

                if !recommendedTemplates.isEmpty {
                    templateCarouselSection(
                        title: String(localized: "Recommended"),
                        templates: recommendedTemplates
                    )
                }

                templateListSection

                if pastEntries.isEmpty {
                    guidedJournalEmptyState
                } else {
                    pastEntriesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 16)
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $selectedTemplate) { template in
            GuidedJournalWizardView(template: template) {
                Task { await refreshEntries() }
            }
            .dsSheetPresentation()
        }
        .task {
            await refreshEntries()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshEntries() }
        }
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                TextField(String(localized: "Search templates"), text: $searchText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        HapticManager.shared.lightImpact()
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.secondaryText.opacity(0.12), lineWidth: 0.8)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categoryOptions, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func categoryChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            HapticManager.shared.selection()
            selectedCategory = category
        } label: {
            Text(category)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background {
                    if isSelected {
                        accent
                    } else {
                        Theme.cardBackground
                    }
                }
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Theme.secondaryText.opacity(0.14), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private func templateCarouselSection(title: String, templates: [JournalTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            GuidedTemplateCard(template: template, accent: accent)
                                .frame(width: 286)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var templateListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "Templates"))

            if filteredTemplates.isEmpty {
                EmptyTemplateResultsView {
                    HapticManager.shared.lightImpact()
                    searchText = ""
                    selectedCategory = Self.allCategory
                }
            } else {
                ForEach(filteredTemplates) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        GuidedTemplateCard(template: template, accent: accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var guidedJournalEmptyState: some View {
        SupportiveEmptyStateView(
            systemImage: "pencil.and.list.clipboard",
            title: String(localized: "Guided Journal"),
            message: String(localized: "Guided journal entries use simple prompts to help you reflect without starting from a blank page."),
            actionTitle: String(localized: "Start a Gentle Entry"),
            actionSystemImage: "square.and.pencil"
        ) {
            guard let firstTemplate = filteredTemplates.first ?? templates.first else { return }
            HapticManager.shared.lightImpact()
            selectedTemplate = firstTemplate
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var pastEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "Past Entries"))

            ForEach(pastEntries) { entry in
                GuidedJournalEntryRow(entry: entry, accent: accent)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 4)
    }

    private func matchesCurrentFilters(_ template: JournalTemplate) -> Bool {
        if selectedCategory != Self.allCategory, template.category != selectedCategory {
            return false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        let searchableText = [
            template.title,
            template.description,
            template.category,
            template.approach,
            template.helperText,
            template.completionReflection
        ]
        .compactMap { $0 }
        + template.moodEmotionTags
        + template.promptSteps.flatMap { step in
            [step.title, step.prompt, step.helperText].compactMap { $0 }
        }

        return searchableText.contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    private func refreshEntries() async {
        pastEntries = LaunchSafeFetch.flexibleJournalEntries(from: modelContext)
    }
}

// MARK: - Template Card

private struct GuidedTemplateCard: View {
    let template: JournalTemplate
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: template.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: template.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(template.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)

                Text(template.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        metadataLabel(template.durationLabel, icon: "clock")
                        metadataLabel(template.approach, icon: "sparkle.magnifyingglass")
                        metadataLabel(template.category, icon: "folder")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        metadataLabel(template.durationLabel, icon: "clock")
                        metadataLabel(template.approach, icon: "sparkle.magnifyingglass")
                    }
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.secondaryText.opacity(0.6))
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func metadataLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.secondaryText.opacity(0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Empty Results

private struct EmptyTemplateResultsView: View {
    let resetFilters: () -> Void

    var body: some View {
        SupportiveEmptyStateView(
            systemImage: "doc.text.magnifyingglass",
            title: String(localized: "Guided Journal Templates"),
            message: String(localized: "Templates are structured prompts for focused reflection. The current filters are hiding them."),
            actionTitle: String(localized: "Clear Filters"),
            actionSystemImage: "xmark.circle"
        ) {
            resetFilters()
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

// MARK: - Past Entry Row

private struct GuidedJournalEntryRow: View {
    let entry: FlexibleJournalEntry
    let accent: Color

    private var matchingTemplate: JournalTemplate? {
        JournalTemplate.template(matching: entry.templateType)
    }

    private var title: String {
        matchingTemplate?.title ?? entry.templateType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Image(systemName: matchingTemplate?.icon ?? "doc.text")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            if let template = matchingTemplate {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(zip(template.prompts.indices, template.prompts)), id: \.0) { index, prompt in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prompt.text)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)

                            if index < entry.responses.count {
                                Text(entry.responses[index])
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
