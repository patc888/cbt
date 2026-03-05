import Foundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if os(macOS)
import AppKit
#endif

@MainActor
final class BreathingSoundManager {
    func playPhaseChange() {
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1104)
        #elseif os(macOS)
        NSSound.beep()
        #endif
    }
}
