import SwiftUI
import SwiftData
import OSLog

struct JournalEntryDetailView: View {
    private static let logger = AppLogger.make(category: "JournalEntryDetailView")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.colorScheme) private var colorScheme

    let entry: JournalEntry

    @State private var showingDeleteConfirmation = false

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                // Header badge
                HStack(spacing: DSSpacing.small) {
                    if let kind = entry.sessionSourceKind {
                        Image(systemName: kind.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                        Text(kind.displayName)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                    }

                    Spacer()

                    if let durationLabel = entry.durationLabel {
                        Label(durationLabel, systemImage: "timer")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .padding(.horizontal, DSSpacing.medium)
                            .padding(.vertical, DSSpacing.xSmall)
                            .background(DSTheme.elevatedFill)
                            .clipShape(Capsule())
                    }
                }

                // Date
                Text(entry.createdAt.formatted(date: .long, time: .shortened))
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)

                // Title
                Text(entry.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DSTheme.primaryText)

                Divider()

                // Body content
                Text(entry.body)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(DSTheme.primaryText)
                    .lineSpacing(4)

                Spacer(minLength: DSSpacing.xxLarge)
            }
            .padding(.horizontal, DSSpacing.large)
            .padding(.top, DSSpacing.large)
            .responsiveMaxWidth()
        }
        .background(ThemedBackground().ignoresSafeArea())
        .navigationTitle("Journal Entry")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    HapticManager.shared.mediumImpact()
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DSTheme.destructive)
                }
            }
        }
        .alert("Delete Entry?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
        } message: {
            Text("This journal entry will be removed.")
        }
#if os(iOS)
        .toolbarBackground(Theme.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
    }

    private func deleteEntry() {
        do {
            try modelContext.cbtStore.softDelete(item: entry)
            dismiss()
        } catch {
            Self.logger.error("Failed to soft-delete journal entry: \(error.localizedDescription, privacy: .public)")
        }
    }
}
