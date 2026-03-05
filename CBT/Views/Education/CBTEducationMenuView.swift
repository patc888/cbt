import SwiftUI

struct CBTEducationMenuView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.large) {
                    DSSectionHeader(title: "Learn About CBT")
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(spacing: DSSpacing.medium) {
                        EducationMenuRow(title: "What is CBT?", icon: "questionmark.circle", destination: CBTEducationIntroView())
                        EducationMenuRow(title: "The CBT Triangle", icon: "triangle", destination: CBTTriangleView())
                        EducationMenuRow(title: "Cognitive Distortions", icon: "brain.head.profile", destination: CBTCognitiveDistortionsView())
                        EducationMenuRow(title: "How CBT Works", icon: "gearshape", destination: CBTHowItWorksView())
                        EducationMenuRow(title: "What Research Shows", icon: "chart.bar", destination: CBTResearchView())
                        EducationMenuRow(title: "CBT Skills", icon: "hand.raised", destination: CBTSkillsView())
                        EducationMenuRow(title: "Seeing Patterns", icon: "eye", destination: CBTPatternsView())
                        EducationMenuRow(title: "Flexible Thinking", icon: "arrow.triangle.2.circlepath", destination: CBTFlexibleThinkingView())
                        EducationMenuRow(title: "Using This App", icon: "iphone", destination: CBTUsingAppView())
                        EducationMenuRow(title: "Further Reading", icon: "book", destination: CBTFurtherReadingView())
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, DSSpacing.xLarge)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EducationMenuRow<Destination: View>: View {
    let title: String
    let icon: String
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            DSCardContainer {
                HStack(spacing: DSSpacing.medium) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.primaryColor)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(DSTypography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(DSTheme.primaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// Shared layouts for Education views
struct CBTEducationLayout<Content: View>: View {
    let title: String
    var hideBackground: Bool = false
    var hideTitle: Bool = false
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        if hideBackground {
            mainContent
        } else {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                mainContent
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                if !hideTitle {
                    Text(title)
                        .font(DSTypography.pageTitle)
                        .foregroundStyle(DSTheme.primaryText)
                        .padding(.horizontal)
                        .padding(.top)
                }
                
                content()
            }
            .padding(.bottom, DSSpacing.xLarge)
        }
    }
}

struct BulletPoint: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.primaryColor)
                .font(.system(size: 14))
                .padding(.top, 4)
            Text(text)
                .font(DSTypography.body)
                .foregroundStyle(DSTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EducationChartPlaceholder: View {
    let title: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: DSCornerRadius.medium)
            .fill(DSTheme.elevatedFill.opacity(0.3))
            .frame(height: 180)
            .overlay(
                VStack(spacing: DSSpacing.small) {
                    Image(systemName: "chart.bar.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.primaryColor.opacity(0.5))
                    Text(title)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                }
            )
            .padding(.vertical, DSSpacing.small)
    }
}
