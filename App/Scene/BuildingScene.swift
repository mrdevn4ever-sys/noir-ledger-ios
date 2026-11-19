import NoirCore
import SwiftUI

/// The whole operation as one living cross-section: the street on top with the depot, the vehicle and the customers'
/// house; the lift shaft on the left; one floor per workshop below, each with its workers, its machines and its crate
/// shelf; the next floor still bricked up; the foundation. Everything moves with the simulation.
struct BuildingScene: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(\.noirReduceMotion) private var reduceMotion

    /// Measurements of the art at @3x, in points.
    static let streetHeight: CGFloat = 236
    static let roadHeight: CGFloat = 46
    static let floorHeight: CGFloat = 196
    static let floorBoards: CGFloat = 18
    static let shaftWidth: CGFloat = 54
    static let lockedHeight: CGFloat = 132
    static let foundationHeight: CGFloat = 70
    /// Width the floor art was drawn for; positions on a floor scale with the screen.
    static let artWidth: CGFloat = 402

    /// A sheet covers the scene: nothing needs to move behind it.
    var covered = false

    var body: some View {
        let goods = state.openGoods
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                StreetSection(state: state, forecast: forecast, sheet: $sheet)
                    .frame(height: Self.streetHeight)
                    .modifier(ScrollVisibility())
                ForEach(Array(goods.enumerated()), id: \.element) { i, g in
                    FloorRow(good: g, index: i, state: state, forecast: forecast.good(g), sheet: $sheet)
                        .frame(height: Self.floorHeight)
                        .modifier(ScrollVisibility())
                }
                if let next = Good.allCases.first(where: { !state.isOpen($0) }) {
                    LockedFloor(good: next, state: state).frame(height: Self.lockedHeight)
                }
                Image("Foundation").resizable().frame(height: Self.foundationHeight).accessibilityHidden(true)
            }
            LiftCar(trip: TripMotion(state.trip), floors: goods.count)
        }
        .environment(\.sceneAnimating, !covered && !reduceMotion)
        .onAppear { SceneImages.shared.prewarm(SceneArt.prewarmList(state)) }
        .onChange(of: prewarmKey) { _, _ in SceneImages.shared.prewarm(SceneArt.prewarmList(state)) }
    }

    /// Changes when the scene's looks change: a floor's stage, the fleet's stage, the newest quarter.
    private var prewarmKey: String {
        state.openGoods.map { "\($0.rawValue)\(SceneArt.stage(level: state.workshop($0)?.bench ?? 1))" }.joined()
            + "\(SceneArt.stage(level: state.fleet))\(state.quarters.count)"
    }
}

/// Lets the part of the scene that is scrolled out of view stand still.
struct ScrollVisibility: ViewModifier {
    @Environment(\.sceneAnimating) private var parent
    @State private var visible = true

    func body(content: Self.Content) -> some View {
        content
            .environment(\.sceneAnimating, parent && visible)
            .onGeometryChange(for: Bool.self) { proxy in
                guard let bounds = proxy.bounds(of: .scrollView) else { return true }
                return CGRect(origin: .zero, size: proxy.size).intersects(bounds.insetBy(dx: 0, dy: -60))
            } action: { visible = $0 }
    }
}

// MARK: - Street

struct StreetSection: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @Environment(\.sceneAnimating) private var animating
    @State private var floaters: [Floater] = []
    @State private var floaterSeq = 0
    @State private var burstAt = 0.0

    static let depotWidth: CGFloat = 128
    static let houseWidth: CGFloat = 118
    static let buildingHeight: CGFloat = 150

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let streetY = h - BuildingScene.roadHeight
            let buildingTop = streetY + 4 - Self.buildingHeight
            ZStack(alignment: .topLeading) {
                StreetBackdrop(width: w, height: h, fireflies: (state.quarters.values.map(\.attention).max() ?? 0) < 30)
                CustomersHouse(state: state, forecast: forecast, sheet: $sheet)
                    .frame(width: Self.houseWidth, height: Self.buildingHeight)
                    .position(x: w - Self.houseWidth / 2, y: buildingTop + Self.buildingHeight / 2)
                Depot(state: state, forecast: forecast, sheet: $sheet)
                    .frame(width: Self.depotWidth, height: Self.buildingHeight)
                    .position(x: Self.depotWidth / 2, y: buildingTop + Self.buildingHeight / 2)
                dispatcher(streetY: streetY)
                if let trip = TripMotion(state.trip) {
                    BuyerLeaving(quarter: SceneArt.newestQuarter(state), trip: trip, x0: w - Self.houseWidth + 10, y: streetY + 2 - 32)
                }
                police(w: w, h: h, streetY: streetY)
                MovingVehicle(fleet: state.fleet, trip: TripMotion(state.trip), rush: state.ability(.rushRun).active > 0,
                              start: BuildingScene.shaftWidth + 4, end: w - Self.houseWidth + 26, h: h)
                goButton(w: w, h: h)
                if state.ability(.quietWord).active > 0 {
                    AnimatedStrip(name: "ShushBubble4", frames: 4, fps: 4, size: CGSize(width: 54, height: 54))
                        .position(x: w - Self.houseWidth + 26, y: buildingTop + 50)
                        .allowsHitTesting(false)
                }
                OneShotStrip(name: "CoinBurst8", frames: 8, size: 72, start: burstAt)
                    .position(x: w - Self.houseWidth / 2, y: buildingTop + 60)
                ForEach(floaters) { f in
                    FloaterView(floater: f).position(x: w - 70, y: buildingTop + 20)
                }
            }
            .clipped()
        }
        .onChange(of: store.bookings) { _, _ in
            guard let last = state.ledger.last, last.amount > 0 else { return }
            if animating { burstAt = Date().timeIntervalSinceReferenceDate }
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

    /// "Go!" next to the waiting vehicle while nobody sends it by themselves.
    @ViewBuilder private func goButton(w: CGFloat, h: CGFloat) -> some View {
        if !state.dispatcher && state.trip == nil {
            let v = SceneArt.vehicle(fleetLevel: state.fleet)
            let vw = v.size.width * 0.8 / 3
            let start = BuildingScene.shaftWidth + 4 + vw / 2
            Button { store.dispatch(.tapFleet) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.toon(12, .black))
                    Text(verbatim: t("l4_go")).font(.toon(16, .heavy))
                }
                .foregroundStyle(Color(hex: 0x1B1B28))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Toon.window, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                .background(Capsule().fill(Toon.window.opacity(0.35)).padding(-5))
                .idle(.pulse(1.05), duration: 0.8)
            }
            .buttonStyle(.plain)
            .position(x: min(w - Self.houseWidth - 34, start + vw / 2 + 44), y: h - BuildingScene.roadHeight / 2)
            .accessibilityIdentifier("fleet.go")
        }
    }

    /// The dispatcher waits at the curb next to the depot; the empty place shows the price.
    @ViewBuilder private func dispatcher(streetY: CGFloat) -> some View {
        let x = Self.depotWidth + 24
        if state.dispatcher {
            Dispatcher(trip: TripMotion(state.trip)).position(x: x, y: streetY + 2 - 33)
        } else {
            Button { store.dispatch(.hireDispatcher) } label: {
                ManagerSlot(crew: FlowContent.dispatcher, hired: false, cost: FlowContent.dispatcherCost,
                            affordable: state.cash >= FlowContent.dispatcherCost)
            }
            .buttonStyle(.plain)
            .position(x: x, y: streetY - 30)
            .accessibilityLabel(Text(verbatim: t("l4_dispatcher_t", Content.crewDef(FlowContent.dispatcher)?.name ?? "")))
            .accessibilityIdentifier("dispatcher.hire")
        }
    }

    /// Watched: a cop walks the pavement. Hot: the patrol car stands at the kerb, its light turning, the cop writing.
    @ViewBuilder private func police(w: CGFloat, h: CGFloat, streetY: CGFloat) -> some View {
        let hottest = state.quarters.values.map(\.attention).max() ?? 0
        let tier = Flow.tier(hottest)
        if tier >= 2 {
            let car = SceneArt.police
            let ch = car.size.height * 0.7 / 3
            AnimatedStrip(name: "SirenGlow4", frames: 4, fps: 6, size: CGSize(width: 200, height: 100))
                .position(x: w * 0.55, y: h - 8 - ch)
                .allowsHitTesting(false)
            VehicleSprite(vehicle: car, wheelAngle: 0, scale: 0.7)
                .overlay(alignment: .top) {
                    AnimatedStrip(name: "PoliceSiren2", frames: 2, fps: 4, size: CGSize(width: 28, height: 14))
                        .offset(x: 4, y: -8)
                }
                .position(x: w * 0.55, y: h - 8 - ch / 2)
            SceneFigure(sheet: "CopNotebook4", move: .work)
                .position(x: w - Self.houseWidth - 22, y: streetY + 2 - 35)
        } else if tier == 1 {
            WalkingCop(from: Self.depotWidth - 20, span: Double(w - Self.depotWidth - Self.houseWidth + 40))
                .position(x: 0, y: streetY + 2 - 35)
        }
    }
}

/// The still street behind everything: sky, moon, skyline, road, lamp. Laid out again only when the size changes.
struct StreetBackdrop: View {
    let width: CGFloat
    let height: CGFloat
    let fireflies: Bool

    var body: some View {
        let w = width
        let h = height
        let streetY = h - BuildingScene.roadHeight
        let gapMid = (StreetSection.depotWidth + w - StreetSection.houseWidth) / 2
        ZStack(alignment: .topLeading) {
            // The sky art is 270 pt tall; the scene shows its lower part.
            SceneImage("SkyNight", w, 270).offset(y: h - 270)
            SceneImage("Moon", 44, 44).idle(.bob(4), duration: 2.6)
                .position(x: w * 0.6, y: 28)
            SceneImage("SkylineFar", w, 100).position(x: w / 2, y: streetY - 62)
            if fireflies {
                AnimatedStrip(name: "Fireflies8", frames: 8, fps: 5, size: CGSize(width: 100, height: 100))
                    .opacity(0.8).position(x: w * 0.3, y: streetY - 120)
            }
            SceneImage("SkylineNear", w, 120).position(x: w / 2, y: streetY - 60)
            // Road with the shaft opening on the left
            SceneImage("Street", w, BuildingScene.roadHeight + 1).position(x: w / 2, y: h - BuildingScene.roadHeight / 2)
            SceneImage("ShaftTile", BuildingScene.shaftWidth, BuildingScene.floorHeight)
                .frame(width: BuildingScene.shaftWidth, height: BuildingScene.roadHeight, alignment: .top).clipped()
                .position(x: BuildingScene.shaftWidth / 2, y: h - BuildingScene.roadHeight / 2)
            // Lamp between the houses
            SceneImage("StreetLampGlow", 110, 110).opacity(0.85).idle(.glow(0.8), duration: 0.9)
                .position(x: gapMid, y: streetY - 70)
            SceneImage("StreetLamp", 47, 87).position(x: gapMid, y: streetY - 42)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// The vehicle on the road: it waits in front of the depot, drives to the customers and comes back. Runs at the
/// display's rate while it drives and reads the trip between simulation ticks.
struct MovingVehicle: View {
    let fleet: Int
    let trip: TripMotion?
    let rush: Bool
    let start: CGFloat
    let end: CGFloat
    let h: CGFloat
    @Environment(LedgerStore.self) private var store
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        let v = SceneArt.vehicle(fleetLevel: fleet)
        let scale: CGFloat = 0.8
        let vw = v.size.width * scale / 3
        let vh = v.size.height * scale / 3
        let from = start + vw / 2
        let to = end - vw / 2
        TimelineView(.animation(paused: !animating || trip == nil)) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            let p = store.tripPhase(trip, at: tl.date)
            let driving = trip != nil && p >= 0.5
            let x: CGFloat = p < 0.5 ? from : (p < 0.75 ? from + (to - from) * CGFloat((p - 0.5) / 0.25)
                                                         : to - (to - from) * CGFloat((p - 0.75) / 0.25))
            let facing: CGFloat = trip != nil && p >= 0.75 ? -1 : 1
            let bob: CGFloat = driving ? CGFloat(sin(time * 18)) * 0.8 : 0
            ZStack {
                if v.wheel == nil && driving {
                    SpriteStrip(name: "Fleet0Push8", frames: 8, frame: Int(time * 12), size: CGSize(width: vw, height: vh))
                } else {
                    VehicleSprite(vehicle: v, wheelAngle: driving ? time * 9 * Double(facing) : 0, scale: scale)
                }
                if driving && rush {
                    SpriteStrip(name: "SpeedLines6", frames: 6, frame: Int(time * 14), size: CGSize(width: 80, height: 54))
                        .offset(x: -vw / 2 - 30)
                }
                if driving && fleet >= 25 {
                    SpriteStrip(name: "Exhaust6", frames: 6, frame: Int(time * 12), size: CGSize(width: 22, height: 22))
                        .offset(x: -vw / 2 - 6, y: vh / 2 - 12)
                }
            }
            .scaleEffect(x: facing, y: 1)
            .position(x: x, y: h - 3 - vh / 2 + bob)
        }
        .allowsHitTesting(false)
    }
}

/// Emil Varga at the curb: waits, talks now and then, whistles the vehicle off.
struct Dispatcher: View {
    let trip: TripMotion?
    @Environment(LedgerStore.self) private var store
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 6, paused: !animating)) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            let p = store.tripPhase(trip, at: tl.date)
            let move: (String, Int, Double) = trip != nil && p > 0.4 && p < 0.55 ? ("BodyVargaWhistle4", 4, 6)
                : (Int(time / 4) % 3 == 0 ? (SceneArt.talk(FlowContent.dispatcher), 4, 5) : (SceneArt.body(FlowContent.dispatcher), 2, 1.5))
            SpriteStrip(name: move.0, frames: move.1, frame: Int(time * move.2), size: CGSize(width: 44, height: 66))
        }
        .frame(width: 44, height: 66)
    }
}

/// When the goods arrive, a buyer carries a crate off along the pavement.
struct BuyerLeaving: View {
    let quarter: Quarter
    let trip: TripMotion
    let x0: CGFloat
    let y: CGFloat
    @Environment(LedgerStore.self) private var store
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        TimelineView(.animation(paused: !animating)) { tl in
            let p = store.tripPhase(trip, at: tl.date)
            if p > 0.75 {
                let f = CGFloat((p - 0.75) / 0.25)
                SpriteStrip(name: "Buyer\(SceneArt.name(quarter))Carry8", frames: 8,
                            frame: Int(tl.date.timeIntervalSinceReferenceDate * SceneArt.Move.carry.fps), size: SceneFigure.size(0.9))
                    .scaleEffect(x: -1, y: 1)
                    .position(x: x0 - f * 110, y: y)
                    .opacity(Double(1 - max(0, f - 0.8) * 5))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A cop walking the pavement back and forth.
struct WalkingCop: View {
    let from: CGFloat
    let span: Double
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        TimelineView(.animation(paused: !animating)) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            let raw = (time * 14).truncatingRemainder(dividingBy: span * 2)
            let forward = raw < span
            SpriteStrip(name: "CopWalk8", frames: 8, frame: Int(time * SceneArt.Move.walk.fps), size: SceneFigure.size(1))
                .scaleEffect(x: forward ? 1 : -1, y: 1)
                .offset(x: from + CGFloat(forward ? raw : span * 2 - raw))
        }
        .allowsHitTesting(false)
    }
}

/// Our building on the street: the lift head over the shaft, the fleet's level, the mailbox with new orders.
struct Depot: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        let neck = state.openGoods.contains { forecast.good($0)?.bottleneck == .fleet }
        let mail = Flow.boardOpen(state) && !state.offers.isEmpty
        ZStack(alignment: .topLeading) {
            SceneImage(SceneArt.depot(fleetLevel: state.fleet), StreetSection.depotWidth, StreetSection.buildingHeight)
            SceneImage("LiftHead", BuildingScene.shaftWidth, 40).offset(y: 42)
            // Fleet level
            Button { sheet = .station(.fleet) } label: {
                LevelBadge(level: state.fleet, caption: t("l4_fleet"), affordable: state.cash >= Flow.fleetCost(state, 1), bottleneck: neck)
            }
            .buttonStyle(.plain)
            .offset(x: BuildingScene.shaftWidth + 6, y: 40)
            .accessibilityLabel(Text(verbatim: t("l4_fleet") + " " + t("l4_level", state.fleet)))
            .accessibilityIdentifier("fleet.open")
            // Mailbox: new orders
            Button { sheet = .orders } label: {
                Group {
                    if mail {
                        Image("Mailbox").resizable().frame(width: 34, height: 34).idle(.sway(4), duration: 0.5)
                    } else {
                        Image("MailboxClosed").resizable().frame(width: 34, height: 34)
                    }
                }
                    .overlay {
                        if state.ability(.newWindow).active > 0 {
                            AnimatedStrip(name: "WindowSparkle6", frames: 6, fps: 10, size: CGSize(width: 54, height: 54))
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if mail {
                            Text(verbatim: "\(state.offers.count)").font(.toon(11, .heavy))
                                .foregroundStyle(.white).frame(minWidth: 17, minHeight: 17)
                                .background(Color(hex: 0xE5484D), in: Circle())
                                .offset(x: 5, y: -5)
                        }
                    }
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .offset(x: StreetSection.depotWidth - 46, y: 102)
            .accessibilityLabel(Text(verbatim: t("l4_orders")))
            .accessibilityIdentifier("mailbox.open")
        }
        .frame(width: StreetSection.depotWidth, height: StreetSection.buildingHeight, alignment: .topLeading)
    }
}

/// The customers' house across the street: the newest quarter's house, dark and shut while it is hot.
struct CustomersHouse: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        let neck = state.openGoods.contains { forecast.good($0)?.bottleneck == .demand }
        let demand = state.openGoods.reduce(0) { $0 + (forecast.good($1)?.demand ?? 0) }
        let quarter = SceneArt.newestQuarter(state)
        let hot = Flow.tier(state.quarter(quarter).attention) >= 2
        Button { sheet = .contacts } label: {
            ZStack(alignment: .topLeading) {
                SceneImage(SceneArt.customers(quarter, hot: hot), StreetSection.houseWidth, StreetSection.buildingHeight)
                if !hot {
                    SceneFigure(sheet: SceneArt.buyer(quarter, walking: false), move: .idle, scale: 0.9)
                        .offset(x: 2, y: StreetSection.buildingHeight - 4 - 63)
                }
                VStack(spacing: 1) {
                    Text(verbatim: t("l4_customers")).font(.toon(11, .bold))
                    Text(verbatim: t("l4_per_min", t.money(demand))).font(.toon(14, .heavy)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(width: 92, height: 40)
                .background(Image("BadgePlate").resizable())
                .overlay(alignment: .topTrailing) { if neck { BottleneckDot().offset(x: 8, y: -8) } }
                .offset(x: 18, y: -4)
            }
            .frame(width: StreetSection.houseWidth, height: StreetSection.buildingHeight, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: t("l4_contacts")))
        .accessibilityIdentifier("contacts.open")
    }
}

/// The lift car: parked in the depot, goes down to the deepest floor and back in the first half of a trip.
struct LiftCar: View {
    let trip: TripMotion?
    let floors: Int
    @Environment(LedgerStore.self) private var store
    @Environment(\.sceneAnimating) private var animating

    static let size = CGSize(width: 46, height: 56)

    var body: some View {
        let streetY = BuildingScene.streetHeight - BuildingScene.roadHeight
        let top = streetY + 4 - Self.size.height
        let bottom = BuildingScene.streetHeight + CGFloat(max(1, floors)) * BuildingScene.floorHeight - BuildingScene.floorBoards - Self.size.height
        // The cable hangs from the pulley in the lift head.
        let pulley = streetY + 4 - StreetSection.buildingHeight + 42 + 22
        TimelineView(.animation(paused: !animating || trip == nil)) { tl in
            let p = trip == nil ? 1 : store.tripPhase(trip, at: tl.date)
            let phase: CGFloat = p < 0.25 ? CGFloat(p / 0.25) : (p < 0.5 ? 1 - CGFloat((p - 0.25) / 0.25) : 0)
            let y = top + phase * (bottom - top)
            let loaded = (trip?.loaded ?? false) && (p > 0.25 || phase > 0.9)
            ZStack(alignment: .top) {
                Image("LiftCable").resizable(resizingMode: .tile)
                    .frame(width: 4, height: max(0, y - pulley))
                    .offset(y: -max(0, y - pulley))
                SceneImage(loaded ? "LiftCarLoaded" : "LiftCarEmpty", Self.size.width, Self.size.height)
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
            .offset(x: (BuildingScene.shaftWidth - Self.size.width) / 2, y: y)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Floors

/// One workshop floor: tap it to run a cycle by hand; the badge upgrades the bench; the crates are its shelf.
struct FloorRow: View {
    let good: Good
    let index: Int
    let state: FlowState
    let forecast: GoodForecast?
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @Environment(\.sceneAnimating) private var animating
    @State private var floaters: [Floater] = []
    @State private var floaterSeq = 0
    @State private var rebuildAt = 0.0

    var body: some View {
        let w = state.workshop(good) ?? WorkshopState()
        let stage = SceneArt.stage(level: w.bench)
        let capacity = Flow.shelfCapacity(state, good)
        let full = w.stock >= capacity - 1e-9
        let running = w.cycle != nil
        let def = FlowContent.good(good)
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let k = width / BuildingScene.artWidth
            let floorY = height - BuildingScene.floorBoards
            let machine = (start: 150 * k, end: 317 * k)
            ZStack(alignment: .topLeading) {
                FloorStage(good: good, bench: w.bench, lit: running || w.lead, width: width, height: height)
                // Double shift: a warm pulsing glow with turning gears over the machines.
                if state.ability(.doubleShift).active > 0, state.ability(.doubleShift).good == good {
                    AnimatedStrip(name: "ShiftGlow6", frames: 6, fps: 10, size: CGSize(width: 200, height: 100))
                        .position(x: (machine.start + machine.end) / 2, y: floorY - 70)
                        .allowsHitTesting(false)
                }
                FloorCrew(good: good, count: 1 + min(2, stage / 2), lead: w.lead, running: running,
                          machineStart: machine.start, machineEnd: machine.end, width: width, height: height)
                // The shelf with its crates
                Button { sheet = .station(.shelf(good)) } label: {
                    CrateShelf(good: good, stock: w.stock, capacity: capacity, full: full, neck: forecast?.bottleneck == .shelf)
                }
                .buttonStyle(.plain)
                .offset(x: BuildingScene.shaftWidth + 2, y: floorY - CrateShelf.height)
                .accessibilityLabel(Text(verbatim: t("l4_shelf_count", t.decimal(w.stock.rounded(.down), digits: 0), t.money(capacity))))
                .accessibilityIdentifier("shelf.\(good.rawValue)")
                // Workshop lead
                Group {
                    if w.lead {
                        LeadFigure(crew: def.lead, index: index)
                    } else {
                        Button { store.dispatch(.hireLead(good)) } label: {
                            ManagerSlot(crew: def.lead, hired: false, cost: def.leadCost, affordable: state.cash >= def.leadCost)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: t("l4_lead_t", Content.crewDef(def.lead)?.name ?? "")))
                        .accessibilityIdentifier("lead.\(good.rawValue)")
                    }
                }
                .frame(width: 44, height: 66, alignment: .bottom)
                .offset(x: BuildingScene.shaftWidth + 66, y: floorY - 66)
                // Bench level
                Button { sheet = .station(.bench(good)) } label: {
                    LevelBadge(level: w.bench, caption: t(GoodText.name(good)),
                               affordable: state.cash >= Flow.benchCost(state, good, 1),
                               bottleneck: forecast?.bottleneck == .bench)
                }
                .buttonStyle(.plain)
                .offset(x: width - 72, y: 26)
                .accessibilityLabel(Text(verbatim: t("l4_bench_of", t(GoodText.name(good))) + " " + t("l4_level", w.bench)))
                .accessibilityIdentifier("bench.\(good.rawValue).open")
                // Production rate
                CoinLabel(text: t("l4_per_min_crates", t.money(forecast?.production ?? 0)))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .offset(x: BuildingScene.shaftWidth + 8, y: 8)
                // Tap hint
                if !w.lead && !running && !full {
                    let cx = (machine.start + machine.end) / 2
                    VStack(spacing: 2) {
                        Text(verbatim: t("l4_tap_here"))
                            .font(.toon(15, .heavy))
                            .foregroundStyle(Color(hex: 0x1B1B28))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Toon.window, in: Capsule())
                            .background(Capsule().fill(Toon.window.opacity(0.35)).padding(-5))
                        AnimatedStrip(name: "TapHand4", frames: 4, fps: 6, size: CGSize(width: 40, height: 40))
                    }
                    .position(x: cx, y: height * 0.42)
                    .allowsHitTesting(false)
                }
                // Cycle progress
                if running {
                    CycleBar(cycle: w.cycle ?? 0, seconds: Flow.cycleSeconds(state, good), width: machine.end - machine.start)
                        .offset(x: machine.start, y: floorY + 6)
                }
                OneShotStrip(name: "DustPuff6", frames: 6, size: 120, start: rebuildAt, fps: 9)
                    .position(x: (machine.start + machine.end) / 2, y: floorY - 60)
                ForEach(floaters) { f in
                    FloaterView(floater: f).position(x: BuildingScene.shaftWidth + 34, y: floorY - CrateShelf.height - 14)
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
        .onChange(of: stage) { old, new in
            if new > old && animating { rebuildAt = Date().timeIntervalSinceReferenceDate }
        }
        .onChange(of: w.stock) { old, new in
            guard new > old + 0.5, animating else { return }
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
}

/// A floor's room: the art for its stage, lit with moving machines while it works, dim while it waits.
struct FloorStage: View {
    let good: Good
    let bench: Int
    let lit: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            SceneImage(SceneArt.floor(good, level: bench), width, height)
            SceneImage("ShaftTile", BuildingScene.shaftWidth, height)
            if lit {
                SceneImage(SceneArt.floorLit(good, level: bench), width, height)
                AnimatedStrip(name: SceneArt.floorRun(good, level: bench), frames: 4, fps: 6, size: CGSize(width: width, height: height))
            } else {
                Rectangle().fill(Color.black.opacity(0.22)).frame(width: width - BuildingScene.shaftWidth, height: height)
                    .offset(x: BuildingScene.shaftWidth)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// A floor's workers: with a lead they walk, work and carry; without, they work while a cycle runs and doze otherwise.
struct FloorCrew: View {
    let good: Good
    let count: Int
    let lead: Bool
    let running: Bool
    let machineStart: CGFloat
    let machineEnd: CGFloat
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let floorY = height - BuildingScene.floorBoards
        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { i in
                let station = machineStart + (machineEnd - machineStart) * (0.15 + 0.35 * CGFloat(i))
                let shelfX = BuildingScene.shaftWidth + 90
                if lead {
                    WorkerLoop(good: good, worker: i, shelfX: shelfX, station: station)
                        .offset(y: floorY - 70)
                } else if running {
                    SceneFigure(sheet: SceneArt.worker(good, .work), move: .work, phase: Double(i))
                        .position(x: station, y: floorY - 35)
                } else {
                    SceneFigure(sheet: SceneArt.worker(good, .sleep), move: .sleep, phase: Double(i) * 0.7)
                        .position(x: station, y: floorY - 35)
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// A worker's day with a lead: walk to the machine, work, carry a crate back to the shelf. At the display's rate.
struct WorkerLoop: View {
    let good: Good
    let worker: Int
    let shelfX: CGFloat
    let station: CGFloat
    @Environment(\.sceneAnimating) private var animating

    static let loop = 7.0

    var body: some View {
        TimelineView(.animation(paused: !animating)) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            let phase = Double(worker)
            let t0 = (time + phase * 2.3).truncatingRemainder(dividingBy: Self.loop) / Self.loop
            let (move, x, facing): (SceneArt.Move, CGFloat, CGFloat) =
                t0 < 0.3 ? (.walk, shelfX + (station - shelfX) * CGFloat(t0 / 0.3), 1)
                : (t0 < 0.6 ? (.work, station, 1) : (.carry, station - (station - shelfX) * CGFloat((t0 - 0.6) / 0.4), -1))
            SpriteStrip(name: SceneArt.worker(good, move), frames: move.frames, frame: Int((time + phase) * move.fps),
                        size: SceneFigure.size(1))
                .scaleEffect(x: facing, y: 1)
                .offset(x: x - 22)
        }
    }
}

/// The workshop lead at the shelf: stands, and now and then talks.
struct LeadFigure: View {
    let crew: String
    let index: Int
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 5, paused: !animating)) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            let talking = Int(time / 5 + Double(index)) % 3 == 0
            SpriteStrip(name: talking ? SceneArt.talk(crew) : SceneArt.body(crew), frames: talking ? 4 : 2,
                        frame: Int(time * (talking ? 5 : 1.5) + Double(index)), size: CGSize(width: 44, height: 66))
        }
        .accessibilityHidden(true)
    }
}

/// The running cycle's progress under the machines, smooth between simulation ticks.
struct CycleBar: View {
    let cycle: Double
    let seconds: Double
    let width: CGFloat
    @Environment(LedgerStore.self) private var store
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        let span = max(0.1, seconds)
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.5)).frame(width: width, height: 7)
            TimelineView(.animation(paused: !animating)) { tl in
                let p = min(1, cycle + store.sinceTick(tl.date) / span)
                Capsule().fill(Toon.up).frame(width: max(7, width * CGFloat(p)), height: 7)
            }
        }
        .frame(width: width, height: 7, alignment: .leading)
    }
}

/// The shelf of a floor: three boards with two crates each; the crates fill up with the stock, a red sign when full.
struct CrateShelf: View {
    let good: Good
    let stock: Double
    let capacity: Double
    let full: Bool
    let neck: Bool
    @Environment(\.l10n) private var t

    static let height: CGFloat = 96

    var body: some View {
        let fraction = capacity > 0 ? min(1, stock / capacity) : 0
        let count = Int((fraction * 6).rounded(.up))
        let boards: [CGFloat] = [18, 43, 68]
        VStack(spacing: 2) {
            Text(verbatim: t.money(stock.rounded(.down)) + "/" + t.money(capacity))
                .font(.toon(12, .heavy)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(full ? Color(hex: 0xE5484D) : Color.black.opacity(0.6), in: Capsule())
                .frame(width: 66)
            ZStack(alignment: .topLeading) {
                Image("ShelfFrame").resizable().frame(width: 60, height: 72)
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<2, id: \.self) { col in
                        let n = (2 - row) * 2 + col
                        Image(n < count ? SceneArt.crate(good) : "CrateSlot").resizable()
                            .frame(width: 25, height: 20)
                            .offset(x: 5 + CGFloat(col) * 25, y: boards[row] - 20)
                    }
                }
                if full {
                    Image("ShelfFullSign").resizable().frame(width: 50, height: 20).rotationEffect(.degrees(-6))
                        .offset(x: 5, y: 24)
                }
            }
            .frame(width: 60, height: 72, alignment: .topLeading)
        }
        .frame(width: 66, height: Self.height, alignment: .bottom)
        .overlay(alignment: .topTrailing) { if neck || full { BottleneckDot().offset(x: 8, y: 4) } }
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
            Image(SceneArt.floorLocked(good)).resizable()
            HStack(spacing: 0) {
                Image("ShaftTile").resizable().frame(width: BuildingScene.shaftWidth)
                Spacer()
            }
            VStack(spacing: 6) {
                Spacer()
                if def.chapter <= state.chapter {
                    Button { store.dispatch(.openWorkshop(good)) } label: {
                        VStack(spacing: 1) {
                            Text(verbatim: t("l4_open_floor", t(GoodText.name(good)))).font(.toon(15, .heavy))
                            Text(verbatim: t.money(def.openCost)).font(.toon(13, .bold)).monospacedDigit()
                        }
                        .foregroundStyle(Color(hex: 0x1B1B28))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(state.cash >= def.openCost ? Toon.window : Toon.badgeGrey, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.cash < def.openCost)
                    .accessibilityIdentifier("workshop.\(good.rawValue).open")
                } else {
                    Text(verbatim: t("l4_locked_floor", def.chapter))
                        .font(.toon(14, .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.6), in: Capsule())
                }
            }
            .padding(.leading, BuildingScene.shaftWidth)
            .padding(.bottom, 26)
        }
    }
}
