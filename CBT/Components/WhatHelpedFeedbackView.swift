import SwiftUI
import SwiftData

struct WhatHelpedFeedbackView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let activityKind: HelpfulnessActivityKind
    let itemID: String?
    let sourceScreen: String?

    @State private var selectedResponse: HelpfulnessResponse?
    @State private var saveError: String?

    init(
        activityKind: HelpfulnessActivityKind,
        itemID: String? = nil,
        sourceScreen: String? = nil
    ) {
        self.activityKind = activityKind
        self.itemID = itemID
        self.sourceScreen = sourceScreen
    }

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack(spacing: DSSpacing.small) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(accent)
                Text("What helped?")
                    .font(DSTypography.button)
                    .foregroundStyle(DSTheme.primaryText)
            }

            Text("Did this feel useful right now?")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)

            HStack(spacing: DSSpacing.small) {
                ForEach(HelpfulnessResponse.allCases) { response in
                    Button {
                        save(response)
                    } label: {
                        Text(response.title)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 8)
                    .background(buttonBackground(for: response))
                    .foregroundStyle(selectedResponse == response ? .white : DSTheme.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
                    .accessibilityLabel("Mark \(response.title.lowercased())")
                }
            }

            if selectedResponse != nil {
                Label("Saved for smarter suggestions", systemImage: "checkmark.circle.fill")
                    .font(DSTypography.caption)
                    .foregroundStyle(accent)
            } else if let saveError {
                Text(saveError)
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.errorRed)
            }
        }
        .padding(DSSpacing.medium)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.25), lineWidth: 1)
        }
    }

    private func buttonBackground(for response: HelpfulnessResponse) -> Color {
        selectedResponse == response ? accent : DSTheme.elevatedFill
    }

    private func save(_ response: HelpfulnessResponse) {
        do {
            try HelpfulnessFeedbackService.shared.record(
                activityKind: activityKind,
                response: response,
                itemID: itemID,
                sourceScreen: sourceScreen,
                in: modelContext
            )
            selectedResponse = response
            saveError = nil
            HapticManager.shared.lightImpact()
        } catch {
            saveError = "Could not save that response."
        }
    }
}
