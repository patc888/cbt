import SwiftUI

struct FurtherReadingEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Further Reading",
            subtitle: "Recommended resources for those who want a deeper dive."
        ) {
            VStack(spacing: 16) {
                BookRow(title: "Feeling Good", author: "David Burns, MD", category: "Best for Beginners")
                BookRow(title: "Mind Over Mood", author: "Greenberger & Padesky", category: "Practical Worksheets")
                BookRow(title: "The CBT Handbook", author: "Pamela Myles", category: "Comprehensive Guide")
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Online Resources")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            LinkItem(text: "Beck Institute (beckinstitute.org)")
                            LinkItem(text: "ABCT (abct.org)")
                            LinkItem(text: "NHS CBT Guide (nhs.uk)")
                        }
                    }
                }
            }
        }
    }
    
    struct BookRow: View {
        let title: String
        let author: String
        let category: String
        @Environment(ThemeManager.self) private var themeManager
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.caption2.bold())
                        .foregroundStyle(themeManager.selectedColor)
                        .textCase(.uppercase)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "book.fill")
                    .foregroundStyle(themeManager.selectedColor.opacity(0.3))
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }
    
    struct LinkItem: View {
        let text: String
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
