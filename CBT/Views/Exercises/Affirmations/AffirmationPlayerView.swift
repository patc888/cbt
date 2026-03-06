import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AffirmationPlayerView: View {
    @State private var store = AffirmationFavoritesStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var allAffirmations: [Affirmation] = AffirmationsLoader.shared.affirmations
    
    // "All" vs "Favorites"
    @State private var showingFavorites: Bool = false
    
    // Index state
    @State private var currentIndex: Int = 0
    
    // Drag state
    @State private var dragOffset: CGSize = .zero
    
    // Timer state
    @StateObject private var timerManager = TimedSessionManager()
    @State private var showingTimerPicker = false
    @State private var showingSaveSession = false
    @State private var completedSummary: SessionSummary?
    
    private let timerOptions = [60, 120, 300] // 1m, 2m, 5m
    
    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }
    
    var currentList: [Affirmation] {
        if showingFavorites {
            let favs = allAffirmations.filter { store.isFavorite(id: $0.id) }
            return favs.isEmpty ? [Affirmation(id: "empty", category: "Info", text: "No favorites yet. \n\nTap the heart to save one!")] : favs
        }
        return allAffirmations
    }
    
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()
            
            VStack {
                // Header Options
                headerContent
                
                // Timer bar (if running)
                if timerManager.isRunning || timerManager.isPaused {
                    timerBar
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                
                // Pager (Interactive Stack)
                if currentList.count > 0 {
                    ZStack {
                        let maxVisible = min(3, currentList.count)
                        ForEach((0..<maxVisible).reversed(), id: \.self) { stackedOffset in
                            let index = (currentIndex + stackedOffset) % currentList.count
                            if index < currentList.count {
                                let affirmation = currentList[index]
                                let isTop = (stackedOffset == 0)
                                
                                AffirmationCardView(affirmation: affirmation)
                                    .offset(y: isTop ? dragOffset.height : CGFloat(stackedOffset * 15))
                                    .offset(x: isTop ? dragOffset.width : 0)
                                    .rotationEffect(isTop ? .degrees(Double(dragOffset.width / 30.0)) : .zero)
                                    .scaleEffect(isTop ? 1.0 : 1.0 - CGFloat(stackedOffset) * 0.05)
                                    .zIndex(Double(-stackedOffset))
                                    .gesture(
                                        isTop ? DragGesture()
                                            .onChanged { value in
                                                withAnimation(reduceMotion ? .none : .interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                                    dragOffset = value.translation
                                                }
                                            }
                                            .onEnded { value in
                                                let threshold: CGFloat = 100
                                                // Swipe to dismiss
                                                if abs(value.translation.width) > threshold || abs(value.translation.height) > threshold {
                                                    let isRight = value.translation.width > 0
                                                    let isDown = value.translation.height > 0
                                                    
                                                    withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)) {
                                                        dragOffset.width = isRight ? 500 : (abs(value.translation.width) > threshold ? -500 : 0)
                                                        dragOffset.height = isDown ? 500 : (abs(value.translation.height) > threshold ? -500 : 0)
                                                    }
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.2)) {
                                                        dragOffset = .zero
                                                        withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                                                            advanceNext()
                                                        }
                                                    }
                                                } else {
                                                    // Snap back
                                                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                                                        dragOffset = .zero
                                                    }
                                                }
                                            } : nil
                                    )
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Affirmation \(currentIndex + 1) of \(currentList.count). \(affirmation.text)")
                                    .accessibilityHint("Swipe left or right to see next affirmation")
                            }
                        }
                    }
                    .frame(maxHeight: 520)
                } else {
                    Spacer()
                }
                
                // Bottom Secondary Actions
                if let currentAffirmation = currentList.indices.contains(currentIndex) ? currentList[currentIndex] : nil, currentAffirmation.id != "empty" {
                    secondaryActions(affirmation: currentAffirmation)
                }
                
                Spacer().frame(height: DSSpacing.large)
                
                // Bottom Controls
                primaryControls
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Affirmations")
        .onChange(of: showingFavorites) { _, _ in
            currentIndex = 0
            triggerSelectionHaptic()
        }
        .onAppear {
            if allAffirmations.isEmpty {
                allAffirmations = AffirmationsLoader.shared.affirmations
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
            // Progress
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
                .accessibilityLabel("Resume timer")
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
                .accessibilityLabel("Pause timer")
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
            .accessibilityLabel("Stop timer")
        }
        .padding(.horizontal, DSSpacing.large)
        .padding(.vertical, DSSpacing.medium)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
        .padding(.horizontal, DSSpacing.large)
    }
    
    private var headerContent: some View {
        HStack {
            Picker("Filter", selection: $showingFavorites) {
                Text("All").tag(false)
                Text("Favorites").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            
            Spacer()
            
            // Timer button
            if !timerManager.isRunning && !timerManager.isPaused {
                Menu {
                    ForEach(timerOptions, id: \.self) { seconds in
                        Button("\(seconds / 60) min") {
                            startTimer(seconds: seconds)
                        }
                    }
                } label: {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(DSSpacing.small)
                        .background(DSTheme.elevatedFill)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Session timer")
                .accessibilityHint("Select a duration to start a timed session")
            }
            
            Text("\(currentIndex + 1) / \(currentList.count)")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)
                .padding(.horizontal, DSSpacing.medium)
                .padding(.vertical, DSSpacing.small)
                .background(DSTheme.elevatedFill)
                .clipShape(Capsule())
        }
        .padding(DSSpacing.large)
    }
    
    private func secondaryActions(affirmation: Affirmation) -> some View {
        HStack(spacing: DSSpacing.xLarge) {
            // Favorite Button
            Button {
                store.toggleFavorite(id: affirmation.id)
                triggerFavoriteHaptic()
            } label: {
                Image(systemName: store.isFavorite(id: affirmation.id) ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundStyle(store.isFavorite(id: affirmation.id) ? DSTheme.destructive : DSTheme.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(store.isFavorite(id: affirmation.id) ? "Remove from favorites" : "Add to favorites")
            
            // Copy Button
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = affirmation.text
                triggerSuccessHaptic()
                #endif
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 20))
                    .foregroundStyle(DSTheme.secondaryText)
            }
            
            // Share Button
            ShareLink(item: affirmation.text) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundStyle(DSTheme.secondaryText)
            }
        }
        .padding(.vertical, DSSpacing.medium)
    }
    
    private var primaryControls: some View {
        HStack(spacing: DSSpacing.large) {
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                    advancePrev()
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(DSTheme.elevatedFill, accent)
            }
            .accessibilityLabel("Previous affirmation")
            
            Button {
                if currentList.count > 1 {
                    var newIndex = currentIndex
                    while newIndex == currentIndex {
                        newIndex = Int.random(in: 0..<currentList.count)
                    }
                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                        currentIndex = newIndex
                    }
                    triggerSelectionHaptic()
                }
            } label: {
                Image(systemName: "shuffle.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(DSTheme.elevatedFill, accent)
            }
            .accessibilityLabel("Shuffle affirmations")
            
            Button {
                // Simulate swipe off animation
                withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset.width = -500
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.2)) {
                    dragOffset = .zero
                    withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7)) {
                        advanceNext()
                    }
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(DSTheme.elevatedFill, accent)
            }
            .accessibilityLabel("Next affirmation")
        }
    }
    
    // MARK: - Timer
    private func startTimer(seconds: Int) {
        HapticManager.shared.lightImpact()
        let currentAffirmation = currentList.indices.contains(currentIndex) ? currentList[currentIndex] : nil
        let summary = SessionSummary(
            sourceKind: .affirmation,
            sourceID: currentAffirmation?.id ?? "",
            title: "Affirmations",
            bodyText: currentAffirmation?.text ?? "Session of affirmations",
            durationSeconds: seconds,
            startedAt: Date(),
            endedAt: Date()
        )
        timerManager.start(durationSeconds: seconds, summary: summary)
    }
    
    private func advanceNext() {
        if currentIndex < currentList.count - 1 {
            currentIndex += 1
        } else if currentList.count > 1 {
            currentIndex = 0
        }
        triggerSelectionHaptic()
    }
    
    private func advancePrev() {
        if currentIndex > 0 {
            currentIndex -= 1
        } else if currentList.count > 1 {
            currentIndex = currentList.count - 1
        }
        triggerSelectionHaptic()
    }
    
    private func triggerSelectionHaptic() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
    
    private func triggerSuccessHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func triggerFavoriteHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}
