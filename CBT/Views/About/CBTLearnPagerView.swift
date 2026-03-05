import SwiftUI

struct CBTLearnPagerView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let pages = [
        "What is CBT?",
        "The CBT Triangle",
        "Cognitive Distortions",
        "How CBT Works",
        "What Research Shows",
        "CBT Skills",
        "Seeing Patterns",
        "Flexible Thinking",
        "Using This App",
        "Further Reading"
    ]
    
    var body: some View {
        ZStack(alignment: .top) {
            ThemedBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Headline Header
                VStack(spacing: DSSpacing.small) {
                    Text(pages[currentPage])
                        .font(DSTypography.pageTitle)
                        .foregroundStyle(DSTheme.primaryText)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(currentPage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    Rectangle()
                        .fill(Theme.primaryColor.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal)
                }
                .background(ThemedBackground().opacity(0.8).blur(radius: 10))
                .zIndex(1)
                
                TabView(selection: $currentPage) {
                    CBTEducationIntroView(hideBackground: true, hideTitle: true).tag(0)
                    CBTTriangleView(hideBackground: true, hideTitle: true).tag(1)
                    CBTCognitiveDistortionsView(hideBackground: true, hideTitle: true).tag(2)
                    CBTHowItWorksView(hideBackground: true, hideTitle: true).tag(3)
                    CBTResearchView(hideBackground: true, hideTitle: true).tag(4)
                    CBTSkillsView(hideBackground: true, hideTitle: true).tag(5)
                    CBTPatternsView(hideBackground: true, hideTitle: true).tag(6)
                    CBTFlexibleThinkingView(hideBackground: true, hideTitle: true).tag(7)
                    CBTUsingAppView(hideBackground: true, hideTitle: true).tag(8)
                    CBTFurtherReadingView(hideBackground: true, hideTitle: true).tag(9)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    HapticManager.shared.trigger(.selection)
                }
                
                // Custom indicator dots
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Theme.primaryColor : Theme.secondaryText.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(
                    ThemedBackground().opacity(0.9)
                        .overlay(
                            Rectangle()
                                .fill(DSTheme.separator.opacity(0.5))
                                .frame(height: 1),
                            alignment: .top
                        )
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DismissButton(style: .chevron)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
