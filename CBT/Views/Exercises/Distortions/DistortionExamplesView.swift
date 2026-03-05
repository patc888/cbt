import SwiftUI

struct DistortionExamplesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    
    @State private var selectedCategory: String = "All"
    @State private var currentExample: CognitiveDistortionExample?
    
    // Timer state
    @StateObject private var timerManager = TimedSessionManager()
    @State private var showingSaveSession = false
    @State private var completedSummary: SessionSummary?
    
    private let timerOptions = [120, 300] // 2m, 5m
    
    private let library = CognitiveDistortionsLibrary.shared
    
    private var allCategories: [String] {
        ["All"] + library.allDistortionNames()
    }
    
    private var currentList: [CognitiveDistortionExample] {
        if selectedCategory == "All" {
            return library.examples
        } else {
            return library.examples(for: selectedCategory)
        }
    }
    
    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.paddingLarge) {
                
                // Picker
                VStack(alignment: .leading, spacing: Theme.paddingSmall) {
                    Text("Filter by Distortion")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                        .padding(.horizontal, Theme.paddingMedium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.paddingSmall) {
                            ForEach(allCategories, id: \.self) { category in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    withAnimation {
                                        selectedCategory = category
                                        setRandomExample()
                                    }
                                }) {
                                    Text(category)
                                        .font(.system(size: 14, weight: selectedCategory == category ? .bold : .medium, design: .rounded))
                                        .padding(.horizontal, Theme.paddingMedium)
                                        .padding(.vertical, Theme.paddingSmall)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategory == category ? Theme.primaryColor : Theme.tertiaryBackground)
                                        )
                                        .foregroundColor(selectedCategory == category ? Theme.backgroundColor : Theme.primaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.paddingMedium)
                    }
                }
                .padding(.top, Theme.paddingMedium)
                
                // Timer bar (if running)
                if timerManager.isRunning || timerManager.isPaused {
                    timerBar
                        .padding(.horizontal, Theme.paddingMedium)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Card
                if let example = currentExample {
                    DistortionExampleCardView(example: example)
                        .padding(.horizontal, Theme.paddingMedium)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .id(example.id)
                } else {
                    Text("No examples available.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(Theme.paddingMedium)
                        .cardStyle()
                        .padding(.horizontal, Theme.paddingMedium)
                }
                
                // Controls
                HStack(spacing: Theme.paddingMedium) {
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation { setRandomExample() }
                    }) {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.paddingMedium)
                            .background(Theme.tertiaryBackground)
                            .foregroundColor(Theme.primaryText)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation { setNextExample() }
                    }) {
                        Label("Next", systemImage: "arrow.right")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.paddingMedium)
                            .background(Theme.primaryColor)
                            .foregroundColor(Theme.backgroundColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.paddingMedium)
                .padding(.top, Theme.paddingSmall)
                
                // Practice Timer Button
                if !timerManager.isRunning && !timerManager.isPaused {
                    Menu {
                        ForEach(timerOptions, id: \.self) { seconds in
                            Button("\(seconds / 60) min") {
                                startPracticeTimer(seconds: seconds)
                            }
                        }
                    } label: {
                        Label("Practice Timer", systemImage: "timer")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.paddingMedium)
                            .background(accent.opacity(0.12))
                            .foregroundColor(accent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, Theme.paddingMedium)
                }
                
            }
            .padding(.bottom, Theme.paddingXLarge)
        }
        .background(Theme.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Distortion Examples")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if currentExample == nil {
                setRandomExample()
            }
            timerManager.onComplete = { summary in
                completedSummary = summary
                showingSaveSession = true
            }
        }
        .sheet(isPresented: $showingSaveSession) {
            if let summary = completedSummary {
                SaveSessionView(summary: summary)
            }
        }
        .onDisappear {
            timerManager.stop()
        }
    }
    
    // MARK: - Timer Bar
    private var timerBar: some View {
        HStack(spacing: DSSpacing.medium) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: 3)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
            }

            Text(timerManager.formattedRemaining)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DSTheme.primaryText)

            Spacer()

            if timerManager.isPaused {
                Button {
                    HapticManager.shared.lightImpact()
                    timerManager.resume()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    HapticManager.shared.lightImpact()
                    timerManager.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            Button {
                HapticManager.shared.mediumImpact()
                timerManager.endEarly()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DSTheme.destructive)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.large)
        .padding(.vertical, DSSpacing.medium)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
    }
    
    // MARK: - Timer Start
    private func startPracticeTimer(seconds: Int) {
        HapticManager.shared.lightImpact()
        guard let example = currentExample else { return }
        let bodyText = """
        Thought: \(example.thought)
        Explanation: \(example.explanation)
        Balanced thought: \(example.balancedThought)
        """
        let summary = SessionSummary(
            sourceKind: .distortionExample,
            sourceID: example.id,
            title: example.distortion,
            bodyText: bodyText,
            durationSeconds: seconds,
            startedAt: Date(),
            endedAt: Date()
        )
        timerManager.start(durationSeconds: seconds, summary: summary)
    }
    
    private func setRandomExample() {
        let list = currentList
        guard !list.isEmpty else {
            currentExample = nil
            return
        }
        if list.count == 1 {
            currentExample = list.first
            return
        }
        var next = list.randomElement()
        // Prevent same example twice
        while next?.id == currentExample?.id && list.count > 1 {
            next = list.randomElement()
        }
        currentExample = next
    }
    
    private func setNextExample() {
        let list = currentList
        guard !list.isEmpty else {
            currentExample = nil
            return
        }
        guard let current = currentExample, let idx = list.firstIndex(where: { $0.id == current.id }) else {
            currentExample = list.first
            return
        }
        let nextIdx = (idx + 1) % list.count
        currentExample = list[nextIdx]
    }
}
