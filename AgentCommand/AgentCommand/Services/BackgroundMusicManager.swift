import Foundation
import AVFoundation

/// Intensity level for background music
enum MusicIntensity: String {
    case calm
    case active
}

/// Manages theme-specific background music using procedural audio generation
@MainActor
class BackgroundMusicManager: ObservableObject {
    @Published var isPlaying: Bool = false

    @Published var musicVolume: Float {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: "backgroundMusicVolume")
            updateEngineVolume()
        }
    }

    @Published var isMusicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "backgroundMusicEnabled")
            if isMusicEnabled {
                if let theme = currentTheme {
                    playThemeMusic(theme)
                }
            } else {
                stopMusic()
            }
        }
    }

    @Published var intensity: MusicIntensity = .calm

    private var currentTheme: SceneTheme?
    private var musicTimer: Timer?
    private var fadeTimer: Timer?
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var currentVolume: Float = 0.0
    private var targetVolume: Float = 0.3

    /// Reference to SoundManager to respect global mute state
    weak var soundManager: SoundManager?

    init() {
        let savedVolume = UserDefaults.standard.float(forKey: "backgroundMusicVolume")
        self.musicVolume = savedVolume > 0 ? savedVolume : 0.3
        if UserDefaults.standard.object(forKey: "backgroundMusicEnabled") == nil {
            self.isMusicEnabled = false // Default off to not overwhelm users
        } else {
            self.isMusicEnabled = UserDefaults.standard.bool(forKey: "backgroundMusicEnabled")
        }
    }

    // MARK: - Public API

    func playThemeMusic(_ theme: SceneTheme) {
        currentTheme = theme
        guard isMusicEnabled else { return }
        if let sm = soundManager, sm.isMuted { return }

        stopMusicEngine()
        startProceduralMusic(for: theme)
        isPlaying = true
    }

    func stopMusic() {
        stopMusicEngine()
        isPlaying = false
    }

    func setIntensity(_ newIntensity: MusicIntensity) {
        intensity = newIntensity
        // Intensity affects tempo and volume in the procedural generator
    }

    func fadeOut(duration: TimeInterval = 1.0) {
        guard isPlaying else { return }
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = currentVolume / Float(steps)

        var currentStep = 0
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                currentStep += 1
                self.currentVolume = max(0, self.currentVolume - volumeStep)
                self.updateEngineVolume()
                if currentStep >= steps {
                    timer.invalidate()
                    self.stopMusic()
                }
            }
        }
    }

    func fadeIn(duration: TimeInterval = 1.0) {
        guard isMusicEnabled, let theme = currentTheme else { return }
        if let sm = soundManager, sm.isMuted { return }

        if !isPlaying {
            currentVolume = 0
            startProceduralMusic(for: theme)
            isPlaying = true
        }

        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = musicVolume / Float(steps)

        var currentStep = 0
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                currentStep += 1
                self.currentVolume = min(self.musicVolume, self.currentVolume + volumeStep)
                self.updateEngineVolume()
                if currentStep >= steps {
                    timer.invalidate()
                }
            }
        }
    }

    /// Called when global mute state changes
    func onMuteChanged(_ muted: Bool) {
        if muted {
            stopMusic()
        } else if isMusicEnabled, let theme = currentTheme {
            playThemeMusic(theme)
        }
    }

    // MARK: - Procedural Music Engine

    private struct ThemeMusicConfig {
        let baseFrequency: Float
        let harmonics: [Float]        // frequency multipliers
        let noteIntervalCalm: TimeInterval
        let noteIntervalActive: TimeInterval
        let noteDuration: TimeInterval
        let volumeScale: Float
    }

    private func configFor(_ theme: SceneTheme) -> ThemeMusicConfig {
        switch theme {
        case .commandCenter:
            return ThemeMusicConfig(
                baseFrequency: 110,
                harmonics: [1.0, 1.5, 2.0, 3.0],
                noteIntervalCalm: 4.0,
                noteIntervalActive: 2.5,
                noteDuration: 2.0,
                volumeScale: 0.3
            )
        case .floatingIslands:
            return ThemeMusicConfig(
                baseFrequency: 261.63,
                harmonics: [1.0, 1.25, 1.5, 2.0],
                noteIntervalCalm: 3.5,
                noteIntervalActive: 2.0,
                noteDuration: 2.5,
                volumeScale: 0.25
            )
        case .dungeon:
            return ThemeMusicConfig(
                baseFrequency: 82.41,
                harmonics: [1.0, 1.189, 1.498, 2.0],
                noteIntervalCalm: 5.0,
                noteIntervalActive: 3.0,
                noteDuration: 3.0,
                volumeScale: 0.2
            )
        case .spaceStation:
            return ThemeMusicConfig(
                baseFrequency: 146.83,
                harmonics: [1.0, 1.335, 1.782, 2.0],
                noteIntervalCalm: 4.0,
                noteIntervalActive: 2.5,
                noteDuration: 2.5,
                volumeScale: 0.25
            )
        case .cyberpunkCity:
            return ThemeMusicConfig(
                baseFrequency: 130.81,
                harmonics: [1.0, 1.26, 1.587, 2.0],
                noteIntervalCalm: 3.0,
                noteIntervalActive: 1.5,
                noteDuration: 1.5,
                volumeScale: 0.3
            )
        case .medievalCastle:
            return ThemeMusicConfig(
                baseFrequency: 196.0,
                harmonics: [1.0, 1.25, 1.5, 2.0],
                noteIntervalCalm: 4.0,
                noteIntervalActive: 2.5,
                noteDuration: 2.5,
                volumeScale: 0.2
            )
        case .underwaterLab:
            return ThemeMusicConfig(
                baseFrequency: 174.61,
                harmonics: [1.0, 1.122, 1.335, 2.0],
                noteIntervalCalm: 4.5,
                noteIntervalActive: 2.5,
                noteDuration: 3.0,
                volumeScale: 0.2
            )
        case .japaneseGarden:
            // Pentatonic scale ratios
            return ThemeMusicConfig(
                baseFrequency: 293.66,
                harmonics: [1.0, 1.122, 1.335, 1.498, 1.782],
                noteIntervalCalm: 5.0,
                noteIntervalActive: 3.0,
                noteDuration: 3.0,
                volumeScale: 0.15
            )
        case .minecraftOverworld:
            return ThemeMusicConfig(
                baseFrequency: 220.0,
                harmonics: [1.0, 1.25, 1.5, 2.0],
                noteIntervalCalm: 4.0,
                noteIntervalActive: 2.5,
                noteDuration: 2.0,
                volumeScale: 0.2
            )
        }
    }

    private func startProceduralMusic(for theme: SceneTheme) {
        let config = configFor(theme)
        currentVolume = musicVolume
        targetVolume = musicVolume

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let mixer = engine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: mixer, format: format)
        mixer.outputVolume = currentVolume * config.volumeScale

        do {
            try engine.start()
        } catch {
            return
        }

        audioEngine = engine
        tonePlayer = player
        player.play()

        // Schedule the first note
        scheduleNote(config: config, format: format)

        // Set up repeating timer for notes
        let interval = intensity == .calm ? config.noteIntervalCalm : config.noteIntervalActive
        musicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                self.scheduleNote(config: config, format: format)
            }
        }
    }

    private func scheduleNote(config: ThemeMusicConfig, format: AVAudioFormat) {
        guard let player = tonePlayer, let engine = audioEngine, engine.isRunning else { return }

        let sampleRate = format.sampleRate
        let duration = config.noteDuration
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }

        // Pick a random harmonic
        let harmonic = config.harmonics.randomElement() ?? 1.0
        let frequency = config.baseFrequency * harmonic

        // Add slight random pitch variation for organic feel
        let pitchVariation = Float.random(in: 0.98...1.02)
        let finalFreq = frequency * pitchVariation

        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(sampleRate)
            // Sine wave with envelope (attack-sustain-release)
            let envelope: Float
            let attackTime: Float = 0.1
            let releaseTime = Float(duration) * 0.4
            let sustainEnd = Float(duration) - releaseTime

            if t < attackTime {
                envelope = t / attackTime
            } else if t < sustainEnd {
                envelope = 1.0
            } else {
                envelope = max(0, 1.0 - (t - sustainEnd) / releaseTime)
            }

            let sample = sin(2.0 * .pi * finalFreq * t) * envelope * 0.3
            data[frame] = sample
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func stopMusicEngine() {
        musicTimer?.invalidate()
        musicTimer = nil
        fadeTimer?.invalidate()
        fadeTimer = nil

        tonePlayer?.stop()
        audioEngine?.stop()
        tonePlayer = nil
        audioEngine = nil
    }

    private func updateEngineVolume() {
        guard let engine = audioEngine else { return }
        let config = currentTheme.map { configFor($0) }
        let scale = config?.volumeScale ?? 0.3
        engine.mainMixerNode.outputVolume = currentVolume * scale
    }
}
