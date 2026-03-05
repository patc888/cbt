import SwiftUI

struct ContextualHelpButton: View {
    let title: String
    let message: String
    @State private var showingHelp = false
    
    var body: some View {
        Button {
            HapticManager.shared.lightImpact()
            showingHelp = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.primaryColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Help for \(title)")
        .sheet(isPresented: $showingHelp) {
            HelpSheet(title: title, message: message)
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct HelpSheet: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.cardBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.secondaryText)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(24)
        }
    }
}
