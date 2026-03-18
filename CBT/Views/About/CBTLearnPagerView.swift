import SwiftUI

struct CBTLearnPagerView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let pages = [
        "What is CBT?",
        "The CBT Triangle",
        "How CBT Works",
        "Mood Check-In",
        "Thought Records",
        "Cognitive Distortions",
        "Evidence for & Against",
        "Balanced Perspectives",
        "What Research Shows",
        "CBT Skills",
        "Seeing Patterns",
        "Flexible Thinking",
        "Using This App",
        "Professional Support",
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
                    CBTHowItWorksView(hideBackground: true, hideTitle: true).tag(2)
                    MoodCheckInEducationView(hideBackground: true, hideTitle: true).tag(3)
                    ThoughtRecordEducationView(hideBackground: true, hideTitle: true).tag(4)
                    CBTCognitiveDistortionsView(hideBackground: true, hideTitle: true).tag(5)
                    EvidenceEducationView(hideBackground: true, hideTitle: true).tag(6)
                    BalancedThoughtEducationView(hideBackground: true, hideTitle: true).tag(7)
                    CBTResearchView(hideBackground: true, hideTitle: true).tag(8)
                    CBTSkillsView(hideBackground: true, hideTitle: true).tag(9)
                    CBTPatternsView(hideBackground: true, hideTitle: true).tag(10)
                    CBTFlexibleThinkingView(hideBackground: true, hideTitle: true).tag(11)
                    CBTUsingAppView(hideBackground: true, hideTitle: true).tag(12)
                    ProfessionalHelpEducationView(hideBackground: true, hideTitle: true).tag(13)
                    CBTFurtherReadingView(hideBackground: true, hideTitle: true).tag(14)
                }
                #if os(macOS)
                .tabViewStyle(.automatic)
                #else
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .automatic) {
                DismissButton(style: .chevron)
            }
            #else
            ToolbarItem(placement: .navigationBarTrailing) {
                DismissButton(style: .chevron)
            }
            #endif
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}
