import Foundation
import AppKit
import AVFoundation

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
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "soundMuted")
            if isMuted {
                ambientPlayer?.volume = 0
            } else {
                ambientPlayer?.volume = ambientVolume
            }
        }
    }
    @Published var volume: Float = 0.7

    @Published var ambientVolume: Float {
        didSet {
            UserDefaults.standard.set(ambientVolume, forKey: "ambientVolume")
            if !isMuted {
                ambientPlayer?.volume = ambientVolume
            }
        }
    }

    @Published var isAmbientEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAmbientEnabled, forKey: "ambientEnabled")
            if isAmbientEnabled {
                if let theme = currentAmbientTheme {
                    playAmbientSound(for: theme)
                }
            } else {
                stopAmbientSound()
            }
        }
    }

    private var typingTimer: Timer?
    private var ambientPlayer: AVAudioPlayer?
    private var currentAmbientTheme: SceneTheme?

    init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "soundMuted")
        let savedAmbientVolume = UserDefaults.standard.float(forKey: "ambientVolume")
        self.ambientVolume = savedAmbientVolume > 0 ? savedAmbientVolume : 0.3
        if UserDefaults.standard.object(forKey: "ambientEnabled") == nil {
            self.isAmbientEnabled = true
        } else {
            self.isAmbientEnabled = UserDefaults.standard.bool(forKey: "ambientEnabled")
        }
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

    // MARK: - Ambient Environment Sounds

    func playAmbientSound(for theme: SceneTheme) {
        currentAmbientTheme = theme
        guard isAmbientEnabled, !isMuted else { return }

        // Stop any existing ambient playback
        ambientPlayer?.stop()
        ambientPlayer = nil

        // Try to load the theme's ambient sound file from the bundle
        let soundId = theme.ambientSound
        if let url = Bundle.main.url(forResource: soundId, withExtension: "mp3")
            ?? Bundle.main.url(forResource: soundId, withExtension: "m4a")
            ?? Bundle.main.url(forResource: soundId, withExtension: "wav")
            ?? Bundle.main.url(forResource: soundId, withExtension: "aiff") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1 // loop indefinitely
                player.volume = ambientVolume
                player.prepareToPlay()
                player.play()
                ambientPlayer = player
            } catch {
                // Silently fail — ambient sound is non-critical
            }
        } else {
            // No bundled audio file; generate procedural ambient sound using system sounds
            startProceduralAmbient(for: theme)
        }
    }

    func stopAmbientSound() {
        ambientPlayer?.stop()
        ambientPlayer = nil
        ambientTimer?.invalidate()
        ambientTimer = nil
    }

    // MARK: - Procedural Ambient (fallback using system sounds)

    private var ambientTimer: Timer?

    private func startProceduralAmbient(for theme: SceneTheme) {
        ambientTimer?.invalidate()

        let config = proceduralConfig(for: theme)
        ambientTimer = Timer.scheduledTimer(withTimeInterval: config.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isAmbientEnabled, !self.isMuted else { return }
                let soundName = config.sounds.randomElement() ?? "Tink"
                if let sound = NSSound(named: NSSound.Name(soundName)) {
                    sound.volume = self.ambientVolume * config.volumeScale
                    sound.play()
                }
            }
        }
    }

    private struct ProceduralAmbientConfig {
        let sounds: [String]
        let interval: TimeInterval
        let volumeScale: Float
    }

    private func proceduralConfig(for theme: SceneTheme) -> ProceduralAmbientConfig {
        switch theme {
        case .commandCenter:
            // Subtle electronic hums and beeps
            return ProceduralAmbientConfig(sounds: ["Tink", "Pop", "Morse"], interval: 4.0, volumeScale: 0.3)
        case .floatingIslands:
            // Gentle wind and nature
            return ProceduralAmbientConfig(sounds: ["Breeze", "Tink", "Pop"], interval: 5.0, volumeScale: 0.25)
        case .dungeon:
            // Dark dripping and echoes
            return ProceduralAmbientConfig(sounds: ["Pop", "Bottle", "Tink"], interval: 6.0, volumeScale: 0.2)
        case .spaceStation:
            // Sci-fi beeps and hums
            return ProceduralAmbientConfig(sounds: ["Morse", "Tink", "Submarine"], interval: 5.0, volumeScale: 0.25)
        case .cyberpunkCity:
            // Urban electronic pulses
            return ProceduralAmbientConfig(sounds: ["Pop", "Morse", "Tink"], interval: 3.5, volumeScale: 0.3)
        case .medievalCastle:
            // Torch crackling and stone echoes
            return ProceduralAmbientConfig(sounds: ["Tink", "Pop", "Bottle"], interval: 6.0, volumeScale: 0.2)
        case .underwaterLab:
            // Bubbles and sonar
            return ProceduralAmbientConfig(sounds: ["Submarine", "Pop", "Bubble"], interval: 4.0, volumeScale: 0.25)
        case .japaneseGarden:
            // Water drops and wind chimes
            return ProceduralAmbientConfig(sounds: ["Pop", "Tink", "Glass"], interval: 7.0, volumeScale: 0.15)
        case .minecraftOverworld:
            // Minecraft-style ambient pings
            return ProceduralAmbientConfig(sounds: ["Tink", "Pop", "Glass"], interval: 8.0, volumeScale: 0.2)
        }
    }
}
