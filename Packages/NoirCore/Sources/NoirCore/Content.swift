import Foundation

/*
 * Authored, static game content. Everything here is fictional and abstract:
 * products are named goods with economic profiles only (price, cost, throughput, risk).
 * No real substances, processes or places. Player-facing text lives in the app's string tables.
 */

public enum ProductId: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case glimmer = "GLIMMER", cinder = "CINDER", velvet = "VELVET", halo = "HALO"
}

public enum DistrictId: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case cellars = "CELLARS", docks = "DOCKS", neonMile = "NEON_MILE", foundry = "FOUNDRY", crownHill = "CROWN_HILL"
}

public enum FrontId: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case laundromat = "LAUNDROMAT", taxi = "TAXI", nightclub = "NIGHTCLUB", construction = "CONSTRUCTION", gallery = "GALLERY"
}

public enum CrewRole: String, CaseIterable, Codable, Sendable {
    case foreman = "FOREMAN", courier = "COURIER", enforcer = "ENFORCER", accountant = "ACCOUNTANT", lawyer = "LAWYER", fixer = "FIXER"
}

public enum Trait: String, CaseIterable, Codable, Sendable {
    case loyal = "LOYAL", greedy = "GREEDY", hothead = "HOTHEAD", discreet = "DISCREET", connected = "CONNECTED", meticulous = "METICULOUS"

    public var powerMult: Double {
        switch self {
        case .loyal: 1.0
        case .greedy: 1.3
        case .hothead: 1.25
        case .discreet: 0.9
        case .connected: 1.0
        case .meticulous: 1.15
        }
    }

    public var wageMult: Double {
        switch self {
        case .loyal, .hothead, .discreet: 1.0
        case .greedy: 1.5
        case .connected: 1.1
        case .meticulous: 1.15
        }
    }
}

public enum UpgradeBranch: String, CaseIterable, Codable, Sendable {
    case logistics = "LOGISTICS", production = "PRODUCTION", security = "SECURITY", finance = "FINANCE", network = "NETWORK"
}

public enum UpgradeId: String, CaseIterable, Codable, Sendable {
    case bikeCouriers = "BIKE_COURIERS", deliveryVans = "DELIVERY_VANS", deadDrops = "DEAD_DROPS", distributionHub = "DISTRIBUTION_HUB"
    case shiftPlan = "SHIFT_PLAN", piecework = "PIECEWORK", qualityControl = "QUALITY_CONTROL", supplyContracts = "SUPPLY_CONTRACTS"
    case lookouts = "LOOKOUTS", policeScanner = "POLICE_SCANNER", fallbackStash = "FALLBACK_STASH", cleanHands = "CLEAN_HANDS"
    case doubleBooks = "DOUBLE_BOOKS", shellCompanies = "SHELL_COMPANIES", taxOffice = "TAX_OFFICE", privateBank = "PRIVATE_BANK"
    case regularsTable = "REGULARS_TABLE", boughtPress = "BOUGHT_PRESS", councilFriends = "COUNCIL_FRIENDS", cityCouncil = "CITY_COUNCIL"

    public var branch: UpgradeBranch {
        switch self {
        case .bikeCouriers, .deliveryVans, .deadDrops, .distributionHub: .logistics
        case .shiftPlan, .piecework, .qualityControl, .supplyContracts: .production
        case .lookouts, .policeScanner, .fallbackStash, .cleanHands: .security
        case .doubleBooks, .shellCompanies, .taxOffice, .privateBank: .finance
        case .regularsTable, .boughtPress, .councilFriends, .cityCouncil: .network
        }
    }

    public var tier: Int {
        switch self {
        case .bikeCouriers, .shiftPlan, .lookouts, .doubleBooks, .regularsTable: 1
        case .distributionHub, .supplyContracts, .cleanHands, .privateBank, .cityCouncil: 3
        default: 2
        }
    }

    /// The other half of a tier-2 pair: buying one rules the other out for this run.
    public var exclusive: UpgradeId? {
        switch self {
        case .deliveryVans: .deadDrops
        case .deadDrops: .deliveryVans
        case .piecework: .qualityControl
        case .qualityControl: .piecework
        case .policeScanner: .fallbackStash
        case .fallbackStash: .policeScanner
        case .shellCompanies: .taxOffice
        case .taxOffice: .shellCompanies
        case .boughtPress: .councilFriends
        case .councilFriends: .boughtPress
        default: nil
        }
    }

    public static func inBranch(_ b: UpgradeBranch) -> [UpgradeId] { allCases.filter { $0.branch == b } }
}

public enum LineTrack: String, CaseIterable, Codable, Sendable {
    case capacity = "CAPACITY", speed = "SPEED", quality = "QUALITY"
}

public enum PerkId: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case startingCapital = "STARTING_CAPITAL", oldContacts = "OLD_CONTACTS", efficientLines = "EFFICIENT_LINES"
    case cleanBooks = "CLEAN_BOOKS", coldTrail = "COLD_TRAIL", knownName = "KNOWN_NAME"

    public var maxRank: Int { self == .knownName ? 3 : 5 }
}

public enum TutorialStep: String, CaseIterable, Codable, Sendable {
    case startLine = "START_LINE", stockUp = "STOCK_UP", openRoute = "OPEN_ROUTE", earn = "EARN"
    case buyFront = "BUY_FRONT", launder = "LAUNDER", heatBriefing = "HEAT_BRIEFING", done = "DONE"

    public var ordinal: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public let tutorialStockTarget = 9.0
public let tutorialEarnTarget = 150.0
public let tutorialLaunderTarget = 40.0

public struct ProductDef: Sendable, Equatable {
    public let id: ProductId
    public let basePrice: Double
    public let unitCost: Double
    public let cycleSec: Double
    public let batch: Double
    /// Heat exposure per unit of revenue.
    public let risk: Double
    public let demandPerMin: Double
    /// Route throughput (units/s) per route level.
    public let routeRate: Double
    public let routeCostBase: Double
    public let lineCost: Double
    public let lineUpgradeBase: Double
    /// Chapter in which the line can be bought.
    public let unlockChapter: Int
}

public struct DistrictDef: Sendable, Equatable {
    public let id: DistrictId
    public let unlockChapter: Int
    public let unlockClean: Double
    public let unlockInfluence: Double
    public let police: Double
    public let priceMod: Double
    public let routeMod: Double
    public let demandMod: [ProductId: Double]
    public let startRival: Double
    /// Influence per second at 100 % control.
    public let influenceRate: Double
    public let tier: Double
    public let front: FrontId
}

public struct FrontDef: Sendable, Equatable {
    public let id: FrontId
    public let district: DistrictId
    public let buy: Cost
    /// Dirty cash laundered per second at level 1.
    public let capacity: Double
    public let fee: Double
    public let risk: Double
    public let cover: Double
    public let upgradeCleanBase: Double
}

public struct CrewDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let role: CrewRole
    public let trait: Trait
    public let tier: Int
    public let hireCost: Double
    public let wagePerMin: Double
    public let unlockChapter: Int

    public var basePower: Double { tier == 1 ? 1.0 : 1.7 }
}

public struct Cost: Sendable, Equatable {
    public var dirty: Double
    public var clean: Double
    public var influence: Double

    public init(dirty: Double = 0, clean: Double = 0, influence: Double = 0) {
        self.dirty = dirty
        self.clean = clean
        self.influence = influence
    }

    public func affordable(_ s: GameState) -> Bool {
        s.dirty >= dirty - 1e-9 && s.clean >= clean - 1e-9 && s.influence >= influence - 1e-9
    }

    public func pay(_ s: inout GameState) {
        s.dirty -= dirty
        s.clean -= clean
        s.influence -= influence
    }

    public func grant(_ s: inout GameState) {
        s.dirty += dirty
        s.clean += clean
        s.influence += influence
    }

    public func scaled(_ f: Double) -> Cost { Cost(dirty: dirty * f, clean: clean * f, influence: influence * f) }
    public var isFree: Bool { dirty <= 0 && clean <= 0 && influence <= 0 }
}

public enum Objective: Sendable, Hashable {
    case earnDirty(Double)
    case lineLevels(ProductId, Int)
    case crewCount(Int)
    case launder(Double)
    case unlockDistrict(DistrictId)
    case ownLine(ProductId)
    case ownFront(FrontId)
    case control(DistrictId, Double)
    case upgrades(Int)
    case influenceHeld(Double)
}

public enum Content {
    public static let maxLineLevel = 10
    public static let maxRouteLevel = 10
    public static let maxFrontLevel = 10
    public static let maxStorageLevel = 12
    public static let maxProtectionLevel = 14
    public static let finalChapter = 6

    public static let heatWarning = 50.0
    public static let heatInvestigation = 75.0
    public static let heatClear = 60.0
    public static let investigationSeconds = 180.0
    public static let offlineHeatCeiling = 74.0
    public static let offlineCapSeconds: Int64 = 8 * 3600
    public static let offlineEfficiency = 1.0

    public static let raidSuspendSeconds = 120.0
    public static let turfCooldown = 60.0
    public static let bribeCooldown = 120.0

    public static func product(_ p: ProductId) -> ProductDef {
        switch p {
        case .glimmer:
            ProductDef(id: .glimmer, basePrice: 10, unitCost: 2.5, cycleSec: 8, batch: 3, risk: 1.0, demandPerMin: 30,
                       routeRate: 0.2, routeCostBase: 40, lineCost: 0, lineUpgradeBase: 60, unlockChapter: 0)
        case .cinder:
            ProductDef(id: .cinder, basePrice: 26, unitCost: 7, cycleSec: 12, batch: 6, risk: 0.6, demandPerMin: 36,
                       routeRate: 0.18, routeCostBase: 150, lineCost: 2500, lineUpgradeBase: 250, unlockChapter: 2)
        case .velvet:
            ProductDef(id: .velvet, basePrice: 90, unitCost: 24, cycleSec: 20, batch: 4, risk: 1.1, demandPerMin: 14,
                       routeRate: 0.07, routeCostBase: 900, lineCost: 15000, lineUpgradeBase: 1500, unlockChapter: 3)
        case .halo:
            ProductDef(id: .halo, basePrice: 480, unitCost: 130, cycleSec: 40, batch: 2, risk: 1.4, demandPerMin: 4,
                       routeRate: 0.02, routeCostBase: 6000, lineCost: 90000, lineUpgradeBase: 12000, unlockChapter: 5)
        }
    }

    public static func district(_ d: DistrictId) -> DistrictDef {
        switch d {
        case .cellars:
            DistrictDef(id: .cellars, unlockChapter: 0, unlockClean: 0, unlockInfluence: 0, police: 0.7, priceMod: 0.85, routeMod: 1.0,
                        demandMod: [.glimmer: 1.2, .cinder: 0.6, .velvet: 0.4, .halo: 0.1],
                        startRival: 40, influenceRate: 0.008, tier: 1.0, front: .laundromat)
        case .docks:
            DistrictDef(id: .docks, unlockChapter: 2, unlockClean: 1500, unlockInfluence: 0, police: 0.9, priceMod: 0.95, routeMod: 1.4,
                        demandMod: [.glimmer: 1.0, .cinder: 1.6, .velvet: 0.5, .halo: 0.2],
                        startRival: 65, influenceRate: 0.012, tier: 1.3, front: .taxi)
        case .neonMile:
            DistrictDef(id: .neonMile, unlockChapter: 3, unlockClean: 15000, unlockInfluence: 60, police: 1.3, priceMod: 1.25, routeMod: 1.0,
                        demandMod: [.glimmer: 0.9, .cinder: 0.4, .velvet: 1.8, .halo: 1.0],
                        startRival: 60, influenceRate: 0.02, tier: 1.8, front: .nightclub)
        case .foundry:
            DistrictDef(id: .foundry, unlockChapter: 4, unlockClean: 90000, unlockInfluence: 220, police: 0.8, priceMod: 1.0, routeMod: 1.2,
                        demandMod: [.glimmer: 0.8, .cinder: 1.8, .velvet: 0.6, .halo: 0.3],
                        startRival: 80, influenceRate: 0.025, tier: 2.4, front: .construction)
        case .crownHill:
            DistrictDef(id: .crownHill, unlockChapter: 5, unlockClean: 450000, unlockInfluence: 650, police: 1.8, priceMod: 1.7, routeMod: 1.0,
                        demandMod: [.glimmer: 0.3, .cinder: 0.2, .velvet: 1.2, .halo: 2.2],
                        startRival: 70, influenceRate: 0.05, tier: 3.2, front: .gallery)
        }
    }

    public static func front(_ f: FrontId) -> FrontDef {
        switch f {
        case .laundromat:
            FrontDef(id: .laundromat, district: .cellars, buy: Cost(dirty: 120), capacity: 4, fee: 0.30, risk: 0.25, cover: 1, upgradeCleanBase: 150)
        case .taxi:
            FrontDef(id: .taxi, district: .docks, buy: Cost(clean: 4000), capacity: 7, fee: 0.22, risk: 0.30, cover: 4, upgradeCleanBase: 1500)
        case .nightclub:
            FrontDef(id: .nightclub, district: .neonMile, buy: Cost(clean: 30000), capacity: 32, fee: 0.15, risk: 0.60, cover: 10, upgradeCleanBase: 10000)
        case .construction:
            FrontDef(id: .construction, district: .foundry, buy: Cost(clean: 150_000), capacity: 120, fee: 0.25, risk: 0.15, cover: 40, upgradeCleanBase: 50000)
        case .gallery:
            FrontDef(id: .gallery, district: .crownHill, buy: Cost(clean: 700_000), capacity: 450, fee: 0.10, risk: 0.35, cover: 90, upgradeCleanBase: 220_000)
        }
    }

    public static let crew: [CrewDef] = [
        CrewDef(id: "brandt", name: "Jonas Brandt", role: .foreman, trait: .meticulous, tier: 1, hireCost: 300, wagePerMin: 6, unlockChapter: 1),
        CrewDef(id: "varga", name: "Emil Varga", role: .courier, trait: .hothead, tier: 1, hireCost: 350, wagePerMin: 7, unlockChapter: 1),
        CrewDef(id: "okafor", name: "Sami Okafor", role: .fixer, trait: .connected, tier: 1, hireCost: 1200, wagePerMin: 15, unlockChapter: 1),
        CrewDef(id: "morgen", name: "Ilse Morgen", role: .accountant, trait: .loyal, tier: 1, hireCost: 1500, wagePerMin: 18, unlockChapter: 1),
        CrewDef(id: "feld", name: "Dario Feld", role: .enforcer, trait: .hothead, tier: 1, hireCost: 4000, wagePerMin: 40, unlockChapter: 2),
        CrewDef(id: "wolff", name: "Hanna Wolff", role: .lawyer, trait: .discreet, tier: 1, hireCost: 6000, wagePerMin: 60, unlockChapter: 2),
        CrewDef(id: "kessler", name: "Mira Kessler", role: .foreman, trait: .loyal, tier: 2, hireCost: 30000, wagePerMin: 300, unlockChapter: 3),
        CrewDef(id: "hollis", name: "Lena Hollis", role: .courier, trait: .discreet, tier: 2, hireCost: 35000, wagePerMin: 320, unlockChapter: 3),
        CrewDef(id: "sand", name: "Viktor Sand", role: .enforcer, trait: .loyal, tier: 2, hireCost: 150_000, wagePerMin: 1200, unlockChapter: 4),
        CrewDef(id: "reiter", name: "Paul Reiter", role: .accountant, trait: .greedy, tier: 2, hireCost: 160_000, wagePerMin: 1400, unlockChapter: 4),
        CrewDef(id: "kraus", name: "Anton Kraus", role: .lawyer, trait: .connected, tier: 2, hireCost: 600_000, wagePerMin: 4000, unlockChapter: 5),
        CrewDef(id: "lind", name: "Greta Lind", role: .fixer, trait: .greedy, tier: 2, hireCost: 650_000, wagePerMin: 4500, unlockChapter: 5),
    ]

    public static func crewDef(_ id: String) -> CrewDef? { crew.first { $0.id == id } }

    public static func upgradeCost(_ u: UpgradeId) -> Cost {
        switch u.tier {
        case 1: Cost(clean: 1500)
        case 2: Cost(clean: 25000, influence: 40)
        default: Cost(clean: 200_000, influence: 150)
        }
    }

    public static func upgradeAvailableChapter(_ u: UpgradeId) -> Int {
        switch u.tier {
        case 1: 1
        case 2: 3
        default: 4
        }
    }

    public static func lineUpgradeCost(_ p: ProductId, _ track: LineTrack, currentLevel: Int) -> Double {
        let trackMult: Double = switch track {
        case .capacity: 1.0
        case .speed: 1.25
        case .quality: 1.5
        }
        return product(p).lineUpgradeBase * trackMult * pow(1.75, Double(currentLevel - 1))
    }

    /// Every route level past the first reaches more corners and buyers: +15 % demand in that district per level.
    /// Without it a route stops paying as soon as it can carry more than the street buys.
    public static func routeReach(level: Int) -> Double { level <= 1 ? 1 : 1 + 0.15 * Double(level - 1) }

    public static func routeCost(_ d: DistrictId, _ p: ProductId, currentLevel: Int) -> Double {
        product(p).routeCostBase * district(d).tier * pow(1.55, Double(currentLevel))
    }

    public static func storageCost(currentLevel: Int) -> Double { 120 * pow(2.1, Double(currentLevel - 1)) }
    public static func storageCapacity(level: Int) -> Double { 120 * pow(1.8, Double(level - 1)) }

    public static func frontUpgradeCost(_ f: FrontId, currentLevel: Int) -> Double {
        front(f).upgradeCleanBase * pow(1.9, Double(currentLevel - 1))
    }

    public static func protectionCost(currentLevel: Int) -> Double { 600 * pow(2.6, Double(currentLevel)) }
    public static func protectionCover(level: Int) -> Double { level <= 0 ? 0 : 8 * (pow(2.0, Double(level)) - 1) }

    public static func perkCost(currentRank: Int) -> Int { currentRank + 1 }

    /// Chapter objectives. Chapter 0 is the briefing (see `TutorialStep`); chapter 6 is the final operation.
    public static func objectives(chapter: Int) -> [Objective] {
        switch chapter {
        case 1: [.earnDirty(3000), .lineLevels(.glimmer, 6), .crewCount(2), .launder(1500)]
        case 2: [.unlockDistrict(.docks), .ownLine(.cinder), .control(.docks, 55), .ownFront(.taxi)]
        case 3: [.unlockDistrict(.neonMile), .ownLine(.velvet), .ownFront(.nightclub), .upgrades(3), .launder(60000)]
        case 4: [.unlockDistrict(.foundry), .control(.foundry, 60), .crewCount(5), .ownFront(.construction), .influenceHeld(400)]
        case 5: [.unlockDistrict(.crownHill), .ownLine(.halo), .ownFront(.gallery), .control(.crownHill, 50)]
        default: []
        }
    }

    public static func chapterReward(_ chapter: Int) -> Cost {
        switch chapter {
        case 1: Cost(dirty: 1000)
        case 2: Cost(clean: 3000, influence: 20)
        case 3: Cost(clean: 20000, influence: 60)
        case 4: Cost(clean: 150_000, influence: 120)
        case 5: Cost(clean: 400_000, influence: 200)
        default: Cost()
        }
    }

    // MARK: Final operation
    public static let finalControlRequired = 70.0
    public static let finalHeatMax = 50.0
    public static let finalPhaseCooldown = 120.0
    public static func finalCleanRequired(ng: Int) -> Double { 1_200_000 * (1 + 0.25 * Double(ng)) }
    public static func finalInfluenceRequired(ng: Int) -> Double { 1200 * (1 + 0.25 * Double(ng)) }

    public static func legacyAward(_ s: GameState) -> Int {
        var pts = 10
        pts += min(8, s.upgrades.count / 2)
        if s.stats.raids == 0 { pts += 3 }
        pts += min(4, s.stats.investigationsSurvived)
        return pts
    }

    public static func rivalNgBonus(ng: Int) -> Double { 5.0 * Double(ng) }
}
