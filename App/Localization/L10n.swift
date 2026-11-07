import Foundation
import SwiftUI

/// The player's language choice. `.system` follows the device: German if the first preferred language is German,
/// otherwise English.
enum LanguageChoice: String, CaseIterable, Identifiable, Sendable {
    case system, en, de
    var id: String { rawValue }

    var resolved: String {
        switch self {
        case .en: "en"
        case .de: "de"
        case .system:
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("de") ? "de" : "en"
        }
    }
}

/// Localised text for one language. Every player-facing string goes through this type, so the manual language switch
/// applies to labels, VoiceOver text and number formats alike.
struct L10n: Sendable {
    let language: String
    let locale: Locale
    private let table: [String: String]
    private let fallback: [String: String]

    static let english = L10n(language: "en")

    init(language: String, bundle: Bundle = .main) {
        self.language = language
        self.locale = Locale(identifier: language == "de" ? "de_DE" : "en_US")
        self.table = Self.loadTable(language, bundle: bundle)
        self.fallback = language == "en" ? [:] : Self.loadTable("en", bundle: bundle)
    }

    static func loadTable(_ language: String, bundle: Bundle) -> [String: String] {
        guard let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return [:]
        }
        return plist
    }

    var keys: Set<String> { Set(table.keys) }

    func has(_ key: String) -> Bool { table[key] != nil }

    /// Looks up `key` and formats it with `args` in this language's locale.
    func callAsFunction(_ key: String, _ args: CVarArg...) -> String {
        format(key, args)
    }

    func format(_ key: String, _ args: [CVarArg]) -> String {
        let template = table[key] ?? fallback[key] ?? key
        if args.isEmpty { return template.replacingOccurrences(of: "%%", with: "%") }
        return String(format: template, locale: locale, arguments: args)
    }

    /// English and German share the one/other plural rule.
    func plural(_ key: String, count: Int, _ args: CVarArg...) -> String {
        format(count == 1 ? "\(key)_one" : "\(key)_other", args)
    }
}

private struct L10nKey: EnvironmentKey {
    static let defaultValue = L10n.english
}

extension EnvironmentValues {
    var l10n: L10n {
        get { self[L10nKey.self] }
        set { self[L10nKey.self] = newValue }
    }
}
