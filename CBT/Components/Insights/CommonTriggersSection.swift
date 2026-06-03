import SwiftData
import SwiftUI

struct CommonTriggersSection: View {
    let snapshot: TriggerLibrarySnapshot

    @State private var selectedWindow: TriggerLibraryWindow = .sevenDays
    @Environment(ThemeManager.self) private var themeManager

    private var triggers: [PersonalizedTriggerSummary] {
        snapshot.commonTriggers(for: selectedWindow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(localized: "Common Triggers"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Picker(String(localized: "Trigger range"), selection: $selectedWindow) {
                    ForEach(TriggerLibraryWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if triggers.isEmpty {
                CommonTriggersEmptyCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(triggers) { trigger in
                        NavigationLink {
                            TriggerDetailView(trigger: trigger)
                        } label: {
                            CommonTriggerRow(trigger: trigger, window: selectedWindow)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct CommonTriggerRow: View {
    let trigger: PersonalizedTriggerSummary
    let window: TriggerLibraryWindow

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: trigger.category.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 38, height: 38)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(trigger.category.displayName)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(patternText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(trigger.count(for: window))")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(themeManager.selectedColor)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
                .accessibilityHidden(true)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trigger.category.displayName), \(trigger.count(for: window)) times in \(window.title)")
    }

    private var patternText: String {
        let moodText = trigger.averageMood.map { String(format: "Avg mood %.1f/10", $0) }
        let stressText = trigger.averageStress.map { String(format: "avg stress %.1f/10", $0) }
        return [moodText, stressText].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
            ?? String(localized: "\(trigger.recommendedTools.count) suggested tools")
    }
}

private struct CommonTriggersEmptyCard: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tag.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 36, height: 36)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(String(localized: "Trigger patterns appear after check-ins, journals, or thought records mention recurring situations."))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

struct TriggerDetailView: View {
    let trigger: PersonalizedTriggerSummary

    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: [SortDescriptor(\LibraryItem.category), SortDescriptor(\LibraryItem.title)])
    private var libraryItems: [LibraryItem]
    @Query(sort: \Course.title)
    private var courses: [Course]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                frequencyCard
                patternsCard
                toolsSection(
                    title: String(localized: "Recommended Tools"),
                    tools: trigger.recommendedTools,
                    emptyText: String(localized: "No matching tools are mapped yet.")
                )
                toolsSection(
                    title: String(localized: "Completed Tools"),
                    tools: trigger.completedTools,
                    emptyText: String(localized: "Completed recommendations will appear here.")
                )
            }
            .padding(16)
            .responsiveMaxWidth()
        }
        .background(ThemedBackground().ignoresSafeArea())
        .navigationTitle(trigger.category.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: trigger.category.systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(
                        colors: [themeManager.selectedColor, themeManager.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(trigger.category.displayName)
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "Local patterns from your entries. This is not a diagnosis."))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Frequency"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                metric(title: "7 days", value: "\(trigger.sevenDayCount)")
                metric(title: "30 days", value: "\(trigger.thirtyDayCount)")
                metric(title: "All time", value: "\(trigger.allTimeCount)")
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var patternsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Mood & Stress Patterns"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)

            if trigger.averageMood == nil && trigger.averageStress == nil {
                Text(String(localized: "Patterns appear when related entries include mood or stress ratings."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    if let averageMood = trigger.averageMood {
                        metric(title: "Avg mood", value: String(format: "%.1f/10", averageMood))
                    }
                    if let averageStress = trigger.averageStress {
                        metric(title: "Avg stress", value: String(format: "%.1f/10", averageStress))
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func toolsSection(title: String, tools: [TriggerToolRecommendation], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)

            if tools.isEmpty {
                Text(emptyText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(tools) { tool in
                        toolRow(tool)
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func toolRow(_ tool: TriggerToolRecommendation) -> some View {
        NavigationLink {
            destination(for: tool)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 34, height: 34)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(tool.kind.rawValue) - \(tool.subtitle)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(for tool: TriggerToolRecommendation) -> some View {
        switch tool.kind {
        case .exercise, .libraryItem:
            if let item = libraryItems.first(where: { $0.id == tool.destinationID }) {
                LibraryItemDestinationView(item: item)
            } else if let exercise = LibraryService.shared.exercise(withID: tool.destinationID) {
                ExerciseDetailView(exercise: exercise)
            } else {
                ContentUnavailableView("Tool unavailable", systemImage: "exclamationmark.triangle")
            }
        case .course, .cbtPath:
            if let course = courses.first(where: { $0.id == tool.destinationID }) {
                CourseDetailView(course: course, libraryItems: libraryItems)
            } else {
                ContentUnavailableView("Course unavailable", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(themeManager.selectedColor)
                .monospacedDigit()

            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(themeManager.selectedColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
