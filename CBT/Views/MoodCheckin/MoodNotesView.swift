import SwiftUI

struct MoodNotesView: View {
    @Binding var notes: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            Text("Anything you'd like to write about this moment?")
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextEditor(text: $notes)
                .font(DSTypography.body)
                .frame(maxHeight: 200)
                .padding(12)
                .background(DSTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                        .stroke(DSTheme.separator.opacity(0.18), lineWidth: 1)
                )
                .padding(.horizontal, DSSpacing.large)
            
            Spacer()
            
            Button(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Skip" : "Continue") {
                onNext()
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .padding(.horizontal, DSSpacing.large)
            .padding(.bottom, DSSpacing.large)
        }
        .onTapGesture {
            // Dismiss keyboard
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }
}
