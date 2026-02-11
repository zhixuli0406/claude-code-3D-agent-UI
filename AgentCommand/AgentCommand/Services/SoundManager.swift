import Foundation
import AppKit

/// Manages sound effects for agent events
@MainActor
class SoundManager: ObservableObject {
    enum SoundEffect: String {
        case taskComplete
        case error
        case permissionRequest
        case typing
        case levelUp
        case achievement
        case streakBreak
        case coinEarned
        case discovery
    }

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "soundMuted") }
    }
    @Published var volume: Float = 0.7

    private var typingTimer: Timer?

    init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "soundMuted")
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted else { return }

        let soundName: NSSound.Name
        switch effect {
        case .taskComplete:
            soundName = "Glass"
        case .error:
            soundName = "Basso"
        case .permissionRequest:
            soundName = "Ping"
        case .typing:
            soundName = "Tink"
        case .levelUp:
            soundName = "Hero"
        case .achievement:
            soundName = "Purr"
        case .streakBreak:
            soundName = "Funk"
        case .coinEarned:
            soundName = "Pop"
        case .discovery:
            soundName = "Submarine"
        }

        if let sound = NSSound(named: soundName) {
            sound.volume = volume
            sound.play()
        }
    }

    func startTypingSounds() {
        guard typingTimer == nil else { return }
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.play(.typing)
            }
        }
    }

    func stopTypingSounds() {
        typingTimer?.invalidate()
        typingTimer = nil
    }
}
