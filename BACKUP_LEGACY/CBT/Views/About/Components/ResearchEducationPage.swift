import SwiftUI

struct ResearchEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Backed by Science",
            subtitle: "CBT is one of the most extensively researched therapies in the world."
        ) {
            VStack(spacing: 20) {
                // Mini Chart
                HStack(alignment: .bottom, spacing: 16) {
                    Bar(label: "CBT", value: 0.9, color: themeManager.selectedColor)
                    Bar(label: "Med.", value: 0.7, color: themeManager.selectedColor.opacity(0.6))
                    Bar(label: "Other", value: 0.5, color: themeManager.selectedColor.opacity(0.3))
                }
                .frame(height: 150)
                .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    CitationRow(
                        text: "CBT is considered the 'gold standard' for anxiety and depression management.",
                        source: "Hofmann et al. (2012). The Efficacy of CBT: A Review of Meta-analyses."
                    )
                    
                    CitationRow(
                        text: "A massive review of 16 meta-analyses found CBT to have strong evidence for eating disorders, personality disorders, and substance abuse.",
                        source: "Butler et al. (2006). The empirical status of CBT: A review of meta-analyses."
                    )
                    
                    CitationRow(
                        text: "In a landmark study, CBT was found to be as effective as anti-depressants for moderate and severe depression.",
                        source: "DeRubeis et al. (2005). Cognitive therapy vs medications in treatment of moderate to severe depression."
                    )
                    
                    CitationRow(
                        text: "CBT is endorsed by major health organizations including the WHO, NHS (UK), and APA (USA).",
                        source: "NICE Guidelines; APA Clinical Practice Guidelines."
                    )
                    
                    CitationRow(
                        text: "The 'Founding Father' of CBT, Aaron Beck, revolutionized treatment by focusing on thoughts.",
                        source: "Beck, A. T. (1964). Thinking and Depression."
                    )
                }
                
                Text("Source: Meta-analysis of 269 studies on CBT effectiveness.")
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
    
    struct Bar: View {
        let label: String
        let value: CGFloat
        let color: Color
        
        var body: some View {
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 44, height: 100 * value)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
    
    struct CitationRow: View {
        let text: String
        let source: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primaryText)
                Text("— \(source)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
                    .padding(.leading, 8)
            }
            .padding(12)
            .background(Theme.cardBackground)
            .cornerRadius(10)
        }
    }
}
