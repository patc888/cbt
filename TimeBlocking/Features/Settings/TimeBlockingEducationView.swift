import SwiftUI

struct TimeBlockingEducationView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Page Data
    enum EducationPage: Int, CaseIterable, Identifiable {
        case intro = 0
        case cycle
        case benefits
        case tips
        case conclusion
        
        var id: Int { self.rawValue }
    }
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    TBIntroPage().tag(EducationPage.intro.rawValue)
                    TBCyclePage().tag(EducationPage.cycle.rawValue)
                    TBComparisonPage().tag(EducationPage.benefits.rawValue)
                    TBTipsPage().tag(EducationPage.tips.rawValue)
                    TBConclusionPage().tag(EducationPage.conclusion.rawValue)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    HapticManager.shared.lightImpact()
                }
                
                bottomBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Settings")
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryPurple)
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
    }
    
    private var bottomBar: some View {
        VStack(spacing: 16) {
            // Dots
            HStack(spacing: 8) {
                ForEach(EducationPage.allCases) { page in
                    Circle()
                        .fill(currentPage == page.rawValue ? Theme.primaryPurple : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(currentPage == page.rawValue ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.top, 12)
            
            // Next / Done Button
            Button {
                HapticManager.shared.mediumImpact()
                if currentPage < EducationPage.allCases.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    dismiss()
                }
            } label: {
                Text(currentPage == EducationPage.allCases.count - 1 ? "Start Blocking" : "Next")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.primaryPurple)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.cornerRadiusMedium)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 30)
            .frame(maxWidth: 400)
        }
        .background(.ultraThinMaterial.opacity(0.9))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Layout Helper

struct TBPagerLayout<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
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
                    
                    Spacer(minLength: 100)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Intro Page

struct TBIntroPage: View {
    var body: some View {
        TBPagerLayout(
            title: "What is\nTime Blocking?",
            subtitle: "A productivity method where you schedule every part of your day."
        ) {
            VStack(spacing: 20) {
                TimeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primaryPurple)
                            Text("Take Control")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                        }
                        
                        Text("Instead of a simple to-do list, you decide exactly WHEN you will tackle each task. This turns 'I should do this' into 'I WILL do this at 10 AM'.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                TimeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bolt.shield.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primaryPurple)
                            Text("Protect Your Focus")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                        }
                        
                        Text("By pre-allocating time, you protect your most important work from the 'tyranny of the urgent' and minor distractions.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }
}

// MARK: - Cycle Page (The Interactive Part)

struct TBCyclePage: View {
    @State private var activeStep: Int? = 0
    
    struct Step: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let description: String
    }
    
    let steps = [
        Step(id: 0, title: "Brain Dump", icon: "lightbulb.fill", description: "Empty your mind of all tasks, ideas, and commitments into a single list."),
        Step(id: 1, title: "Schedule", icon: "calendar.badge.plus", description: "Drag tasks into your day. Give every important task a dedicated home."),
        Step(id: 2, title: "Execute", icon: "timer", description: "Follow the plan. Focus ONLY on the current block until the timer ends."),
        Step(id: 3, title: "Review", icon: "arrow.clockwise", description: "See what shifted. Adjust for tomorrow to build a more realistic rhythm.")
    ]
    
    var body: some View {
        TBPagerLayout(
            title: "The Golden Cycle",
            subtitle: "Consistent time blocking follows a simple, repeatable 4-step rhythm."
        ) {
            VStack(spacing: 24) {
                // Interactive Cycle Diagram
                ZStack {
                    Circle()
                        .stroke(Theme.primaryPurple.opacity(0.1), lineWidth: 40)
                        .frame(width: 220, height: 220)
                    
                    ForEach(steps) { step in
                        CycleNode(step: step, activeStep: $activeStep)
                            .offset(
                                x: 110 * cos(CGFloat(step.id) * .pi / 2 - .pi / 2),
                                y: 110 * sin(CGFloat(step.id) * .pi / 2 - .pi / 2)
                            )
                    }
                    
                    // Center Icon
                    Image(systemName: "infinity")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.primaryPurple.opacity(0.3))
                }
                .frame(height: 280)
                
                if let activeStep = activeStep {
                    TimeCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(steps[activeStep].title)
                                .font(.headline)
                                .foregroundStyle(Theme.primaryPurple)
                            
                            Text(steps[activeStep].description)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .id(activeStep)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                    }
                }
                
                Text("Tap each step to see how it works.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.7))
            }
        }
    }
    
    struct CycleNode: View {
        let step: Step
        @Binding var activeStep: Int?
        
        var body: some View {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    activeStep = step.id
                }
                HapticManager.shared.lightImpact()
            } label: {
                VStack(spacing: 8) {
                    Circle()
                        .fill(activeStep == step.id ? Theme.primaryPurple : Theme.cardBackground)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: step.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(activeStep == step.id ? .white : Theme.primaryPurple)
                        )
                        .shadow(color: Theme.primaryPurple.opacity(activeStep == step.id ? 0.3 : 0.1), radius: 8, y: 4)
                        .overlay(
                            Circle()
                                .stroke(Theme.primaryPurple.opacity(0.2), lineWidth: 2)
                        )
                        .scaleEffect(activeStep == step.id ? 1.15 : 1.0)
                    
                    Text(step.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(activeStep == step.id ? Theme.primaryPurple : Theme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Theme.cardBackground.opacity(0.8))
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Comparison Page

struct TBComparisonPage: View {
    var body: some View {
        TBPagerLayout(
            title: "List vs. Block",
            subtitle: "Why a traditional to-do list often fails where time blocking succeeds."
        ) {
            VStack(spacing: 24) {
                ComparisonView(
                    title: "The To-Do List",
                    content: "An abstract list of tasks with no relation to time. Leads to procrastination and 'cherry-picking' easy tasks.",
                    color: .red,
                    icon: "list.bullet"
                )
                
                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(Theme.primaryPurple)
                
                ComparisonView(
                    title: "The Time Block",
                    content: "A concrete commitment to do a specific task at a specific time. Reduces decision fatigue and guarantees progress.",
                    color: .green,
                    icon: "calendar.badge.clock"
                )
                
                TimeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Shift")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("A to-do list asks 'What should I do?'. A time block answers 'When will I do it?'. This subtle shift is the key to consistency.")
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

// MARK: - Tips Page

struct TBTipsPage: View {
    var body: some View {
        TBPagerLayout(
            title: "Pro Tips",
            subtitle: "How to avoid the common pitfalls of a rigid schedule."
        ) {
            VStack(spacing: 20) {
                TipRow(icon: "shield.fill", title: "Add Buffer Time", color: .blue, text: "Never schedule blocks back-to-back. Add 15m transitions for emails or snacks.")
                TipRow(icon: "paintpalette.fill", title: "Color Code", color: .purple, text: "Distinguish between deep work, meetings, and personal time at a glance.")
                TipRow(icon: "scissors", title: "Be Realistic", color: .orange, text: "Tasks always take 2x longer than you think. Build in a 'Catch-up' block in the afternoon.")
                TipRow(icon: "hammer.fill", title: "Rough Drafts", color: .green, text: "Your schedule is a plan, not a prison. Adjust it as the day evolves.")
            }
        }
    }
    
    struct TipRow: View {
        let icon: String
        let title: String
        let color: Color
        let text: String
        
        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}

// MARK: - Conclusion Page

struct TBConclusionPage: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TBPagerLayout(
            title: "Ready to\nOptimize?",
            subtitle: "Time blocking is a skill that gets better with every single day."
        ) {
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryPurple.opacity(0.1))
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Theme.primaryPurple.gradient)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    Text("Don't worry about being perfect.")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    Text("The goal isn't to follow a script perfectly, it's to be intentional about where your most valuable resource—Time—is going.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    TimeBlockingEducationView()
}
