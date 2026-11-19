import NoirCore
import SwiftUI

/// The whole operation as one living cross-section: the street on top with the depot, the van and the customers'
/// house; the lift shaft on the left; one floor per workshop below, each with its workers, its machines and its crate
/// stack; the next floor still bricked up; the foundation. Everything moves with the simulation.
struct BuildingScene: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(\.noirReduceMotion) private var reduceMotion

    static let streetHeight: CGFloat = 270
    static let floorHeight: CGFloat = 196
    static let shaftWidth: CGFloat = 54

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let goods = state.openGoods
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    StreetSection(state: state, forecast: forecast, time: time, sheet: $sheet)
                        .frame(height: Self.streetHeight)
                    ForEach(Array(goods.enumerated()), id: \.element) { i, g in
                        FloorRow(good: g, index: i, state: state, forecast: forecast.good(g), time: time, sheet: $sheet)
                            .frame(height: Self.floorHeight)
                    }
                    if let next = Good.allCases.first(where: { !state.isOpen($0) }) {
                        LockedFloor(good: next, state: state).frame(height: 132)
                    }
                    Foundation().frame(height: 70)
                }
                LiftCar(state: state, floors: goods.count, time: time)
            }
        }
    }
}

// MARK: - Street

struct StreetSection: View {
    let state: FlowState
    let forecast: Forecast
    let time: Double
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var floaters: [Floater] = []
    @State private var floaterSeq = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let streetY = h - 46
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Toon.skyTop, Toon.skyBottom], startPoint: .top, endPoint: .bottom)
                Circle().fill(Toon.moon).frame(width: 46, height: 46).position(x: w * 0.62, y: 46)
                    .shadow(color: Toon.moon.opacity(0.6), radius: 18)
                Skyline().frame(width: w, height: 130).position(x: w / 2, y: streetY - 65)
                StreetLamp().position(x: w * 0.38, y: streetY - 40)
                StreetLamp().position(x: w * 0.72, y: streetY - 40)
                // Street
                Rectangle().fill(Toon.street).frame(width: w, height: 46).position(x: w / 2, y: h - 23)
                Rectangle().fill(Toon.curb).frame(width: w, height: 5).position(x: w / 2, y: streetY + 2)
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(Color.white.opacity(0.25)).frame(width: 22, height: 3)
                        .position(x: CGFloat(i) * w / 5 + 20, y: h - 18)
                }
                Depot(state: state, sheet: $sheet).frame(width: 128, height: 150).position(x: 64, y: streetY - 75)
                CustomersHouse(state: state, forecast: forecast, sheet: $sheet).frame(width: 118, height: 150)
                    .position(x: w - 59, y: streetY - 75)
                police(w: w, streetY: streetY)
                van(w: w, streetY: streetY)
                ForEach(floaters) { f in
                    FloaterView(floater: f).position(x: w - 70, y: streetY - 150)
                }
            }
            .clipped()
        }
        .onChange(of: store.bookings) { _, _ in
            guard let last = state.ledger.last, last.amount > 0 else { return }
            floaterSeq += 1
            let id = floaterSeq
            floaters.append(Floater(id: id, text: "+" + t.money(last.amount), at: .zero))
            if floaters.count > 4 { floaters.removeFirst() }
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                floaters.removeAll { $0.id == id }
            }
        }
    }

    /// The van's place on the street: it waits at the depot, drives to the customers in the second half of a trip
    /// (the first half is the lift collecting the crates) and comes back.
    @ViewBuilder private func van(w: CGFloat, streetY: CGFloat) -> some View {
        let p = state.trip.map { 1 - $0.left / max(0.1, $0.duration) } ?? 0
        let start: CGFloat = 150
        let end = w - 150
        let x: CGFloat = p < 0.5 ? start : (p < 0.75 ? start + (end - start) * CGFloat((p - 0.5) / 0.25)
                                                       : end - (end - start) * CGFloat((p - 0.75) / 0.25))
        let facing: CGFloat = p >= 0.75 ? -1 : 1
        Scooter(wheel: state.trip != nil && p >= 0.5 ? time * 12 : 0)
            .scaleEffect(x: facing, y: 1)
            .position(x: x, y: streetY - 6)
            .animation(.linear(duration: 0.25), value: x)
    }

    @ViewBuilder private func police(w: CGFloat, streetY: CGFloat) -> some View {
        let hottest = state.quarters.values.map(\.attention).max() ?? 0
        let tier = Flow.tier(hottest)
        if tier >= 2 {
            PoliceCar(time: time, siren: true).position(x: w * 0.5, y: streetY + 14)
        } else if tier == 1 {
            let x = CGFloat((time * 30).truncatingRemainder(dividingBy: Double(w + 160))) - 80
            PoliceCar(time: time).position(x: x, y: streetY + 16)
        }
    }
}

/// Our building's top floor on the street: the lift head, the door, the dispatcher's place, the van's level.
struct Depot: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let f = Flow.forecast(state)
        let neck = state.openGoods.contains { f.good($0)?.bottleneck == .fleet }
        ZStack(alignment: .topLeading) {
            // Building
            RoundedRectangle(cornerRadius: 4).fill(Toon.wall).frame(width: 128, height: 118).offset(y: 32)
            Rectangle().fill(Toon.roof).frame(width: 136, height: 12).offset(x: -4, y: 26)
            // Lift head with pulley
            Rectangle().fill(Toon.shaft).frame(width: BuildingScene.shaftWidth, height: 118).offset(x: 0, y: 32)
            Circle().stroke(Toon.metal, lineWidth: 4).frame(width: 22, height: 22).offset(x: 16, y: 6)
            Rectangle().fill(Toon.metal).frame(width: 4, height: 30).offset(x: 25, y: 4)
            // Door
            RoundedRectangle(cornerRadius: 3).fill(Toon.wallDark).frame(width: 30, height: 46).offset(x: 86, y: 104)
            // Fleet level
            Button { sheet = .station(.fleet) } label: {
                LevelBadge(level: state.fleet, caption: t("l4_fleet"), affordable: state.cash >= Flow.fleetCost(state, 1), bottleneck: neck)
            }
            .buttonStyle(.plain)
            .offset(x: 62, y: 44)
            .accessibilityLabel(Text(verbatim: t("l4_fleet") + " " + t("l4_level", state.fleet)))
            .accessibilityIdentifier("fleet.open")
            // Dispatcher
            if state.dispatcher {
                ManagerSlot(crew: FlowContent.dispatcher, hired: true, cost: 0, affordable: false).offset(x: 6, y: 96)
                    .accessibilityHidden(true)
            } else {
                Button { store.dispatch(.hireDispatcher) } label: {
                    ManagerSlot(crew: FlowContent.dispatcher, hired: false, cost: FlowContent.dispatcherCost,
                                affordable: state.cash >= FlowContent.dispatcherCost)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: 84)
                .accessibilityLabel(Text(verbatim: t("l4_dispatcher_t", Content.crewDef(FlowContent.dispatcher)?.name ?? "")))
                .accessibilityIdentifier("dispatcher.hire")
            }
            if !state.dispatcher && state.trip == nil {
                Button { store.dispatch(.tapFleet) } label: {
                    Text(verbatim: t("l4_go"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x1B1B28))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Toon.window, in: Capsule())
                        .shadow(color: Toon.window.opacity(0.6), radius: 6)
                }
                .buttonStyle(.plain)
                .offset(x: 60, y: 0)
                .accessibilityIdentifier("fleet.go")
            }
        }
        .frame(width: 128, height: 150, alignment: .topLeading)
    }
}

/// The customers' house across the street: who buys, how much, a buyer at the door.
struct CustomersHouse: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        let neck = state.openGoods.contains { forecast.good($0)?.bottleneck == .demand }
        let demand = state.openGoods.reduce(0) { $0 + (forecast.good($1)?.demand ?? 0) }
        Button { sheet = .contacts } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x8E7A68)).frame(width: 118, height: 112).offset(y: 38)
                Rectangle().fill(Toon.roof).frame(width: 126, height: 12).offset(x: -4, y: 32)
                ForEach(0..<2, id: \.self) { r in
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 2).fill(Toon.window.opacity(0.85)).frame(width: 18, height: 16)
                            .offset(x: 12 + CGFloat(c) * 34, y: 56 + CGFloat(r) * 26)
                    }
                }
                Crate(size: 22).offset(x: 78, y: 126)
                Crate(size: 22).offset(x: 90, y: 110)
                Figure(look: .buyer, skinIndex: 2).offset(x: 20, y: 82)
                VStack(spacing: 1) {
                    Text(verbatim: t("l4_customers")).font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(verbatim: t("l4_per_min", t.money(demand))).font(.system(size: 14, weight: .heavy, design: .rounded)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .foregroundStyle(.white)
                .frame(width: 84, height: 40)
                .background(Toon.badge, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .topTrailing) { if neck { BottleneckDot().offset(x: 8, y: -8) } }
                .offset(x: 18, y: 0)
            }
            .frame(width: 118, height: 150, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: t("l4_contacts")))
        .accessibilityIdentifier("contacts.open")
    }
}

/// The lift car: waits at the top, goes down to the deepest floor and back in the first half of a trip.
struct LiftCar: View {
    let state: FlowState
    let floors: Int
    let time: Double

    var body: some View {
        let p = state.trip.map { 1 - $0.left / max(0.1, $0.duration) } ?? 1
        let depth = CGFloat(max(1, floors)) * BuildingScene.floorHeight
        let phase: CGFloat = p < 0.25 ? CGFloat(p / 0.25) : (p < 0.5 ? 1 - CGFloat((p - 0.25) / 0.25) : 0)
        let top = BuildingScene.streetHeight - 74
        let y = top + phase * (depth - 10)
        let load = state.trip?.crates ?? 0
        ZStack {
            Rectangle().fill(Toon.metal.opacity(0.7)).frame(width: 2, height: max(0, y - 30)).offset(y: -max(0, y - 30) / 2 - 30)
            RoundedRectangle(cornerRadius: 5).fill(Toon.metalDark).frame(width: 46, height: 56)
            RoundedRectangle(cornerRadius: 3).stroke(Toon.metal, lineWidth: 2).frame(width: 40, height: 50)
            if load > 0.5 {
                VStack(spacing: 1) {
                    Crate(size: 16)
                    Crate(size: 16)
                }
                .offset(y: 8)
            } else {
                Figure(look: .courier, skinIndex: 3).scaleEffect(0.6).offset(y: 8)
            }
        }
        .frame(width: 46, height: 56)
        .offset(x: 4, y: y)
        .animation(.linear(duration: 0.25), value: y)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Floors

/// Brick wall background for a floor.
struct BrickWall: View {
    var dark = false

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dark ? Toon.brickLine : Toon.brick))
            var row = 0
            for y in stride(from: CGFloat(0), to: size.height, by: 16) {
                let shift: CGFloat = row % 2 == 0 ? 0 : 18
                for x in stride(from: -shift, to: size.width, by: 36) {
                    ctx.stroke(Path(CGRect(x: x, y: y, width: 36, height: 16)), with: .color(Toon.brickLine.opacity(dark ? 0.6 : 1)), lineWidth: 1.5)
                }
                row += 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// One workshop floor: tap it to run a cycle by hand; the badge upgrades the bench; the crates are its shelf.
struct FloorRow: View {
    let good: Good
    let index: Int
    let state: FlowState
    let forecast: GoodForecast?
    let time: Double
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var floaters: [Floater] = []
    @State private var floaterSeq = 0
    @State private var lastStock = 0.0

    var body: some View {
        let w = state.workshop(good) ?? WorkshopState()
        let stage = min(5, Flow.milestonesReached(w.bench))
        let capacity = Flow.shelfCapacity(state, good)
        let full = w.stock >= capacity - 1e-9
        let running = w.cycle != nil
        let def = FlowContent.good(good)
        GeometryReader { geo in
            let width = geo.size.width
            let floorY = geo.size.height - 18
            let workArea = (start: CGFloat(150), end: width - 84)
            ZStack(alignment: .topLeading) {
                BrickWall()
                // Floor boards and shaft
                Rectangle().fill(Toon.floorBoard).frame(width: width, height: 18).offset(y: floorY)
                Rectangle().fill(Toon.floorEdge).frame(width: width, height: 3).offset(y: floorY)
                Rectangle().fill(Toon.shaft).frame(width: BuildingScene.shaftWidth, height: geo.size.height)
                Rectangle().fill(Toon.metalDark).frame(width: 3, height: geo.size.height).offset(x: 6)
                Rectangle().fill(Toon.metalDark).frame(width: 3, height: geo.size.height).offset(x: BuildingScene.shaftWidth - 9)
                // Lamps along the ceiling
                ForEach(0..<4, id: \.self) { i in
                    HangingLamp(on: running || w.lead).offset(x: workArea.start + CGFloat(i) * (workArea.end - workArea.start) / 4 + 10, y: 0)
                }
                // The goods being made
                production(stage: stage, running: running || w.lead)
                    .frame(width: workArea.end - workArea.start, height: 110, alignment: .bottom)
                    .offset(x: workArea.start, y: floorY - 110)
                // Workers
                ForEach(0..<(1 + min(2, stage / 2)), id: \.self) { i in
                    worker(i, from: 112, to: workArea.end - 30, floorY: floorY, active: running || w.lead)
                }
                // Crate stack = the shelf
                Button { sheet = .station(.shelf(good)) } label: {
                    CrateStack(stock: w.stock, capacity: capacity, full: full,
                               neck: forecast?.bottleneck == .shelf)
                }
                .buttonStyle(.plain)
                .offset(x: BuildingScene.shaftWidth + 4, y: floorY - 96)
                .accessibilityLabel(Text(verbatim: t("l4_shelf_count", t.decimal(w.stock.rounded(.down), digits: 0), t.money(capacity))))
                .accessibilityIdentifier("shelf.\(good.rawValue)")
                // Workshop lead
                Group {
                    if w.lead {
                        ManagerSlot(crew: def.lead, hired: true, cost: 0, affordable: false).accessibilityHidden(true)
                    } else {
                        Button { store.dispatch(.hireLead(good)) } label: {
                            ManagerSlot(crew: def.lead, hired: false, cost: def.leadCost, affordable: state.cash >= def.leadCost)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: t("l4_lead_t", Content.crewDef(def.lead)?.name ?? "")))
                        .accessibilityIdentifier("lead.\(good.rawValue)")
                    }
                }
                .offset(x: BuildingScene.shaftWidth + 4, y: 8)
                // Bench level
                Button { sheet = .station(.bench(good)) } label: {
                    LevelBadge(level: w.bench, caption: t(GoodText.name(good)),
                               affordable: state.cash >= Flow.benchCost(state, good, 1),
                               bottleneck: forecast?.bottleneck == .bench)
                }
                .buttonStyle(.plain)
                .offset(x: width - 72, y: 34)
                .accessibilityLabel(Text(verbatim: t("l4_bench_of", t(GoodText.name(good))) + " " + t("l4_level", w.bench)))
                .accessibilityIdentifier("bench.\(good.rawValue).open")
                // Production rate
                CoinLabel(text: t("l4_per_min_crates", t.money(forecast?.production ?? 0)))
                    .offset(x: width - 150, y: 8)
                // Tap hint
                if !w.lead && !running && !full {
                    Text(verbatim: t("l4_tap_here"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x1B1B28))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Toon.window, in: Capsule())
                        .shadow(color: Toon.window.opacity(0.6), radius: 8)
                        .scaleEffect(1 + 0.05 * CGFloat(sin(time * 4)))
                        .position(x: (workArea.start + workArea.end) / 2, y: geo.size.height * 0.45)
                        .allowsHitTesting(false)
                }
                // Cycle progress
                if running {
                    Capsule().fill(Color.black.opacity(0.4)).frame(width: workArea.end - workArea.start, height: 6)
                        .offset(x: workArea.start, y: floorY + 6)
                    Capsule().fill(Toon.up).frame(width: max(6, (workArea.end - workArea.start) * CGFloat(w.cycle ?? 0)), height: 6)
                        .offset(x: workArea.start, y: floorY + 6)
                }
                ForEach(floaters) { f in
                    FloaterView(floater: f).position(x: BuildingScene.shaftWidth + 40, y: floorY - 110)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { store.dispatch(.tapBench(good)) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction { store.dispatch(.tapBench(good)) }
        .overlay {
            // An invisible, tappable element for automation and VoiceOver: the bench itself.
            Color.clear
                .frame(width: 120, height: 60)
                .contentShape(Rectangle())
                .onTapGesture { store.dispatch(.tapBench(good)) }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text(verbatim: t("l4_cd_bench", t(GoodText.name(good)))))
                .accessibilityIdentifier("bench.\(good.rawValue)")
        }
        .onChange(of: w.stock) { old, new in
            guard new > old + 0.5 else { return }
            floaterSeq += 1
            let id = floaterSeq
            floaters.append(Floater(id: id, text: "+" + t.money(new - old), at: .zero))
            if floaters.count > 3 { floaters.removeFirst() }
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                floaters.removeAll { $0.id == id }
            }
        }
    }

    @ViewBuilder private func production(stage: Int, running: Bool) -> some View {
        switch good {
        case .weed:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<(3 + min(stage, 2)), id: \.self) { i in
                    Plant(stage: stage, sway: time * 1.3 + Double(i), bud: stage >= 3 ? Color(hex: 0xC6E85A) : Toon.leaf)
                }
            }
        case .crystal:
            HStack(alignment: .bottom, spacing: 0) {
                LabBench(stage: stage, time: time)
                if stage >= 3 { LabBench(stage: stage, time: time + 1) }
            }
        case .pills:
            HStack(alignment: .bottom, spacing: 0) {
                PillPress(stage: stage, time: time, running: running)
                if stage >= 3 { PillPress(stage: stage, time: time + 0.5, running: running) }
            }
        case .coke:
            HStack(alignment: .bottom, spacing: 0) {
                BlockTable(stage: stage)
                if stage >= 3 { BlockTable(stage: stage) }
            }
        }
    }

    private var look: Figure.Look {
        switch good {
        case .weed: .gardener
        case .crystal: .chemist
        case .pills: .presser
        case .coke: .suit
        }
    }

    /// A worker walking between the crate stack and the work area; standing still while nothing runs.
    @ViewBuilder private func worker(_ i: Int, from: CGFloat, to: CGFloat, floorY: CGFloat, active: Bool) -> some View {
        let speed = 0.18 + 0.05 * Double(i)
        let raw = (time * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
        let goingRight = raw < 0.5
        let f = goingRight ? raw * 2 : (1 - raw) * 2
        let x = active ? from + (to - from) * CGFloat(f) : to - 40 - CGFloat(i) * 46
        Figure(look: look, walk: active ? time * 9 + Double(i) : nil, facing: active ? (goingRight ? 1 : -1) : 1,
               carrying: active && !goingRight ? Toon.crate : nil, skinIndex: i + index)
            .position(x: x, y: floorY - 33)
    }
}

/// The crates on a floor's shelf: a stack that grows with the stock; red and "full" when nothing more fits.
struct CrateStack: View {
    let stock: Double
    let capacity: Double
    let full: Bool
    let neck: Bool
    @Environment(\.l10n) private var t

    var body: some View {
        let fraction = capacity > 0 ? min(1, stock / capacity) : 0
        let count = Int((fraction * 6).rounded(.up))
        VStack(spacing: 2) {
            Text(verbatim: full ? t("l4_full") : t.money(stock.rounded(.down)))
                .font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(full ? Color(hex: 0xE5484D) : Color.black.opacity(0.5), in: Capsule())
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.25)).frame(width: 56, height: 62)
                VStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<2, id: \.self) { col in
                                let n = (2 - row) * 2 + col
                                Crate(size: 26).opacity(n < count ? 1 : 0)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 60, height: 84)
        .overlay(alignment: .topTrailing) { if neck || full { BottleneckDot().offset(x: 8, y: 6) } }
    }
}

/// A floor that is still bricked up: when it opens, or the price to open it now.
struct LockedFloor: View {
    let good: Good
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = FlowContent.good(good)
        ZStack {
            BrickWall(dark: true)
            HStack(spacing: 0) {
                Rectangle().fill(Toon.shaft).frame(width: BuildingScene.shaftWidth)
                Spacer()
            }
            VStack(spacing: 6) {
                Mark(Glyph.product(good.product), size: 30).opacity(0.8)
                if def.chapter <= state.chapter {
                    Button { store.dispatch(.openWorkshop(good)) } label: {
                        VStack(spacing: 1) {
                            Text(verbatim: t("l4_open_floor", t(GoodText.name(good)))).font(.system(size: 15, weight: .heavy, design: .rounded))
                            Text(verbatim: t.money(def.openCost)).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                        }
                        .foregroundStyle(Color(hex: 0x1B1B28))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(state.cash >= def.openCost ? Toon.window : Toon.badgeGrey, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.cash < def.openCost)
                    .accessibilityIdentifier("workshop.\(good.rawValue).open")
                } else {
                    Text(verbatim: t("l4_locked_floor", def.chapter))
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.leading, BuildingScene.shaftWidth)
        }
    }
}

struct Foundation: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Toon.dirt, Toon.dirtDark]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var n = 7
            for _ in 0..<18 {
                n = (n &* 1103515245 &+ 12345) & 0x7fffffff
                let x = CGFloat(n % 1000) / 1000 * size.width
                n = (n &* 1103515245 &+ 12345) & 0x7fffffff
                let y = CGFloat(n % 1000) / 1000 * size.height
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 9, height: 6)), with: .color(Color(hex: 0x5A4436)))
            }
        }
        .accessibilityHidden(true)
    }
}
