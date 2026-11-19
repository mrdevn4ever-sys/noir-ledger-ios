import NoirCore
import SwiftUI

/// Names of the cartoon-night art in the asset catalog (docs/HERMES_ASSET_BRIEF_4.md) and the few measurements the
/// scene needs from it. All art is drawn at @3x; one point is three pixels.
enum SceneArt {
    static func name(_ g: Good) -> String {
        switch g {
        case .weed: "Weed"
        case .crystal: "Crystal"
        case .pills: "Pills"
        case .coke: "Coke"
        }
    }

    static func name(_ q: Quarter) -> String {
        switch q {
        case .cellars: "Cellars"
        case .oldTown: "OldTown"
        case .docks: "Docks"
        case .night: "Night"
        case .crown: "Crown"
        }
    }

    /// The six looks of a floor follow the bench's milestones 10, 25, 50, 100 and 200.
    static func stage(level: Int) -> Int {
        [10, 25, 50, 100, 200].filter { level >= $0 }.count
    }

    static func floor(_ g: Good, level: Int) -> String { "Floor\(name(g))\(stage(level: level))" }
    static func floorRun(_ g: Good, level: Int) -> String { floor(g, level: level) + "Run4" }
    static func floorLit(_ g: Good, level: Int) -> String { floor(g, level: level) + "Lit" }
    static func floorLocked(_ g: Good) -> String { "Floor\(name(g))Locked" }
    static func crate(_ g: Good) -> String { "Crate\(name(g))" }

    enum Move: String, CaseIterable {
        case walk = "Walk8", carry = "Carry8", work = "Work4", idle = "Idle2", sleep = "Sleep2"

        var frames: Int {
            switch self {
            case .walk, .carry: 8
            case .work: 4
            case .idle, .sleep: 2
            }
        }
    }

    static func worker(_ g: Good, _ move: Move) -> String { "Worker\(name(g))\(move.rawValue)" }
    static func courier(_ move: Move) -> String { "WorkerCourier\(move.rawValue)" }
    static func buyer(_ q: Quarter, walking: Bool) -> String { "Buyer\(name(q))" + (walking ? "Walk8" : "Idle2") }
    static func customers(_ q: Quarter, hot: Bool) -> String { "Customers\(name(q))" + (hot ? "Hot" : "") }
    static func talk(_ crewId: String) -> String { "Body\(crewId.prefix(1).uppercased())\(crewId.dropFirst())Talk4" }
    static func body(_ crewId: String) -> String { "Body\(crewId.prefix(1).uppercased())\(crewId.dropFirst())Idle2" }

    /// The depot grows with the fleet: shed, shop, warehouse.
    static func depot(fleetLevel: Int) -> String { "Depot\(min(2, stage(level: fleetLevel) / 2))" }

    /// A vehicle: body size and wheel centres in pixels, the wheel's diameter in pixels.
    struct Vehicle {
        let body: String
        let wheel: String?
        let size: CGSize
        let wheels: [(x: CGFloat, scale: CGFloat)]
        let wheelSize: CGFloat
    }

    static func vehicle(fleetLevel: Int) -> Vehicle {
        switch min(5, stage(level: fleetLevel)) {
        case 0: Vehicle(body: "Fleet0Body", wheel: nil, size: CGSize(width: 300, height: 200), wheels: [], wheelSize: 54)
        case 1: Vehicle(body: "Fleet1Body", wheel: "Fleet1Wheel", size: CGSize(width: 300, height: 200),
                        wheels: [(53, 0.6), (134, 1), (250, 1)], wheelSize: 66)
        case 2: Vehicle(body: "Fleet2Body", wheel: "Fleet2Wheel", size: CGSize(width: 300, height: 200), wheels: [(63, 1), (244, 1)], wheelSize: 60)
        case 3: Vehicle(body: "Fleet3Body", wheel: "Fleet3Wheel", size: CGSize(width: 360, height: 220), wheels: [(65, 1), (277, 1)], wheelSize: 66)
        case 4: Vehicle(body: "Fleet4Body", wheel: "Fleet4Wheel", size: CGSize(width: 420, height: 240), wheels: [(91, 1), (319, 1)], wheelSize: 78)
        default: Vehicle(body: "Fleet5Body", wheel: "Fleet5Wheel", size: CGSize(width: 540, height: 260), wheels: [(116, 1), (442, 1)], wheelSize: 84)
        }
    }

    static let police = Vehicle(body: "PoliceCarBody", wheel: "PoliceCarWheel", size: CGSize(width: 420, height: 240),
                                wheels: [(85, 1), (321, 1)], wheelSize: 78)

    // MARK: Sheets

    static func contact(_ id: String) -> String { "Contact" + id.prefix(1).uppercased() + id.dropFirst() }

    static func order(_ k: OrderKind) -> String {
        switch k {
        case .quiet: "OrderQuiet"
        case .loud: "OrderLoud"
        case .big: "OrderBig"
        case .trust: "OrderTrust"
        case .city: "OrderCity"
        case .finale: "OrderFinale"
        }
    }

    static func attention(tier: Int, paused: Bool) -> String {
        if paused { return "AttentionUnderground" }
        switch tier {
        case 0: return "AttentionCalm"
        case 1: return "AttentionWatched"
        default: return "AttentionHot"
        }
    }

    static func ability(_ a: Ability) -> String {
        switch a {
        case .doubleShift: "AbilityDoubleShift"
        case .rushRun: "AbilityRushRun"
        case .newWindow: "AbilityNewWindow"
        case .quietWord: "AbilityQuietWord"
        }
    }

    static func specialist(_ s: Specialist) -> String {
        switch s {
        case .okafor: "SpecialistOkafor"
        case .morgen: "SpecialistMorgen"
        case .sand: "SpecialistSand"
        case .lind: "SpecialistLind"
        case .kraus: "SpecialistKraus"
        }
    }

    static func challenge(_ c: ChallengeId, icon: Bool = false) -> String {
        let base = switch c {
        case .fog: "ChallengeFog"
        case .pressWeek: "ChallengePressWeek"
        case .strike: "ChallengeStrike"
        }
        return icon ? base + "Icon" : base
    }

    static func goal(_ k: GoalKind) -> String {
        switch k {
        case .deliveries: "GoalDeliver"
        case .hireLead: "GoalHireLead"
        case .hireDispatcher: "GoalDispatcher"
        case .orders: "GoalOrders"
        case .earn: "GoalEarn"
        case .unlockContact: "GoalUnlockContact"
        case .throughput: "GoalThroughput"
        case .openGood: "GoalOpenGood"
        case .bigOrders: "GoalBigOrder"
        case .clubNight: "GoalClubNights"
        case .trust: "GoalTrust"
        case .cityOrders: "GoalCityOrders"
        case .finale: "GoalFinale"
        }
    }

    static func chapter(_ n: Int, outro: Bool) -> String { "Chapter\(min(6, max(1, n)))" + (outro ? "Outro" : "Intro") }
    static func quarter(_ q: Quarter, wide: Bool) -> String { "Quarter\(name(q))" + (wide ? "Wide" : "") }

    static func item(_ c: StartChoice) -> String {
        switch c {
        case .cashbox: "ItemCashbox"
        case .addressBook: "ItemAddressBook"
        case .tools: "ItemTools"
        }
    }

    static var sheetNames: [String] {
        FlowContent.contacts.map { contact($0.id) } + OrderKind.allCases.map(order) + Ability.allCases.map(ability)
            + Specialist.allCases.map(specialist) + ChallengeId.allCases.flatMap { [challenge($0), challenge($0, icon: true)] }
            + (1...6).flatMap { [chapter($0, outro: false), chapter($0, outro: true)] }
            + Quarter.allCases.flatMap { [quarter($0, wide: false), quarter($0, wide: true)] } + StartChoice.allCases.map(item)
            + (0...2).map { attention(tier: $0, paused: false) } + [attention(tier: 0, paused: true)]
            + FlowContent.chapters.flatMap { $0.goals.map { goal($0.kind) } } + ["CheckDone", "CheckOpen"]
            + ["brandt", "varga", "okafor", "morgen", "feld", "wolff", "kessler", "hollis", "sand", "reiter", "kraus", "lind", "notary",
               "leopold"].flatMap { id in ["", "Happy", "Angry", "Smug"].map { "Crew" + id.prefix(1).uppercased() + id.dropFirst() + $0 } }
            + ["ScenePrologue", "CityMap", "LedgerCover", "LedgerPage", "StampPaid", "StampMissed", "SealChapter", "ChapterRibbon",
               "FavorPile", "Wordmark", "ShopBoost", "ShopCalm", "ShopWarp", "ShopStarter", "ShopPremium", "ShopNoAds",
               "ShopFavorsSmall", "ShopFavorsMedium", "ShopFavorsLarge", "ShopFavorsVault"]
    }

    /// Every image the scene composes from parts, for the test that keeps the catalog complete.
    static var composedNames: [String] {
        var names: [String] = []
        for g in Good.allCases {
            names += [floorLocked(g), crate(g)]
            names += (0...5).flatMap { ["Floor\(name(g))\($0)", "Floor\(name(g))\($0)Run4", "Floor\(name(g))\($0)Lit"] }
            names += Move.allCases.map { worker(g, $0) }
            names += [body(FlowContent.good(g).lead), talk(FlowContent.good(g).lead)]
        }
        names += Move.allCases.map { courier($0) }
        for q in Quarter.allCases {
            names += [customers(q, hot: false), customers(q, hot: true), buyer(q, walking: false), buyer(q, walking: true)]
        }
        names += (0...2).map { "Depot\($0)" }
        names += (0...5).flatMap { [vehicle(fleetLevel: [1, 10, 25, 50, 100, 200][$0]).body] + (vehicle(fleetLevel: [1, 10, 25, 50, 100, 200][$0]).wheel.map { [$0] } ?? []) }
        names += ["Fleet0Push8", "PoliceCarBody", "PoliceCarWheel", "PoliceSiren2", "CopWalk8", "CopNotebook4", "CopIdle2"]
        names += [body(FlowContent.dispatcher), talk(FlowContent.dispatcher), "BodyVargaWhistle4", "Fireflies8", "SirenGlow4", "ShushBubble4",
                  "SpeedLines6", "WindowSparkle6", "ShiftGlow6", "LevelUpRibbon", "Confetti12", "StampPaid6", "StampMissed6", "MoneyRain8"]
        names += Quarter.allCases.map { "Buyer\(name($0))Carry8" }
        names += ["SkyNight", "Moon", "SkylineFar", "SkylineNear", "Street", "StreetLamp", "StreetLampGlow", "ShaftTile", "LiftHead",
                  "LiftCable", "LiftCarEmpty", "LiftCarLoaded", "Mailbox", "MailboxClosed", "Foundation", "ShelfFrame", "ShelfFullSign",
                  "CrateSlot", "BadgePlate", "BadgePlateGrey", "ArrowUp", "BottleneckBubble", "ManagerSlot", "TapHand4", "CoinBurst8",
                  "SteamPuff6", "DustPuff6", "Exhaust6", "HudCoin", "HudFavor", "IconBook", "IconGift", "IconGiftOpen", "IconSettings",
                  "NavOrders", "NavCustomers", "NavCrew", "NavCity", "NavBook"]
        return names
    }
}

/// One frame of a horizontal sprite sheet.
struct SpriteStrip: View {
    let name: String
    let frames: Int
    let frame: Int
    /// Size of one frame in points.
    let size: CGSize

    var body: some View {
        let index = CGFloat(((frame % max(1, frames)) + frames) % max(1, frames))
        Image(name)
            .resizable()
            .interpolation(.high)
            .frame(width: size.width * CGFloat(frames), height: size.height)
            .offset(x: -size.width * index)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .clipped()
            .accessibilityHidden(true)
    }
}

/// A person of the scene at 44 × 70 points, standing on the bottom edge, facing right unless mirrored.
struct SceneFigure: View {
    let sheet: String
    let move: SceneArt.Move
    let time: Double
    var facing: CGFloat = 1
    var scale: CGFloat = 1
    var phase: Double = 0

    var body: some View {
        let fps: Double = move == .idle || move == .sleep ? 2 : (move == .work ? 6 : 10)
        SpriteStrip(name: sheet, frames: move.frames, frame: Int((time + phase) * fps), size: CGSize(width: 44 * scale, height: 70 * scale))
            .scaleEffect(x: facing, y: 1)
    }
}

/// A vehicle from its body and turning wheels; the wheels sit behind the body's fenders.
struct VehicleSprite: View {
    let vehicle: SceneArt.Vehicle
    let wheelAngle: Double
    var scale: CGFloat = 0.8

    var body: some View {
        let k = scale / 3
        let w = vehicle.size.width * k
        let h = vehicle.size.height * k
        ZStack(alignment: .topLeading) {
            if let wheel = vehicle.wheel {
                ForEach(0..<vehicle.wheels.count, id: \.self) { i in
                    let d = vehicle.wheelSize * k * vehicle.wheels[i].scale
                    Image(wheel).resizable().frame(width: d, height: d)
                        .rotationEffect(.radians(wheelAngle))
                        .offset(x: vehicle.wheels[i].x * k - d / 2, y: h - 2 * k - d)
                }
            }
            Image(vehicle.body).resizable().frame(width: w, height: h)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// A short burst (coins, dust, steam) that plays once from `start` and then disappears.
struct BurstSprite: View {
    let name: String
    let frames: Int
    let size: CGFloat
    let start: Double
    let time: Double
    var fps: Double = 12

    var body: some View {
        let f = Int((time - start) * fps)
        if start > 0, f >= 0, f < frames {
            SpriteStrip(name: name, frames: frames, frame: f, size: CGSize(width: size, height: size))
                .allowsHitTesting(false)
        }
    }
}
