import AVFoundation
import Foundation

/// Short effects, the rain bed and the music loop. Audio files live in `App/Resources/Audio`; a file that is not in
/// the bundle is simply silent, so the set can be replaced or extended without code changes.
@MainActor
final class SoundEngine {
    enum Effect: String, CaseIterable {
        case tap, buy, milestone, reject, claim, chapter, raid, alarm, decision, prestige, purchase, boost

        var file: String { "sfx_" + rawValue }

        var volume: Float {
            switch self {
            case .tap: 0.35
            case .buy, .reject, .decision: 0.6
            default: 0.85
            }
        }
    }

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
    private var rain: AVAudioPlayer?
    private var active = false

    private static let extensions = ["m4a", "caf", "wav", "mp3"]

    private static func url(_ name: String) -> URL? {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }

    /// Loads the files and starts the beds. The game never interrupts the player's own music.
    func start() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in Effect.allCases {
            guard let url = Self.url(effect.file) else { continue }
            let voices = effect == .tap || effect == .buy ? 4 : 2
            pools[effect] = (0..<voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
        music = Self.loop("music_main", volume: 0.32)
        rain = Self.loop("amb_rain", volume: 0.22)
        active = true
        resumeBeds()
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
        // Bursts of taps are thinned so they never turn into a buzz.
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlayed[effect], now - last < 0.05 { return }
        lastPlayed[effect] = now
        let index = (next[effect] ?? 0) % pool.count
        next[effect] = index + 1
        let player = pool[index]
        player.volume = effect.volume
        player.currentTime = 0
        player.play()
    }

    func play(_ feedback: Feedback) {
        switch feedback {
        case .tap: play(.tap)
        case .buy: play(.buy)
        case .milestone: play(.milestone)
        case .reject: play(.reject)
        case .claim: play(.claim)
        case .chapter: play(.chapter)
        case .raid: play(.raid)
        case .alarm: play(.alarm)
        case .decision: play(.decision)
        case .prestige: play(.prestige)
        case .purchase: play(.purchase)
        case .boost: play(.boost)
        }
    }

    /// Called when the app leaves the foreground.
    func pause() {
        active = false
        music?.pause()
        rain?.pause()
    }

    /// Called when the app returns to the foreground.
    func resume() {
        active = true
        resumeBeds()
    }

    private func resumeBeds() {
        guard active else { return }
        if musicEnabled, music?.isPlaying == false { music?.play() }
        if effectsEnabled, rain?.isPlaying == false { rain?.play() }
    }

    private func stopBeds(music stopMusic: Bool) {
        if stopMusic { music?.pause() } else { rain?.pause() }
    }
}
