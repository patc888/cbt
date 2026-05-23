import SwiftUI
import SwiftData
import os

struct CognitiveSandboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ThemeManager.self) private var themeManager

    @Query private var records: [ThoughtRecord]

    init(recordID: UUID) {
        _records = Query(
            filter: #Predicate<ThoughtRecord> { record in
                record.id == recordID && record.isDeleted == false
            },
            sort: \ThoughtRecord.createdAt,
            order: .reverse
        )
    }

    init(record: ThoughtRecord) {
        self.init(recordID: record.id)
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            if let record = records.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(for: record)
                        comparison(for: record)
                        credibilitySlider(for: record)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView(
                    "Thought Not Found",
                    systemImage: "brain.head.profile",
                    description: Text("This thought record may have been deleted.")
                )
                .foregroundStyle(Theme.secondaryText)
                .padding()
            }
        }
        .navigationTitle("Cognitive Sandbox")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func header(for record: ThoughtRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Text("Re-rate how true this thought feels now.")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !record.situation.isEmpty {
                Text(record.situation)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func comparison(for record: ThoughtRecord) -> some View {
        let automaticCard = ThoughtComparisonCard(
            title: "Automatic Thought",
            text: record.automaticThought,
            symbolName: "exclamationmark.bubble",
            accent: Theme.secondaryText,
            fill: Theme.secondaryText.opacity(0.08)
        )

        let balancedCard = ThoughtComparisonCard(
            title: "Balanced Thought",
            text: record.balancedThought,
            symbolName: "checkmark.bubble",
            accent: themeManager.primaryColor,
            fill: themeManager.primaryColor.opacity(0.12)
        )

        if horizontalSizeClass == .compact {
            VStack(spacing: 12) {
                automaticCard
                balancedCard
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                automaticCard
                balancedCard
            }
        }
    }

    private func credibilitySlider(for record: ThoughtRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("True / False")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("Current credibility")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Text("\(record.intensityAfter)%")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(themeManager.primaryColor)
                    .monospacedDigit()
            }

            Slider(
                value: credibilityBinding(for: record),
                in: 0...100,
                step: 1
            ) {
                Text("True / False")
            } minimumValueLabel: {
                Text("False")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } maximumValueLabel: {
                Text("True")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } onEditingChanged: { isEditing in
                if !isEditing {
                    saveCredibility()
                }
            }
            .tint(themeManager.primaryColor)

            HStack(spacing: 10) {
                GrowthPill(title: "First rating", value: record.intensityBefore, color: Theme.secondaryText)
                GrowthPill(title: "Now", value: record.intensityAfter, color: themeManager.primaryColor)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func credibilityBinding(for record: ThoughtRecord) -> Binding<Double> {
        Binding(
            get: { Double(record.intensityAfter) },
            set: { newValue in
                record.intensityAfter = ThoughtRecord.clampIntensity(Int(newValue.rounded()))
            }
        )
    }

    private func saveCredibility() {
        do {
            try modelContext.save()
            HapticManager.shared.success()
        } catch {
            AppLogger.make(category: "Data").error("Failed to save cognitive sandbox rating: \(error.localizedDescription, privacy: .private)")
        }
    }
}

private struct ThoughtComparisonCard: View {
    let title: String
    let text: String
    let symbolName: String
    let accent: Color
    let fill: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(accent)
            }

            if text.isEmpty {
                Text("No thought entered.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\"\(text)\"")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(accent)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct GrowthPill: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            Text("\(value)% true")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
