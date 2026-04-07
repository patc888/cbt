import SwiftUI

struct WhatIsCBTPagerView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Page Data
    enum CBTPage: Int, CaseIterable, Identifiable {
        case intro = 0
        case triangle
        case unhelpfulCycles
        case thoughtRecords
        case distortions
        case evidence
        case balancedPerspective
        case science
        case furtherReading
        case conclusion
        
        var id: Int { self.rawValue }
    }
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    IntroEducationPage().tag(CBTPage.intro.rawValue)
                    TriangleEducationPage().tag(CBTPage.triangle.rawValue)
                    CycleEducationPage().tag(CBTPage.unhelpfulCycles.rawValue)
                    ThoughtRecordEducationPage().tag(CBTPage.thoughtRecords.rawValue)
                    DistortionsEducationPage().tag(CBTPage.distortions.rawValue)
                    EvidenceEducationPage().tag(CBTPage.evidence.rawValue)
                    BalancedEducationPage().tag(CBTPage.balancedPerspective.rawValue)
                    ResearchEducationPage().tag(CBTPage.science.rawValue)
                    FurtherReadingEducationPage().tag(CBTPage.furtherReading.rawValue)
                    ConclusionEducationPage().tag(CBTPage.conclusion.rawValue)
                }
                #if os(macOS)
                .tabViewStyle(.automatic)
                #else
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .onChange(of: currentPage) { _, _ in
                    HapticManager.shared.trigger(.selection)
                }
                
                bottomBar
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticManager.shared.lightImpact()
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Fix for floating toolbar blocking the button
            Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
        }
    }
    
    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Dots
            HStack(spacing: 8) {
                ForEach(CBTPage.allCases) { page in
                    Circle()
                        .fill(currentPage == page.rawValue ? themeManager.selectedColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(currentPage == page.rawValue ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.top, 12)
            
            // Next / Done Button
            Button {
                HapticManager.shared.lightImpact()
                if currentPage < CBTPage.allCases.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    dismiss()
                }
            } label: {
                Text(currentPage == CBTPage.allCases.count - 1 ? "Start My Journey" : "Next")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.selectedColor)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.cornerRadiusMedium)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 20)
            .frame(maxWidth: 400)
        }
        .background(
            ThemedBackground()
                .opacity(0.9)
                .blur(radius: 5)
                .overlay(Rectangle().fill(DSTheme.separator.opacity(0.2)).frame(height: 0.5), alignment: .top)
        )
    }
}
