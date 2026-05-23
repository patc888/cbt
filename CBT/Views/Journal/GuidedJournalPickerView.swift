import SwiftUI
import SwiftData

// MARK: - Template Picker

struct GuidedJournalPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @State private var selectedTemplate: JournalTemplate?
    @State private var pastEntries: [FlexibleJournalEntry] = []

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: Template Cards
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Start a New Entry"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .padding(.horizontal, 4)

                    ForEach(JournalTemplate.allTemplates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            GuidedTemplateCard(template: template, accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: Past Entries
                if !pastEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Past Entries"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.horizontal, 4)

                        ForEach(pastEntries) { entry in
                            GuidedJournalEntryRow(entry: entry, accent: accent)
                        }
                    }
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
        }
        .task {
            await refreshEntries()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshEntries() }
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

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(template.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.secondaryText.opacity(0.6))
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
        JournalTemplate.allTemplates.first { $0.name == entry.templateType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Image(systemName: matchingTemplate?.icon ?? "doc.text")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)

                Text(entry.templateType)
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
                            Text(prompt)
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
