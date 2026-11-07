import NoirCore
import SwiftUI

// MARK: - Panel

/// An opaque section surface (books paper, workshop leather, night slate or anthracite) with a fine edge.
/// Panels are never nested; inside a panel, rows are separated by `PanelDivider`.
struct Panel<Content: View>: View {
    let surface: NoirSurface
    @ViewBuilder var content: Content

    init(_ surface: NoirSurface = .anthracite, @ViewBuilder content: () -> Content) {
        self.surface = surface
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Noir.s3) { content }
            .padding(Noir.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface.fill, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(surface.edge, lineWidth: 1))
            .foregroundStyle(surface.ink)
            .environment(\.noirSurface, surface)
    }
}

struct PanelDivider: View {
    @Environment(\.noirSurface) private var surface
    var body: some View {
        Rectangle().fill(surface.edge.opacity(0.7)).frame(height: 1).accessibilityHidden(true)
    }
}

/// Section heading above a group of panels. Headings carry their own weight; no eyebrow labels.
struct SectionHeading: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Noir.ink)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(verbatim: detail).font(.subheadline).foregroundStyle(Noir.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Noir.s3)
    }
}

// MARK: - Buttons

enum NoirButtonKind { case primary, secondary, danger, quiet }

/// The single button vocabulary of the game: 44 pt minimum, a short responsive press (scale 0.97 or, with reduced
/// motion, a dim), and a clearly muted disabled state.
struct NoirButtonStyle: ButtonStyle {
    var kind: NoirButtonKind = .secondary
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.noirReduceMotion) private var reduceMotion
    @Environment(\.noirSurface) private var surface

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Noir.s4)
            .padding(.vertical, Noir.s2 + 2)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Noir.minTarget)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
            .overlay {
                if kind == .secondary || kind == .quiet {
                    RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (pressed && reduceMotion ? 0.75 : 1) : 0.42)
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: pressed ? 0.08 : 0.16), value: pressed)
            .contentShape(RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
    }

    private var foreground: Color {
        switch kind {
        case .primary: Noir.onAmber
        case .danger: Noir.onDanger
        case .secondary, .quiet: surface == .paper ? Noir.paperInk : Noir.ink
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Noir.amberFill
        case .danger: Noir.dangerFill
        case .secondary: surface == .paper ? Noir.paper.opacity(0.0) : Noir.raised
        case .quiet: .clear
        }
    }

    private var border: Color { surface == .paper ? Noir.paperEdge : Noir.hairline }
}

extension View {
    func noirButton(_ kind: NoirButtonKind = .secondary, fullWidth: Bool = true) -> some View {
        buttonStyle(NoirButtonStyle(kind: kind, fullWidth: fullWidth))
    }
}

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Effective reduced-motion preference (system setting combined with the in-game Motion choice).
    var noirReduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

// MARK: - Meters

/// A labelled progress meter. The value is always also given as text, never by fill alone.
struct Meter: View {
    let fraction: Double
    var tint: Color = Noir.amber
    var height: CGFloat = 6
    @Environment(\.noirSurface) private var surface

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(surface == .paper ? Noir.paperEdge.opacity(0.45) : Noir.hairline)
                Capsule().fill(tint).frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Heat as a ruled scale with the warning (50) and investigation (75) marks, plus status text and symbol.
struct HeatGauge: View {
    let heat: Double
    let trend: Double
    let status: HeatStatus
    var compact = false
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: Noir.s1) {
            HStack(spacing: Noir.s1) {
                Image(systemName: status.symbol).imageScale(.small).accessibilityHidden(true)
                Text(verbatim: t(status.key)).font(.caption.weight(.semibold))
                Spacer(minLength: Noir.s1)
                Text(verbatim: t.decimal(heat, digits: 0)).font(.caption.weight(.bold)).monospacedDigit()
                if !compact {
                    Image(systemName: trend > heat + 0.5 ? "arrow.up.right" : (trend < heat - 0.5 ? "arrow.down.right" : "arrow.right"))
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(status.isDanger ? Noir.danger : Noir.ink)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Noir.hairline)
                    Capsule().fill(status.isDanger ? Noir.danger : Noir.amber)
                        .frame(width: max(4, min(1, heat / 100) * w))
                    Rectangle().fill(Noir.ink.opacity(0.7)).frame(width: 1.5).offset(x: w * 0.5)
                    Rectangle().fill(Noir.danger).frame(width: 1.5).offset(x: w * 0.75)
                    Circle().fill(Noir.ink).frame(width: 5, height: 5).offset(x: max(0, min(1, trend / 100) * w - 2.5))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: t("cd_heat_gauge", t.decimal(heat, digits: 0), t.decimal(trend, digits: 0), t(status.key))))
        .accessibilityIdentifier("heat.gauge")
    }
}

enum HeatStatus: Equatable {
    case calm, watched, investigation, layLow

    static func of(_ s: GameState) -> HeatStatus {
        if s.investigation != nil { return .investigation }
        if s.layLow { return .layLow }
        if s.heat >= Content.heatWarning { return .watched }
        return .calm
    }

    var key: String {
        switch self {
        case .calm: "heat_status_calm"
        case .watched: "heat_status_watched"
        case .investigation: "heat_status_investigation"
        case .layLow: "heat_status_laylow"
        }
    }

    var symbol: String {
        switch self {
        case .calm: "moon.zzz"
        case .watched: "eye"
        case .investigation: "exclamationmark.triangle.fill"
        case .layLow: "figure.walk.motion"
        }
    }

    var isDanger: Bool { self == .investigation || self == .watched }
}

// MARK: - Values

enum Account: CaseIterable {
    case dirty, clean, influence

    var key: String {
        switch self {
        case .dirty: "acc_dirty"
        case .clean: "acc_clean"
        case .influence: "acc_influence"
        }
    }

    var symbol: String {
        switch self {
        case .dirty: "banknote"
        case .clean: "building.columns"
        case .influence: "person.2"
        }
    }

    var ink: Color {
        switch self {
        case .dirty: Noir.dirtyInk
        case .clean: Noir.cleanInk
        case .influence: Noir.influenceInk
        }
    }
}

/// A cost line: each currency with its own symbol, so affordability never depends on colour alone.
struct CostLine: View {
    let cost: Cost
    var affordable = true
    @Environment(\.l10n) private var t
    @Environment(\.noirSurface) private var surface

    var body: some View {
        HStack(spacing: Noir.s1) {
            Image(systemName: affordable ? "tag" : "xmark.circle").imageScale(.small).accessibilityHidden(true)
            Text(verbatim: t.cost(cost)).monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(affordable ? surface.inkSoft : surface.danger)
        .accessibilityElement(children: .combine)
    }
}

/// A row with a label on the left and a value on the right (wraps under at large text sizes).
struct ValueRow: View {
    let label: String
    let value: String
    var symbol: String?
    var valueColor: Color?
    @Environment(\.noirSurface) private var surface
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: Noir.s2))
        layout {
            HStack(spacing: Noir.s2) {
                if let symbol { Image(systemName: symbol).foregroundStyle(surface.inkSoft).accessibilityHidden(true) }
                Text(verbatim: label).foregroundStyle(surface.inkSoft)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: Noir.s2) }
            Text(verbatim: value).fontWeight(.semibold).monospacedDigit().foregroundStyle(valueColor ?? surface.ink)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// Lock or status chip with a symbol and text (never colour alone).
struct StatusChip: View {
    let text: String
    let symbol: String
    var danger = false
    @Environment(\.noirSurface) private var surface

    var body: some View {
        Label { Text(verbatim: text) } icon: { Image(systemName: symbol) }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(danger ? surface.danger : surface.inkSoft)
            .labelStyle(.titleAndIcon)
    }
}
