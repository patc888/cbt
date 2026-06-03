import SwiftUI

struct AudioPlayerContent: Hashable, Identifiable {
    let id: String
    let title: String
    let description: String
    let assetFilename: String
    let durationSeconds: Int
    let systemImage: String

    init(
        id: String,
        title: String,
        description: String,
        assetFilename: String,
        durationSeconds: Int,
        systemImage: String = "headphones"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.assetFilename = assetFilename
        self.durationSeconds = max(durationSeconds, 0)
        self.systemImage = systemImage
    }
}

struct AudioPlaybackCompletion: Hashable, Identifiable {
    let id = UUID()
    let content: AudioPlayerContent
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
}

struct MindfulnessAudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let content: AudioPlayerContent
    let isUnlocked: Bool
    let stopsOnDisappear: Bool
    let onRequestUnlock: (() -> Void)?
    let onClose: () -> Void
    let onCompleted: ((AudioPlaybackCompletion) -> Void)?
    let onSaveCompletedSession: ((AudioPlaybackCompletion) -> Void)?

    @State private var sessionStartedAt: Date?
    @State private var completion: AudioPlaybackCompletion?
    @State private var attemptedPlayback = false

    init(
        content: AudioPlayerContent,
        isUnlocked: Bool = true,
        stopsOnDisappear: Bool = true,
        onRequestUnlock: (() -> Void)? = nil,
        onClose: @escaping () -> Void = {},
        onCompleted: ((AudioPlaybackCompletion) -> Void)? = nil,
        onSaveCompletedSession: ((AudioPlaybackCompletion) -> Void)? = nil
    ) {
        self.content = content
        self.isUnlocked = isUnlocked
        self.stopsOnDisappear = stopsOnDisappear
        self.onRequestUnlock = onRequestUnlock
        self.onClose = onClose
        self.onCompleted = onCompleted
        self.onSaveCompletedSession = onSaveCompletedSession
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            header
            progressSection
            controls

            if !isUnlocked {
                noticeRow(
                    title: "Premium audio",
                    message: "Unlock this session to start playback.",
                    systemImage: "lock.fill"
                )
            } else if !assetAvailable {
                noticeRow(
                    title: "Audio unavailable",
                    message: "This session is not available in this version of the app.",
                    systemImage: "headphones.circle"
                )
            } else if attemptedPlayback, let errorMessage = audioPlayer.errorMessage {
                noticeRow(
                    title: "Playback unavailable",
                    message: errorMessage,
                    systemImage: "exclamationmark.triangle.fill"
                )
            }

            if let completion {
                completionSection(completion)
            }
        }
        .padding(DSSpacing.large)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.18), lineWidth: 0.8)
        }
        .onChange(of: content.id) { _, _ in
            resetLocalPlaybackState()
        }
        .onDisappear {
            if stopsOnDisappear {
                audioPlayer.stop()
            }
        }
    }

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var assetAvailable: Bool {
        audioPlayer.localAssetExists(named: content.assetFilename)
    }

    private var isLoadedAudio: Bool {
        audioPlayer.isLoadedAsset(named: content.assetFilename)
    }

    private var isPlayingAudio: Bool {
        audioPlayer.isPlayingAsset(named: content.assetFilename)
    }

    private var effectiveDuration: TimeInterval {
        if isLoadedAudio, audioPlayer.duration > 0 {
            return audioPlayer.duration
        }

        if let completion {
            return TimeInterval(completion.durationSeconds)
        }

        return TimeInterval(content.durationSeconds)
    }

    private var effectiveCurrentTime: TimeInterval {
        if isLoadedAudio {
            return audioPlayer.currentTime
        }

        if completion != nil {
            return effectiveDuration
        }

        return 0
    }

    private var sliderRange: ClosedRange<TimeInterval> {
        0...max(effectiveDuration, 1)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DSSpacing.medium) {
            Image(systemName: content.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text(content.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(DSTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(DSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DSSpacing.small)

            Button {
                HapticManager.shared.lightImpact()
                audioPlayer.stop()
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(DSButtonStyle(variant: .neutral, size: .icon(40), expands: false, hapticType: nil))
            .accessibilityLabel("Close audio player")
        }
    }

    private var progressSection: some View {
        VStack(spacing: DSSpacing.small) {
            Slider(
                value: Binding(
                    get: { effectiveCurrentTime },
                    set: { audioPlayer.seek(to: $0) }
                ),
                in: sliderRange
            )
            .tint(accent)
            .disabled(!isLoadedAudio)
            .accessibilityLabel("Audio progress")

            HStack {
                Text(timecode(effectiveCurrentTime))
                Spacer()
                Text(timecode(effectiveDuration))
            }
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(DSTheme.secondaryText)
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DSSpacing.medium) {
                skipButton(systemImage: "gobackward.15", label: "Skip back 15 seconds") {
                    audioPlayer.seek(by: -15)
                }
                primaryPlaybackButton
                skipButton(systemImage: "goforward.15", label: "Skip forward 15 seconds") {
                    audioPlayer.seek(by: 15)
                }
            }

            VStack(spacing: DSSpacing.small) {
                primaryPlaybackButton
                HStack(spacing: DSSpacing.medium) {
                    skipButton(systemImage: "gobackward.15", label: "Skip back 15 seconds") {
                        audioPlayer.seek(by: -15)
                    }
                    skipButton(systemImage: "goforward.15", label: "Skip forward 15 seconds") {
                        audioPlayer.seek(by: 15)
                    }
                }
            }
        }
    }

    private var primaryPlaybackButton: some View {
        return Button {
            handlePrimaryPlayback()
        } label: {
            Label(primaryPlaybackTitle, systemImage: primaryPlaybackIcon)
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(
            DSButtonStyle(
                variant: isUnlocked && assetAvailable ? .primary : .secondary,
                hapticType: isUnlocked && assetAvailable ? .medium : .light
            )
        )
        .disabled(isUnlocked && !assetAvailable)
        .opacity(isUnlocked && !assetAvailable ? 0.55 : 1)
        .accessibilityLabel(primaryPlaybackAccessibilityLabel)
    }

    private var primaryPlaybackTitle: String {
        if !isUnlocked { return "Unlock" }
        if !assetAvailable { return "Unavailable" }
        if isPlayingAudio { return "Pause" }
        if isLoadedAudio { return "Resume" }
        if completion != nil { return "Replay" }
        return "Play"
    }

    private var primaryPlaybackIcon: String {
        if !isUnlocked { return "lock.fill" }
        if !assetAvailable { return "headphones.circle" }
        if isPlayingAudio { return "pause.fill" }
        return "play.fill"
    }

    private var primaryPlaybackAccessibilityLabel: String {
        if !isUnlocked { return "Unlock premium audio" }
        if !assetAvailable { return "Audio unavailable" }
        if isPlayingAudio { return "Pause audio" }
        if isLoadedAudio { return "Resume audio" }
        if completion != nil { return "Replay audio" }
        return "Play audio"
    }

    private func skipButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(54), expands: false, tint: accent, hapticType: .light))
        .disabled(!canSeek)
        .accessibilityLabel(label)
    }

    private var canSeek: Bool {
        assetAvailable && isUnlocked && isLoadedAudio
    }

    private func noticeRow(title: String, message: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(DSTheme.primaryText)
                Text(message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(DSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DSSpacing.medium)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
    }

    private func completionSection(_ completion: AudioPlaybackCompletion) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(DSTheme.success)

            if let onSaveCompletedSession {
                Button {
                    HapticManager.shared.lightImpact()
                    onSaveCompletedSession(completion)
                } label: {
                    Label("Save Session", systemImage: "book.pages")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .accessibilityLabel("Save completed audio session")
            }
        }
    }

    private func handlePrimaryPlayback() {
        if !isUnlocked {
            HapticManager.shared.warning()
            onRequestUnlock?()
            return
        }

        guard assetAvailable else {
            HapticManager.shared.warning()
            attemptedPlayback = true
            return
        }

        if isPlayingAudio {
            audioPlayer.pause()
            return
        }

        if isLoadedAudio {
            _ = audioPlayer.resume()
            return
        }

        completion = nil
        sessionStartedAt = Date()
        attemptedPlayback = true

        audioPlayer.playLocalAsset(named: content.assetFilename) { _ in
            handlePlaybackCompleted()
        }
    }

    private func handlePlaybackCompleted() {
        let endedAt = Date()
        let duration = Int(max(round(effectiveDuration), 1))
        let startedAt = sessionStartedAt ?? endedAt.addingTimeInterval(-TimeInterval(duration))
        let newCompletion = AudioPlaybackCompletion(
            content: content,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: duration
        )

        completion = newCompletion
        sessionStartedAt = nil
        HapticManager.shared.success()
        onCompleted?(newCompletion)
    }

    private func resetLocalPlaybackState() {
        audioPlayer.stop()
        sessionStartedAt = nil
        completion = nil
        attemptedPlayback = false
    }

    private func timecode(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }

        let totalSeconds = max(Int(time.rounded()), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
