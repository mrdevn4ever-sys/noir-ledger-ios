import Foundation
import Observation

enum MotionChoice: String, CaseIterable, Identifiable, Sendable {
    case system, reduced, full
    var id: String { rawValue }
}

/// Player preferences, stored in UserDefaults (separate from the game save, so a campaign reset keeps them).
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var language: LanguageChoice {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            l10n = L10n(language: language.resolved)
        }
    }

    var motion: MotionChoice {
        didSet { defaults.set(motion.rawValue, forKey: Keys.motion) }
    }

    var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Keys.haptics) }
    }

    private enum Keys {
        static let language = "settings.language"
        static let motion = "settings.motion"
        static let haptics = "settings.haptics"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let lang = LanguageChoice(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        language = lang
        l10n = L10n(language: lang.resolved)
        motion = MotionChoice(rawValue: defaults.string(forKey: Keys.motion) ?? "") ?? .system
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    }

    func resetToDefaults() {
        language = .system
        motion = .system
        haptics = true
    }

    /// The resolved text table for the current choice (reloaded only when the language changes).
    private(set) var l10n: L10n

    func reduceMotion(system: Bool) -> Bool {
        switch motion {
        case .system: system
        case .reduced: true
        case .full: false
        }
    }
}
