import CoreText
import SwiftUI
import UIKit

/// The shared NOIR LEDGER colour tokens. Names and values are identical to `shared-assets/tokens/tokens.json` (the
/// cross-platform token map used by Android too); `scripts/shared_assets.py check` fails the build if they diverge.
enum SharedTokens {
    // BEGIN SHARED TOKENS
    static let ground = Color(hex: 0x141A33)
    static let surface1 = Color(hex: 0x1E2648)
    static let surface2 = Color(hex: 0x283259)
    static let surface3 = Color(hex: 0x333F6B)
    static let hairline = Color(hex: 0x3E4A7A)
    static let ink = Color(hex: 0xF4F1E8)
    static let inkSoft = Color(hex: 0xB9C1E0)
    static let inkFaint = Color(hex: 0x8590B8)
    static let amber = Color(hex: 0xFFC83D)
    static let amberDim = Color(hex: 0x6B5420)
    static let gold = Color(hex: 0xF2B544)
    static let teal = Color(hex: 0x6FC7C9)
    static let red = Color(hex: 0xE5484D)
    static let redDim = Color(hex: 0x6A2026)
    static let paper = Color(hex: 0xF3E9D2)
    static let paperInk = Color(hex: 0x2B2440)
    static let leather = Color(hex: 0x2C3768)
    static let leatherDark = Color(hex: 0x222B55)
    static let brass = Color(hex: 0xF2A93B)
    static let brassDark = Color(hex: 0x9A6A20)
    static let onAmber = Color(hex: 0x2A1E00)
    static let night = Color(hex: 0x0B1026)
    // END SHARED TOKENS
}

/// Semantic roles used by the iOS views, each mapped onto the shared tokens (no colour exists outside the token map
/// except opacity variants). Red is reserved for Heat and danger. Text pairings meet 4.5:1.
enum Noir {
    private typealias T = SharedTokens

    // MARK: Ground and neutrals
    static let ground = T.ground
    static let surface = T.surface1
    static let raised = T.surface2
    static let track = T.surface3
    static let hairline = T.hairline

    // MARK: Ink on dark
    static let ink = T.ink
    static let inkSoft = T.inkSoft
    static let inkMuted = T.inkFaint

    // MARK: Value and action
    static let amber = T.amber
    static let amberFill = T.amber
    static let amberContainer = T.amberDim
    static let onAmber = T.onAmber

    // MARK: Danger (Heat only)
    static let danger = T.red
    static let dangerFill = T.redDim
    static let onDanger = T.ink

    // MARK: Accounts (token meanings: amber = dirty cash, gold = clean cash, teal = influence)
    static let dirtyInk = T.amber
    static let cleanInk = T.gold
    static let influenceInk = T.teal

    // MARK: Section materials
    /// Books: aged ledger paper with dark ink.
    static let paper = T.paper
    static let paperEdge = T.brassDark
    static let paperInk = T.paperInk
    static let paperInkSoft = T.leather
    static let paperRed = T.redDim
    /// Foil on paper: marks, meters and toggles only (text on paper uses paper ink).
    static let paperGold = T.brassDark
    /// Workshop (operations): ledger leather.
    static let leather = T.leatherDark
    static let leatherEdge = T.brassDark.opacity(0.55)
    /// Night city: anthracite under a cold teal edge.
    static let night = T.surface1
    static let nightEdge = T.teal.opacity(0.35)
    static let river = T.teal.opacity(0.22)
    static let silhouette = T.night
    static let brass = T.brass
    static let brassDark = T.brassDark

    // MARK: Spacing (4 pt rhythm)
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32

    static let corner: CGFloat = 14
    static let controlCorner: CGFloat = 10
    static let minTarget: CGFloat = 44
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// The three section surfaces plus the plain anthracite surface.
enum NoirSurface: Sendable {
    case anthracite, paper, leather, night

    var fill: Color {
        switch self {
        case .anthracite: Noir.surface
        case .paper: Noir.paper
        case .leather: Noir.leather
        case .night: Noir.night
        }
    }

    var edge: Color {
        switch self {
        case .anthracite: Noir.hairline
        case .paper: Noir.paperEdge
        case .leather: Noir.leatherEdge
        case .night: Noir.nightEdge
        }
    }

    var ink: Color { self == .paper ? Noir.paperInk : Noir.ink }
    var inkSoft: Color { self == .paper ? Noir.paperInkSoft : Noir.inkSoft }
    var value: Color { self == .paper ? Noir.paperGold : Noir.amber }
    var danger: Color { self == .paper ? Noir.paperRed : Noir.danger }
}

private struct SurfaceKey: EnvironmentKey {
    static let defaultValue: NoirSurface = .anthracite
}

extension EnvironmentValues {
    /// The material of the nearest panel, so nested text picks legible ink automatically.
    var noirSurface: NoirSurface {
        get { self[SurfaceKey.self] }
        set { self[SurfaceKey.self] = newValue }
    }
}

/// The game's two typefaces (SIL Open Font License, App/Resources/Fonts): Fredoka, a rounded variable font, for all
/// text and numbers, and Lilita One for titles. Both follow Dynamic Type; a missing font falls back to the system.
enum ToonFont {
    /// PostScript name of the variable font's default instance; the weight is set on the `wght` axis.
    static let text = "Fredoka-Light"
    static let display = "LilitaOne"

    static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }

    static func uiStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }

    static func axis(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .black, .heavy: 700
        case .bold: 650
        case .semibold: 580
        case .medium: 500
        case .light, .thin, .ultraLight: 350
        default: 430
        }
    }

    static func uiFont(size: CGFloat, weight: Font.Weight, style: Font.TextStyle) -> UIFont {
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let wght = 0x7767_6874 // 'wght'
        let descriptor = UIFontDescriptor(fontAttributes: [.name: text, variation: [wght: axis(weight)]])
        return UIFontMetrics(forTextStyle: uiStyle(style)).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }
}

extension Font {
    /// Rounded game text at a point size, scaled with Dynamic Type like `relativeTo`.
    static func toon(_ size: CGFloat, _ weight: Font.Weight = .medium, relativeTo style: Font.TextStyle = .body) -> Font {
        Font(ToonFont.uiFont(size: size, weight: weight, style: style))
    }

    /// Rounded game text for a text style.
    static func toon(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
        let w = weight ?? (style == .headline ? .semibold : .regular)
        return toon(ToonFont.pointSize(style), w, relativeTo: style)
    }

    /// Titles: Lilita One, Dynamic Type aware.
    static func display(_ style: Font.TextStyle) -> Font {
        .custom(ToonFont.display, size: ToonFont.pointSize(style) + 2, relativeTo: style)
    }
}
