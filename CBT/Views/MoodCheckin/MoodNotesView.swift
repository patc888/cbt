import SwiftUI

struct MoodNotesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var notes: String
    let onNext: () -> Void
    
    var body: some View {
        MoodStepScaffold(
            title: "Anything you'd like to write?",
            subtitle: "A few words can make this check-in easier to understand later.",
            icon: "square.and.pencil",
            accent: themeManager.selectedColor,
            actionTitle: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Skip" : "Continue",
            action: onNext
        ) {
            MoodGlassPanel(accent: themeManager.selectedColor) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $notes)
                        .font(DSTypography.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 190, maxHeight: 240)
                        .padding(4)

                    if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("What happened, what you noticed, or what you might need next...")
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.tertiaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                        .fill(DSTheme.elevatedFill.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous)
                        .stroke(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                )
            }
        }
        .onTapGesture {
            // Dismiss keyboard
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }
}
