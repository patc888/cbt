import SwiftUI
import SwiftData
import OSLog

struct SaveSessionView: View {
    private static let logger = AppLogger.make(category: "SaveSessionView")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let summary: SessionSummary
    var onSaveComplete: (() -> Void)?

    @State private var editableTitle: String
    @State private var notes: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var showBody = false
    @State private var saved = false

    private let availableTags = ["Calm", "Stress", "Work", "Self-Care", "Growth", "Sleep", "Focus"]

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    init(summary: SessionSummary, onSaveComplete: (() -> Void)? = nil) {
        self.summary = summary
        self.onSaveComplete = onSaveComplete
        _editableTitle = State(initialValue: summary.title)
    }

    var body: some View {
        NavigationStack {
            DSSheetContainer(maxContentWidth: 680) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.large) {

                    // Duration Badge
                    HStack(spacing: DSSpacing.small) {
                        Image(systemName: summary.sourceKind.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                        Text(summary.sourceKind.displayName)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                        Spacer()
                        if summary.durationSeconds > 0 {
                            Label(formattedDuration, systemImage: "timer")
                                .font(DSTypography.caption)
                                .foregroundStyle(DSTheme.secondaryText)
                                .padding(.horizontal, DSSpacing.medium)
                                .padding(.vertical, DSSpacing.xSmall)
                                .background(DSTheme.elevatedFill)
                                .clipShape(Capsule())
                        }
                    }

                    // Title
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            Text("TITLE")
                                .font(DSTypography.cardTitle)
                                .foregroundStyle(accent)
                                .tracking(1)
                            TextField("Session Title", text: $editableTitle)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(DSTheme.primaryText)
                                .textFieldStyle(.plain)
                                .cbtInputSurface()
                        }
                    }

                    // What You Did
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showBody.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("WHAT YOU DID")
                                        .font(DSTypography.cardTitle)
                                        .foregroundStyle(accent)
                                        .tracking(1)
                                    Spacer()
                                    Image(systemName: showBody ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(DSTheme.secondaryText)
                                }
                            }
                            .buttonStyle(.plain)

                            if showBody {
                                Text(summary.bodyText)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundStyle(DSTheme.primaryText)
                                    .lineLimit(nil)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else {
                                Text(summary.bodyText)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundStyle(DSTheme.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                    }

                    // Notes
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: DSSpacing.small) {
                            Text("NOTES")
                                .font(DSTypography.cardTitle)
                                .foregroundStyle(accent)
                                .tracking(1)
                            TextEditor(text: $notes)
                                .font(.system(size: 15, design: .rounded))
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(DSTheme.primaryText)
                                .cbtInputSurface()
                        }
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        Text("TAGS")
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(accent)
                            .tracking(1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DSSpacing.small) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button {
                                        HapticManager.shared.selection()
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    } label: {
                                        Text(tag)
                                    }
                                    .buttonStyle(DSSelectionButtonStyle(isSelected: selectedTags.contains(tag), selectedColor: accent, size: .compact, expands: false))
                                }
                            }
                        }
                    }

                    Spacer().frame(height: DSSpacing.small)
                    }
                }

                HStack(spacing: DSSpacing.medium) {
                    Spacer()
                    Button {
                        saveEntry()
                    } label: {
                        Text("Save Session")
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(editableTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save session")
                }
                .padding(.top, DSSpacing.small)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
            .navigationTitle("Save Session")
            #if os(iOS) && !targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Helpers
    private var formattedDuration: String {
        DurationFormatting.sessionLabel(seconds: summary.durationSeconds)
    }

    private func saveEntry() {
        HapticManager.shared.lightImpact()

        do {
            try modelContext.cbtStore.insertJournalEntry(
                summary: summary,
                title: editableTitle,
                bodyText: summary.bodyText,
                notes: notes,
                tags: selectedTags
            )
            HapticManager.shared.success()
            ReviewManager.shared.logSignificantAction()
            saved = true
            dismiss()
            onSaveComplete?()
        } catch {
            Self.logger.error("Failed to save journal entry: \(error.localizedDescription, privacy: .public)")
        }
    }
}
