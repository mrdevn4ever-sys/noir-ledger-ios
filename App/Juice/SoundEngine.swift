import AVFoundation
import Foundation

/// Short effects, the rain bed and the music loop. Audio files live in `App/Resources/Audio`; a file that is not in
/// the bundle is simply silent, so the set can be replaced or extended without code changes.
@MainActor
final class SoundEngine {
    typealias Effect = Feedback

    var effectsEnabled = true {
        didSet { if !effectsEnabled { stopBeds(music: false) } else { resumeBeds() } }
    }

    var musicEnabled = true {
        didSet { if !musicEnabled { stopBeds(music: true) } else { resumeBeds() } }
    }

    private var pools: [Effect: [AVAudioPlayer]] = [:]
    private var next: [Effect: Int] = [:]
    private var lastPlayed: [Effect: TimeInterval] = [:]
    private var music: AVAudioPlayer?
    private var ambience: AVAudioPlayer?
    private var mood = SoundMood(music: "music_main", ambience: "amb_cellar")
    private var active = false

    private static let extensions = ["m4a", "caf", "wav", "mp3"]
    static let musicVolume: Float = 0.32
    static let ambienceVolume: Float = 0.18

    private static func url(_ name: String) -> URL? {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }

    private static func volume(_ effect: Effect) -> Float {
        switch effect {
        case .tap, .benchWeed, .benchCrystal, .benchPills, .benchCoke, .uiOpen, .uiClose: 0.35
        case .coins, .crateDrop, .liftMove, .liftDing: 0.3
        case .vanDepart, .vanArrive, .scooterHorn: 0.4
        case .buy, .upgrade, .reject, .decision, .ink, .orderNew, .attentionUp, .attentionDown: 0.6
        default: 0.85
        }
    }

    /// Minimum seconds between two plays of the same effect, so frequent ones never turn into a buzz.
    private static func spacing(_ effect: Effect) -> TimeInterval {
        switch effect {
        case .coins, .liftMove, .vanDepart, .vanArrive: 1.2
        case .shelfFull, .siren: 4
        default: 0.05
        }
    }

    /// Loads the files and starts the beds. The game never interrupts the player's own music.
    func start(mood: SoundMood) {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in Effect.allCases {
            guard let url = Self.url("sfx_" + effect.rawValue) else { continue }
            let voices = [.tap, .buy, .upgrade, .benchWeed, .benchCrystal, .benchPills, .benchCoke].contains(effect) ? 4 : 2
            pools[effect] = (0..<voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
        self.mood = mood
        music = Self.loop(mood.music, volume: Self.musicVolume)
        ambience = Self.loop(mood.ambience, volume: Self.ambienceVolume)
        active = true
        resumeBeds()
    }

    /// Crossfades to another piece of music or ambience when the chapter or the deepest floor changes.
    func setMood(_ new: SoundMood) {
        guard new != mood else { return }
        if new.music != mood.music {
            music = crossfade(from: music, to: new.music, volume: Self.musicVolume, enabled: musicEnabled)
        }
        if new.ambience != mood.ambience {
            ambience = crossfade(from: ambience, to: new.ambience, volume: Self.ambienceVolume, enabled: effectsEnabled)
        }
        mood = new
    }

    private func crossfade(from old: AVAudioPlayer?, to name: String, volume: Float, enabled: Bool) -> AVAudioPlayer? {
        if let old {
            old.setVolume(0, fadeDuration: 1.5)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                old.stop()
            }
        }
        guard let player = Self.loop(name, volume: 0) else { return nil }
        if active && enabled {
            player.play()
            player.setVolume(volume, fadeDuration: 1.5)
        } else {
            player.volume = volume
        }
        return player
    }

    private static func loop(_ name: String, volume: Float) -> AVAudioPlayer? {
        guard let url = url(name), let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.numberOfLoops = -1
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    func play(_ effect: Effect) {
        guard active, effectsEnabled, let pool = pools[effect], !pool.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlayed[effect], now - last < Self.spacing(effect) { return }
        lastPlayed[effect] = now
        let index = (next[effect] ?? 0) % pool.count
        next[effect] = index + 1
        let player = pool[index]
        player.volume = Self.volume(effect)
        player.currentTime = 0
        player.play()
    }

    /// Called when the app leaves the foreground.
    func pause() {
        active = false
        music?.pause()
        ambience?.pause()
    }

    /// Called when the app returns to the foreground.
    func resume() {
        active = true
        resumeBeds()
    }

    private func resumeBeds() {
        guard active else { return }
        if musicEnabled, music?.isPlaying == false { music?.play() }
        if effectsEnabled, ambience?.isPlaying == false { ambience?.play() }
    }

    private func stopBeds(music stopMusic: Bool) {
        if stopMusic { music?.pause() } else { ambience?.pause() }
    }
}
