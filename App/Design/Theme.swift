import SwiftUI

/// NOIR LEDGER design tokens. One palette, three section materials (books, workshop, night city) and a single
/// value accent. Red is reserved for Heat and danger. Every text pairing below meets 4.5:1 or better.
enum Noir {
    // MARK: Ground and neutrals (warm anthracite)
    static let ground = Color(hex: 0x0F0E0D)
    static let surface = Color(hex: 0x1B1A18)
    static let raised = Color(hex: 0x262420)
    static let hairline = Color(hex: 0x3D3933)

    // MARK: Ink on dark
    static let ink = Color(hex: 0xEDE6D8)
    static let inkSoft = Color(hex: 0xB9B0A2)
    static let inkMuted = Color(hex: 0x948B7E)

    // MARK: Value (dirty amber / old gold)
    static let amber = Color(hex: 0xD6A852)
    static let amberFill = Color(hex: 0xB98A33)
    static let onAmber = Color(hex: 0x17120A)

    // MARK: Danger (Heat only)
    static let danger = Color(hex: 0xEC5B49)
    static let dangerFill = Color(hex: 0x8E2A22)
    static let onDanger = Color(hex: 0xF6ECE0)

    // MARK: Accounts
    static let dirtyInk = Color(hex: 0xCDBFA6)
    static let cleanInk = amber
    static let influenceInk = Color(hex: 0xA9BCCB)

    // MARK: Section materials
    /// Books: aged ledger paper with dark ink.
    static let paper = Color(hex: 0xE4D9C2)
    static let paperEdge = Color(hex: 0xB9A988)
    static let paperInk = Color(hex: 0x2A2219)
    static let paperInkSoft = Color(hex: 0x54483A)
    static let paperRed = Color(hex: 0x9A2A1F)
    static let paperGold = Color(hex: 0x7A5A17)
    /// Workshop (operations): worn leather.
    static let leather = Color(hex: 0x2B2019)
    static let leatherEdge = Color(hex: 0x5A4532)
    /// Night city: wet slate under sodium light.
    static let night = Color(hex: 0x161B22)
    static let nightEdge = Color(hex: 0x34404D)
    static let river = Color(hex: 0x223041)

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
