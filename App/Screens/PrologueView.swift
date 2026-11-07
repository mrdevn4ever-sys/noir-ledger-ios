import NoirCore
import SwiftUI

/// Four pages: the funeral, the ledger, a real choice of what to carry out of the cellar, and the cellar itself.
struct PrologueView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t
    @Environment(\.noirReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var choice: PrologueChoice?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s5) {
                HStack {
                    Spacer()
                    Wordmark()
                    Spacer()
                }
                .padding(.top, Noir.s5)
                pageIndicator
                Group {
                    switch page {
                    case 0: story("pro_1_t", "pro_1_b", art: AnyView(RainyRiver()))
                    case 1: story("pro_2_t", "pro_2_b", art: AnyView(LedgerEmblem().frame(height: 120)))
                    case 2: choosePage
                    default: story("pro_4_t", "pro_4_b", art: AnyView(BareBulb()))
                    }
                }
                .id(page)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                footer
            }
            .padding(Noir.s4)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.prologue", title: "NOIR LEDGER") }
        }
        .background(Noir.ground)
    }

    private var pageIndicator: some View {
        HStack(spacing: Noir.s2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i <= page ? Noir.amber : Noir.hairline).frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: t("prologue_page", page + 1, 4)))
    }

    private func story(_ title: String, _ body: String, art: AnyView) -> some View {
        VStack(alignment: .leading, spacing: Noir.s4) {
            art.frame(maxWidth: .infinity).accessibilityHidden(true)
            Text(verbatim: t(title))
                .font(.display(.title2))
                .foregroundStyle(Noir.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("prologue.title")
            Text(verbatim: t(body))
                .font(.body)
                .foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var choosePage: some View {
        VStack(alignment: .leading, spacing: Noir.s4) {
            Text(verbatim: t("pro_3_t"))
                .font(.display(.title2))
                .foregroundStyle(Noir.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("prologue.title")
            Text(verbatim: t("pro_3_b")).font(.body).foregroundStyle(Noir.inkSoft)
            ForEach(PrologueChoice.allCases, id: \.self) { c in
                let labels = Labels.prologueChoice(c)
                let selected = choice == c
                Button {
                    choice = c
                } label: {
                    HStack(alignment: .top, spacing: Noir.s3) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? Noir.amber : Noir.inkMuted)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: t(labels.title)).font(.headline).foregroundStyle(Noir.ink)
                            Text(verbatim: t(labels.detail)).font(.subheadline).foregroundStyle(Noir.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Noir.s3)
                    .frame(minHeight: Noir.minTarget)
                    .background(selected ? Noir.raised : Noir.surface, in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous)
                        .strokeBorder(selected ? Noir.amber : Noir.hairline, lineWidth: selected ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("prologue.choice.\(c.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if page < 3 {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { page += 1 }
            } label: {
                Text(verbatim: t("btn_continue"))
            }
            .noirButton(.primary)
            .disabled(page == 2 && choice == nil)
            .accessibilityIdentifier("prologue.next")
        } else {
            Button {
                router.resetNavigation()
                store.dispatch(.choosePrologue(choice ?? .cashBox))
            } label: {
                Text(verbatim: t("pro_open"))
            }
            .noirButton(.primary)
            .accessibilityIdentifier("prologue.open")
        }
        if page > 0 {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { page -= 1 }
            } label: {
                Text(verbatim: t("cd_back"))
            }
            .noirButton(.quiet)
            .accessibilityIdentifier("prologue.back")
        }
    }
}

/// Rain over the river at night: thin slanted strokes over a dark band, drawn once (no animation).
private struct RainyRiver: View {
    var body: some View {
        Canvas { ctx, size in
            var sky = Path()
            sky.addRect(CGRect(origin: .zero, size: size))
            ctx.fill(sky, with: .color(Noir.night))
            var skyline = Path()
            let base = size.height * 0.62
            skyline.move(to: CGPoint(x: 0, y: base))
            let blocks: [(CGFloat, CGFloat)] = [(0.08, 0.30), (0.14, 0.42), (0.22, 0.35), (0.27, 0.55), (0.35, 0.40), (0.44, 0.48),
                                                (0.52, 0.33), (0.60, 0.60), (0.66, 0.44), (0.75, 0.38), (0.84, 0.50), (0.92, 0.36), (1.0, 0.42)]
            var x: CGFloat = 0
            for (nx, nh) in blocks {
                let top = base - size.height * nh * 0.5
                skyline.addLine(to: CGPoint(x: x, y: top))
                skyline.addLine(to: CGPoint(x: nx * size.width, y: top))
                x = nx * size.width
            }
            skyline.addLine(to: CGPoint(x: size.width, y: base))
            skyline.closeSubpath()
            ctx.fill(skyline, with: .color(Noir.ground))
            for i in 0..<14 {
                let wx = size.width * (0.05 + CGFloat(i) * 0.067)
                let wy = base - size.height * (0.08 + CGFloat((i * 7) % 5) * 0.04)
                ctx.fill(Path(CGRect(x: wx, y: wy, width: 3, height: 4)), with: .color(Noir.amber.opacity(0.75)))
            }
            var river = Path()
            river.addRect(CGRect(x: 0, y: base, width: size.width, height: size.height - base))
            ctx.fill(river, with: .color(Noir.river))
            for i in 0..<9 {
                let rx = size.width * (0.08 + CGFloat(i) * 0.11)
                var reflection = Path()
                reflection.move(to: CGPoint(x: rx, y: base + 6))
                reflection.addLine(to: CGPoint(x: rx, y: size.height - 6))
                ctx.stroke(reflection, with: .color(Noir.amber.opacity(0.25)), style: StrokeStyle(lineWidth: 2, dash: [3, 6]))
            }
            for i in 0..<60 {
                let fx = CGFloat((i * 37) % 100) / 100 * size.width
                let fy = CGFloat((i * 53) % 100) / 100 * size.height
                var drop = Path()
                drop.move(to: CGPoint(x: fx, y: fy))
                drop.addLine(to: CGPoint(x: fx - 4, y: fy + 12))
                ctx.stroke(drop, with: .color(Noir.inkSoft.opacity(0.22)), lineWidth: 1)
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
    }
}

/// The cellar: a bare bulb over a workbench.
private struct BareBulb: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Noir.leather))
            let cx = size.width / 2
            let glow = Path(ellipseIn: CGRect(x: cx - 90, y: 10, width: 180, height: 120))
            ctx.fill(glow, with: .radialGradient(Gradient(colors: [Noir.amber.opacity(0.35), .clear]),
                                                 center: CGPoint(x: cx, y: 50), startRadius: 4, endRadius: 90))
            var cord = Path()
            cord.move(to: CGPoint(x: cx, y: 0))
            cord.addLine(to: CGPoint(x: cx, y: 38))
            ctx.stroke(cord, with: .color(Noir.inkMuted), lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 8, y: 38, width: 16, height: 20)), with: .color(Noir.amber))
            let bench = CGRect(x: size.width * 0.15, y: size.height * 0.72, width: size.width * 0.7, height: 8)
            ctx.fill(Path(bench), with: .color(Noir.leatherEdge))
            for lx in [bench.minX + 10, bench.maxX - 14] {
                ctx.fill(Path(CGRect(x: lx, y: bench.maxY, width: 4, height: size.height - bench.maxY)), with: .color(Noir.leatherEdge))
            }
            let book = CGRect(x: cx - 26, y: bench.minY - 12, width: 52, height: 12)
            ctx.fill(Path(roundedRect: book, cornerRadius: 2), with: .color(Noir.paperGold))
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
    }
}
