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

// MARK: - Individual Pages

struct PagerLayout<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.primaryText)
                            .padding(.horizontal, 24)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(.body, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    content()
                        .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct IntroEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "What is CBT?",
            subtitle: "Cognitive Behavioral Therapy (CBT) is an evidence-based approach to mental wellness."
        ) {
            VStack(spacing: 20) {
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.title2)
                                .foregroundStyle(themeManager.selectedColor)
                            Text("Practical Tools")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                        }
                        
                        Text("Unlike some therapies that focus on the past, CBT is centered on the 'here and now'. It gives you practical tools to manage stress, anxiety, and low mood in your daily life.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title2)
                                .foregroundStyle(themeManager.selectedColor)
                            Text("Breaking Cycles")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                        }
                        
                        Text("CBT is based on the idea that how we think (Cognition) and how we act (Behavior) directly impact how we feel.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }
}

struct TriangleEducationPage: View {
    @State private var activeNode: CBTDiagramTriangle.CBTNodeType? = .thought
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "The CBT Triangle",
            subtitle: "Your thoughts, emotions, and behaviors are all interconnected."
        ) {
            VStack(spacing: 24) {
                InteractiveCBTTriangle(activeNode: $activeNode)
                    .frame(height: 220)
                    .padding(.vertical)
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(activeNodeTitle)
                            .font(.headline)
                            .foregroundStyle(themeManager.selectedColor)
                        
                        Text(activeNodeDescription)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .id(activeNode)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                }
                
                Text("Tap the nodes above to see how they interact.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
            }
        }
    }
    
    private var activeNodeTitle: String {
        switch activeNode {
        case .thought: return "Thoughts"
        case .emotion: return "Emotions"
        case .behavior: return "Behaviors"
        case .none: return "The Connection"
        }
    }
    
    private var activeNodeDescription: String {
        switch activeNode {
        case .thought: return "What we tell ourselves about a situation. These can be helpful or unhelpful, facts or interpretations."
        case .emotion: return "How we feel in our body and mind (e.g., anxiety, sadness, joy). Emotions often follow our interpretations."
        case .behavior: return "What we do in response. This includes actions, avoidance, or habits that can reinforce how we feel."
        case .none: return "Select a node to learn more about how it contributes to your well-being."
        }
    }
}

struct CycleEducationPage: View {
    @State private var step = 0
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Unhelpful Cycles",
            subtitle: "A single event can trigger a spiral. CBT helps you spot these cycles early."
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    CycleStep(icon: "bell.fill", title: "Trigger Event", description: "You receive a brief email from your boss: 'Let's meet tomorrow.'", isActive: step >= 0)
                    
                    Arrow()
                    
                    CycleStep(icon: "bubble.left.fill", title: "Thought", description: "'I'm in trouble. I'm going to get fired.'", isActive: step >= 1)
                    
                    Arrow()
                    
                    CycleStep(icon: "heart.fill", title: "Emotion", description: "Intense anxiety, heart racing, inability to focus.", isActive: step >= 2)
                    
                    Arrow()
                    
                    CycleStep(icon: "figure.walk", title: "Behavior", description: "Avoid preparing for the meeting; stay up late worrying.", isActive: step >= 3)
                }
                .padding()
                .background(Theme.cardBackground.opacity(0.5))
                .cornerRadius(16)
                
                HStack {
                    Button("Reset") { withAnimation { step = 0 } }
                        .font(.caption.bold())
                        .foregroundStyle(Theme.secondaryText)
                    
                    Spacer()
                    
                    Button(step < 3 ? "Next Step" : "Cycle Complete") {
                        if step < 3 {
                            withAnimation(.spring()) { step += 1 }
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeManager.selectedColor.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
    }
    
    struct CycleStep: View {
        let icon: String
        let title: String
        let description: String
        let isActive: Bool
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .padding(8)
                    .background(isActive ? Theme.primaryColor : Color.secondary.opacity(0.2))
                    .foregroundStyle(isActive ? .white : Color.secondary)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isActive ? Theme.primaryText : Color.secondary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(isActive ? Theme.secondaryText : Color.secondary.opacity(0.5))
                }
                Spacer()
            }
            .opacity(isActive ? 1.0 : 0.4)
        }
    }
    
    struct Arrow: View {
        var body: some View {
            Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.secondaryText.opacity(0.3))
                .padding(.leading, 18)
        }
    }
}

struct ThoughtRecordEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Thought Records",
            subtitle: "The most powerful tool in the CBT toolkit for processing difficult moments."
        ) {
            VStack(spacing: 20) {
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why write it down?")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("Writing down your thoughts helps you step back and see them as 'mental events' rather than absolute facts. This 'de-centering' is key to emotional regulation.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    StepRow(number: "1", title: "The Situation", description: "What happened? (Who, where, when)")
                    StepRow(number: "2", title: "Automatic Thoughts", description: "What went through your mind at that exact moment?")
                    StepRow(number: "3", title: "Emotions", description: "What did you feel, and how intense was it (0-100%)?")
                    StepRow(number: "4", title: "Evidence", description: "Look for facts that support AND facts that contradict the thought.")
                    StepRow(number: "5", title: "Balanced Perspective", description: "Write a more accurate, helpful view based on the evidence.")
                }
                .padding(.top, 8)
            }
        }
    }
    
    struct StepRow: View {
        let number: String
        let title: String
        let description: String
        @Environment(ThemeManager.self) private var themeManager
        
        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Text(number)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 32, height: 32)
                    .background(themeManager.selectedColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}

struct DistortionsEducationPage: View {
    @State private var selectedDistortion: String? = "All-of-Nothing"
    @Environment(ThemeManager.self) private var themeManager
    
    struct Distortion: Identifiable {
        let title: String
        let description: String
        var id: String { title }
    }
    
    let distortions = [
        Distortion(title: "All-or-Nothing", description: "Viewing things in black-and-white. 'If I'm not perfect, I failed.'"),
        Distortion(title: "Overgeneralization", description: "Seeing a single negative event as a never-ending pattern of defeat."),
        Distortion(title: "Mental Filter", description: "Picking out a single negative detail and dwelling on it exclusively."),
        Distortion(title: "Catastrophizing", description: "Assuming the worst possible outcome will happen, even with little evidence."),
        Distortion(title: "Mind Reading", description: "Assuming people are thinking negatively about you without proof.")
    ]
    
    private var selectedDescription: String? {
        distortions.first(where: { $0.title == selectedDistortion })?.description
    }
    
    var body: some View {
        PagerLayout(
            title: "Thinking Traps",
            subtitle: "We all fall into common patterns of distorted thinking. Recognizing them is half the battle."
        ) {
            VStack(spacing: 16) {
                ForEach(distortions) { item in
                    DistortionButton(
                        item: item,
                        isSelected: selectedDistortion == item.title,
                        themeColor: themeManager.selectedColor
                    ) {
                        withAnimation { selectedDistortion = item.title }
                    }
                }
                
                if let selected = selectedDistortion, let desc = selectedDescription {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selected)
                                .font(.headline)
                                .foregroundStyle(themeManager.selectedColor)
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id(selected)
                }
            }
        }
    }
}

struct DistortionButton: View {
    let item: DistortionsEducationPage.Distortion
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : Theme.primaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? AnyView(themeColor) : Theme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct EvidenceEducationPage: View {
    @State private var balance: CGFloat = -0.5 // -1 to 1
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Evidence for & Against",
            subtitle: "Treat your thoughts like a scientist. Look for the actual facts, not just feelings."
        ) {
            VStack(spacing: 24) {
                // Interactive Balance Scale
                VStack(spacing: 12) {
                    ZStack {
                        // The Beam
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 8)
                            .rotationEffect(.degrees(Double(balance * 20)))
                        
                        // Pivot
                        TriangleIcon()
                            .fill(Theme.secondaryText.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .offset(y: 20)
                        
                        // Left Plate (Evidence FOR)
                        VStack {
                            Image(systemName: "hand.thumbsdown.fill")
                                .foregroundStyle(.red.opacity(0.6))
                            Text("FOR")
                                .font(.caption2.bold())
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                        .offset(x: -100, y: balance * 30)
                        
                        // Right Plate (Evidence AGAINST)
                        VStack {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundStyle(.green.opacity(0.6))
                            Text("AGAINST")
                                .font(.caption2.bold())
                                .foregroundStyle(.green.opacity(0.6))
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                        .offset(x: 100, y: -balance * 30)
                    }
                    .frame(height: 120)
                    .padding(.top, 20)
                    
                    Slider(value: $balance, in: -1...1)
                        .tint(themeManager.selectedColor)
                }
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Weight of Evidence")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("Often, we give 'Negative Evidence' (feelings, past mistakes) too much weight. 'Positive Evidence' (facts, recent successes) is often ignored. CBT balances the scale.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ask yourself:")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    BulletPoint(text: "Is there any other way to look at this?")
                    BulletPoint(text: "If a friend had this thought, what would I say?")
                    BulletPoint(text: "What facts support the opposite conclusion?")
                }
            }
        }
    }
    
    struct TriangleIcon: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

struct BalancedEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Balanced Perspective",
            subtitle: "The goal isn't just 'positive thinking'—it's 'accurate thinking'."
        ) {
            VStack(spacing: 24) {
                ComparisonView(
                    title: "Automatic Thought",
                    content: "'I made a mistake in the presentation. Everyone thinks I'm incompetent.'",
                    color: .red,
                    icon: "cloud.bolt.fill"
                )
                
                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(themeManager.selectedColor)
                
                ComparisonView(
                    title: "Balanced Thought",
                    content: "'I made one mistake, but the rest went well. Mistakes are human, and no one said they were unhappy.'",
                    color: .green,
                    icon: "sparkles"
                )
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Shift")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("A balanced thought is grounded in all the evidence. It acknowledges the difficulty while also recognizing your strengths and alternative explanations.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }
    
    struct ComparisonView: View {
        let title: String
        let content: String
        let color: Color
        let icon: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .textCase(.uppercase)
                }
                
                Text(content)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}

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
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
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
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
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
            }
        }
    }
}

struct ConclusionEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "The Road Ahead",
            subtitle: "You now have the foundation. The next step is practice."
        ) {
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.selectedColor)
                    .padding()
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to use this app:")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            BulletItem(icon: "face.smiling", text: "Check into your mood daily to see patterns.")
                            BulletItem(icon: "pencil.and.outline", text: "Fill out a Thought Record when you feel stressed.")
                            BulletItem(icon: "wind", text: "Use the Breathing Reset to calm your body.")
                            BulletItem(icon: "chart.line.uptrend.xyaxis", text: "Review your progress in Insights.")
                        }
                    }
                }
                
                Text("Consistency is more important than perfection. Take it one thought at a time.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 24)
            }
        }
    }
    
    struct BulletItem: View {
        let icon: String
        let text: String
        @Environment(ThemeManager.self) private var themeManager
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 24)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
