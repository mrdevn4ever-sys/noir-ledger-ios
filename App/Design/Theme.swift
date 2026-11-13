import SwiftUI

/// The shared NOIR LEDGER colour tokens. Names and values are identical to `shared-assets/tokens/tokens.json` (the
/// cross-platform token map used by Android too); `scripts/shared_assets.py check` fails the build if they diverge.
enum SharedTokens {
    // BEGIN SHARED TOKENS
    static let ground = Color(hex: 0x0F0D0B)
    static let surface1 = Color(hex: 0x17140F)
    static let surface2 = Color(hex: 0x201B15)
    static let surface3 = Color(hex: 0x2A241C)
    static let hairline = Color(hex: 0x3A3227)
    static let ink = Color(hex: 0xE9DFC9)
    static let inkSoft = Color(hex: 0xB9AC93)
    static let inkFaint = Color(hex: 0x8A7F6C)
    static let amber = Color(hex: 0xE0A43A)
    static let amberDim = Color(hex: 0x6B4E1C)
    static let gold = Color(hex: 0xC8A55A)
    static let teal = Color(hex: 0x8FA6A0)
    static let red = Color(hex: 0xE0483C)
    static let redDim = Color(hex: 0x5A1E19)
    static let paper = Color(hex: 0xE6D8B8)
    static let paperInk = Color(hex: 0x2A2117)
    static let leather = Color(hex: 0x3C2A1D)
    static let leatherDark = Color(hex: 0x2A1D14)
    static let brass = Color(hex: 0xD19E4A)
    static let brassDark = Color(hex: 0x8C6630)
    static let onAmber = Color(hex: 0x1C1307)
    static let night = Color(hex: 0x07060A)
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

extension Font {
    /// Display moments only (wordmark, chapter and story titles): Apple's New York serif, still Dynamic Type aware.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, design: .serif, weight: .semibold) }
}
