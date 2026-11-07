import NoirCore
import SwiftUI

// MARK: - Symbol vocabulary (SF Symbols only, one family)

enum Glyph {
    static func product(_ p: ProductId) -> String {
        switch p {
        case .glimmer: "sparkle"
        case .cinder: "cube.box"
        case .velvet: "rhombus"
        case .halo: "circle.circle"
        }
    }

    static func district(_ d: DistrictId) -> String {
        switch d {
        case .cellars: "door.left.hand.closed"
        case .docks: "shippingbox"
        case .neonMile: "music.note"
        case .foundry: "flame"
        case .crownHill: "crown"
        }
    }

    static func front(_ f: FrontId) -> String {
        switch f {
        case .laundromat: "washer"
        case .taxi: "car"
        case .nightclub: "music.mic"
        case .construction: "hammer"
        case .gallery: "photo.artframe"
        }
    }

    static func role(_ r: CrewRole) -> String {
        switch r {
        case .foreman: "wrench.and.screwdriver"
        case .courier: "bicycle"
        case .enforcer: "shield.lefthalf.filled"
        case .accountant: "doc.text.magnifyingglass"
        case .lawyer: "briefcase"
        case .fixer: "phone"
        }
    }

    static func branch(_ b: UpgradeBranch) -> String {
        switch b {
        case .logistics: "shippingbox.and.arrow.backward"
        case .production: "gearshape.2"
        case .security: "lock.shield"
        case .finance: "banknote"
        case .network: "person.3"
        }
    }
}

// MARK: - Ledger emblem

/// The house mark: a ledger bound in leather with a gold clasp, drawn in strokes.
struct LedgerEmblem: View {
    var color: Color = Noir.amber
    var lineWidth: CGFloat = 2

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let book = CGRect(x: w * 0.12, y: h * 0.16, width: w * 0.76, height: h * 0.68)
            let cover = Path(roundedRect: book, cornerRadius: w * 0.05)
            ctx.stroke(cover, with: .color(color), lineWidth: lineWidth)
            var spine = Path()
            spine.move(to: CGPoint(x: w * 0.5, y: book.minY))
            spine.addLine(to: CGPoint(x: w * 0.5, y: book.maxY))
            ctx.stroke(spine, with: .color(color), lineWidth: lineWidth)
            for i in 1...4 {
                let y = book.minY + book.height * CGFloat(i) / 5.5
                var left = Path()
                left.move(to: CGPoint(x: book.minX + w * 0.07, y: y))
                left.addLine(to: CGPoint(x: w * 0.44, y: y))
                var right = Path()
                right.move(to: CGPoint(x: w * 0.56, y: y))
                right.addLine(to: CGPoint(x: book.maxX - w * 0.07, y: y))
                ctx.stroke(left, with: .color(color.opacity(0.6)), lineWidth: lineWidth * 0.6)
                ctx.stroke(right, with: .color(color.opacity(0.6)), lineWidth: lineWidth * 0.6)
            }
            let clasp = CGRect(x: book.maxX - w * 0.02, y: h * 0.44, width: w * 0.08, height: h * 0.12)
            ctx.fill(Path(roundedRect: clasp, cornerRadius: w * 0.015), with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// The wordmark: NOIR LEDGER in the display serif, tracked wide, with the emblem.
struct Wordmark: View {
    var body: some View {
        VStack(spacing: Noir.s2) {
            LedgerEmblem().frame(width: 56, height: 44)
            Text(verbatim: "NOIR LEDGER")
                .font(.display(.title))
                .tracking(4)
                .foregroundStyle(Noir.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "NOIR LEDGER"))
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - City map (signature)

/// Varnholm drawn as the pinned map from the owner's desk: the river, five districts as pins and the route threads
/// running out from Leopold's cellar. Threads are amber; only districts under investigation or closed by a raid turn red.
struct CityMap: View {
    let state: GameState
    var onSelect: (DistrictId) -> Void
    @Environment(\.l10n) private var t

    static func position(_ d: DistrictId) -> CGPoint {
        switch d {
        case .cellars: CGPoint(x: 0.30, y: 0.62)
        case .docks: CGPoint(x: 0.16, y: 0.26)
        case .neonMile: CGPoint(x: 0.56, y: 0.40)
        case .foundry: CGPoint(x: 0.82, y: 0.70)
        case .crownHill: CGPoint(x: 0.80, y: 0.18)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Canvas { ctx, sz in drawBase(&ctx, sz) }
                ForEach(DistrictId.allCases, id: \.self) { d in
                    pin(d, size: size)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .background(Noir.night, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.nightEdge, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
    }

    private func danger(_ d: DistrictId) -> Bool {
        state.investigation?.district == d || state.district(d).suspendedUntil > state.time
    }

    private func drawBase(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        // Street grid, very faint.
        var grid = Path()
        let step: CGFloat = 22
        var x: CGFloat = 0
        while x < sz.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x + sz.height * 0.25, y: sz.height))
            x += step
        }
        var y: CGFloat = 0
        while y < sz.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: sz.width, y: y - sz.width * 0.08))
            y += step
        }
        ctx.stroke(grid, with: .color(Noir.nightEdge.opacity(0.35)), lineWidth: 0.5)

        // The river.
        var river = Path()
        river.move(to: CGPoint(x: 0, y: sz.height * 0.45))
        river.addCurve(to: CGPoint(x: sz.width, y: sz.height * 0.52),
                       control1: CGPoint(x: sz.width * 0.35, y: sz.height * 0.20),
                       control2: CGPoint(x: sz.width * 0.60, y: sz.height * 0.88))
        ctx.stroke(river, with: .color(Noir.river), style: StrokeStyle(lineWidth: sz.height * 0.09, lineCap: .round))
        ctx.stroke(river, with: .color(Noir.influenceInk.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

        // Route threads from the cellar to every district where routes run.
        let origin = point(.cellars, sz)
        for d in DistrictId.allCases where d != .cellars {
            let ds = state.district(d)
            guard ds.unlocked else { continue }
            let levels = ds.totalRouteLevels
            var thread = Path()
            thread.move(to: origin)
            let target = point(d, sz)
            let mid = CGPoint(x: (origin.x + target.x) / 2, y: min(origin.y, target.y) - sz.height * 0.06)
            thread.addQuadCurve(to: target, control: mid)
            let color = danger(d) ? Noir.danger : Noir.amber
            let width = levels > 0 ? 1.2 + min(3, CGFloat(levels) * 0.25) : 1
            let style = levels > 0 ? StrokeStyle(lineWidth: width, lineCap: .round) : StrokeStyle(lineWidth: 1, dash: [4, 4])
            ctx.stroke(thread, with: .color(color.opacity(levels > 0 ? 0.9 : 0.5)), style: style)
        }
    }

    private func point(_ d: DistrictId, _ sz: CGSize) -> CGPoint {
        let p = Self.position(d)
        return CGPoint(x: p.x * sz.width, y: p.y * sz.height)
    }

    @ViewBuilder
    private func pin(_ d: DistrictId, size: CGSize) -> some View {
        let ds = state.district(d)
        let p = point(d, size)
        let isDanger = danger(d)
        let ring: Color = isDanger ? Noir.danger : (ds.unlocked ? Noir.amber : Noir.inkMuted)
        Button {
            onSelect(d)
        } label: {
            ZStack {
                Circle().fill(Noir.ground).frame(width: 30, height: 30)
                Circle().trim(from: 0, to: ds.unlocked ? ds.control / 100 : 0)
                    .stroke(ring, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 30, height: 30)
                Circle().strokeBorder(ring.opacity(0.45), lineWidth: 1).frame(width: 30, height: 30)
                Image(systemName: ds.unlocked ? Glyph.district(d) : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ds.unlocked ? Noir.ink : Noir.inkMuted)
            }
            .frame(width: Noir.minTarget, height: Noir.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(p)
        .accessibilityLabel(Text(verbatim: pinLabel(d, ds, isDanger)))
        .accessibilityIdentifier("map.\(d.rawValue)")
    }

    private func pinLabel(_ d: DistrictId, _ ds: DistrictState, _ isDanger: Bool) -> String {
        var parts = [t(Labels.district(d))]
        if ds.unlocked {
            parts.append(t("district_control") + " " + t.points(ds.control))
        } else {
            parts.append(t("district_locked"))
        }
        if state.investigation?.district == d {
            parts.append(t("heat_status_investigation"))
        } else if isDanger {
            parts.append(t("district_suspended", t.duration(ds.suspendedUntil - state.time)))
        }
        return parts.joined(separator: ", ")
    }
}
