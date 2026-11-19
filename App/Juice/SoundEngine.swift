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
    nonisolated static let musicVolume: Float = 0.32
    nonisolated static let ambienceVolume: Float = 0.18

    nonisolated private static func url(_ name: String) -> URL? {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }

    private static func volume(_ effect: Effect) -> Float {
        switch effect {
        case .tap, .benchWeed, .benchCrystal, .benchPills, .benchCoke, .uiOpen, .uiClose, .toggle: 0.35
        case .liftDoor, .whistle: 0.4
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

    /// Loads the files off the main thread and starts the beds. The game never interrupts the player's own music.
    func start(mood: SoundMood) {
        self.mood = mood
        active = true
        Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) { () -> Loaded in
                try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true)
                var pools: [Effect: [AVAudioPlayer]] = [:]
                for effect in Effect.allCases {
                    guard let url = SoundEngine.url("sfx_" + effect.rawValue) else { continue }
                    let voices = [.tap, .buy, .upgrade, .benchWeed, .benchCrystal, .benchPills, .benchCoke].contains(effect) ? 4 : 2
                    pools[effect] = (0..<voices).compactMap { _ in
                        let player = try? AVAudioPlayer(contentsOf: url)
                        player?.prepareToPlay()
                        return player
                    }
                }
                return Loaded(pools: pools,
                              music: SoundEngine.loop(mood.music, volume: SoundEngine.musicVolume),
                              ambience: SoundEngine.loop(mood.ambience, volume: SoundEngine.ambienceVolume))
            }.value
            guard let self else { return }
            self.pools = loaded.pools
            // A mood that changed while loading wins over the first one.
            if self.music == nil, self.mood.music == mood.music { self.music = loaded.music }
            if self.ambience == nil, self.mood.ambience == mood.ambience { self.ambience = loaded.ambience }
            self.resumeBeds()
        }
    }

    /// Players made off the main thread and handed over once.
    private struct Loaded: @unchecked Sendable {
        let pools: [Effect: [AVAudioPlayer]]
        let music: AVAudioPlayer?
        let ambience: AVAudioPlayer?
    }

    private struct Bed: @unchecked Sendable { let player: AVAudioPlayer? }

    /// Crossfades to another piece of music or ambience when the chapter or the deepest floor changes.
    func setMood(_ new: SoundMood) {
        guard new != mood else { return }
        let old = mood
        mood = new
        if new.music != old.music { swapBed(music: true, to: new.music) }
        if new.ambience != old.ambience { swapBed(music: false, to: new.ambience) }
    }

    private var bedGeneration = (music: 0, ambience: 0)

    private func swapBed(music isMusic: Bool, to name: String) {
        if let old = isMusic ? music : ambience {
            old.setVolume(0, fadeDuration: 1.5)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                old.stop()
            }
        }
        if isMusic { music = nil; bedGeneration.music += 1 } else { ambience = nil; bedGeneration.ambience += 1 }
        let generation = isMusic ? bedGeneration.music : bedGeneration.ambience
        let volume = isMusic ? Self.musicVolume : Self.ambienceVolume
        Task { [weak self] in
            let bed = await Task.detached(priority: .utility) { Bed(player: SoundEngine.loop(name, volume: 0)) }.value
            guard let self, let player = bed.player,
                  generation == (isMusic ? self.bedGeneration.music : self.bedGeneration.ambience) else { return }
            if isMusic { self.music = player } else { self.ambience = player }
            if self.active && (isMusic ? self.musicEnabled : self.effectsEnabled) {
                player.play()
                player.setVolume(volume, fadeDuration: 1.5)
            } else {
                player.volume = volume
            }
        }
    }

    nonisolated private static func loop(_ name: String, volume: Float) -> AVAudioPlayer? {
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
