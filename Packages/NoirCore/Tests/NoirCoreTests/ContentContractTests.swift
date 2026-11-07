import Foundation
import NoirCore
import Testing

/// The content contract from docs/reference-game-rules.md, checked value by value.
@Suite("Content contract")
struct ContentContractTests {

    @Test("Four fictional product lines with the documented economic profiles", arguments: [
        (ProductId.glimmer, 10.0, 2.5, 8.0, 3.0, 1.0, 30.0, 0),
        (ProductId.cinder, 26.0, 7.0, 12.0, 6.0, 0.6, 36.0, 2),
        (ProductId.velvet, 90.0, 24.0, 20.0, 4.0, 1.1, 14.0, 3),
        (ProductId.halo, 480.0, 130.0, 40.0, 2.0, 1.4, 4.0, 5),
    ])
    func productProfiles(_ id: ProductId, price: Double, cost: Double, cycle: Double, batch: Double, risk: Double, demand: Double, chapter: Int) {
        let p = Content.product(id)
        #expect(p.basePrice == price)
        #expect(p.unitCost == cost)
        #expect(p.cycleSec == cycle)
        #expect(p.batch == batch)
        #expect(p.risk == risk)
        #expect(p.demandPerMin == demand)
        #expect(p.unlockChapter == chapter)
    }

    @Test("Line prices to open: free, 2,500, 15,000 and 90,000 dirty")
    func lineCosts() {
        #expect(ProductId.allCases.map { Content.product($0).lineCost } == [0, 2500, 15000, 90000])
    }

    @Test("Five districts with unlock costs, police, price and rivals", arguments: [
        (DistrictId.cellars, 0, 0.0, 0.0, 0.7, 0.85, 40.0),
        (DistrictId.docks, 2, 1500.0, 0.0, 0.9, 0.95, 65.0),
        (DistrictId.neonMile, 3, 15000.0, 60.0, 1.3, 1.25, 60.0),
        (DistrictId.foundry, 4, 90000.0, 220.0, 0.8, 1.0, 80.0),
        (DistrictId.crownHill, 5, 450_000.0, 650.0, 1.8, 1.7, 70.0),
    ])
    func districts(_ id: DistrictId, chapter: Int, clean: Double, influence: Double, police: Double, price: Double, rivals: Double) {
        let d = Content.district(id)
        #expect(d.unlockChapter == chapter)
        #expect(d.unlockClean == clean)
        #expect(d.unlockInfluence == influence)
        #expect(d.police == police)
        #expect(d.priceMod == price)
        #expect(d.startRival == rivals)
        #expect(Content.front(d.front).district == id, "each district hosts exactly its own front")
    }

    @Test("North Quay routes run at ×1.4")
    func docksRouteBonus() {
        #expect(Content.district(.docks).routeMod == 1.4)
    }

    @Test("Five laundering fronts", arguments: [
        (FrontId.laundromat, Cost(dirty: 120), 1.5, 0.30, 0.25, 1.0),
        (FrontId.taxi, Cost(clean: 4000), 7.0, 0.22, 0.30, 4.0),
        (FrontId.nightclub, Cost(clean: 30000), 32.0, 0.15, 0.60, 10.0),
        (FrontId.construction, Cost(clean: 150_000), 120.0, 0.25, 0.15, 40.0),
        (FrontId.gallery, Cost(clean: 700_000), 450.0, 0.10, 0.35, 90.0),
    ])
    func fronts(_ id: FrontId, price: Cost, capacity: Double, fee: Double, risk: Double, cover: Double) {
        let f = Content.front(id)
        #expect(f.buy == price)
        #expect(f.capacity == capacity)
        #expect(f.fee == fee)
        #expect(f.risk == risk)
        #expect(f.cover == cover)
    }

    @Test("Twelve named crew candidates: a regular and a veteran for each of six roles")
    func crewRoster() {
        #expect(Content.crew.count == 12)
        #expect(Set(Content.crew.map(\.id)).count == 12)
        #expect(Set(Content.crew.map(\.name)).count == 12)
        for role in CrewRole.allCases {
            let members = Content.crew.filter { $0.role == role }
            #expect(members.count == 2)
            #expect(Set(members.map(\.tier)) == [1, 2])
            let veteran = members.first { $0.tier == 2 }
            #expect(veteran?.basePower == 1.7)
        }
    }

    @Test("Five improvement branches, four nodes each, with a real tier-2 choice")
    func improvementTree() {
        #expect(UpgradeId.allCases.count == 20)
        for b in UpgradeBranch.allCases {
            let nodes = UpgradeId.inBranch(b)
            #expect(nodes.count == 4)
            #expect(nodes.filter { $0.tier == 1 }.count == 1)
            #expect(nodes.filter { $0.tier == 3 }.count == 1)
            let pair = nodes.filter { $0.tier == 2 }
            #expect(pair.count == 2)
            #expect(pair[0].exclusive == pair[1] && pair[1].exclusive == pair[0])
        }
        #expect(Content.upgradeCost(.bikeCouriers) == Cost(clean: 1500))
        #expect(Content.upgradeCost(.deliveryVans) == Cost(clean: 25000, influence: 40))
        #expect(Content.upgradeCost(.distributionHub) == Cost(clean: 200_000, influence: 150))
        #expect([1, 2, 3].map { tier in Content.upgradeAvailableChapter(UpgradeId.allCases.first { $0.tier == tier }!) } == [1, 3, 4])
    }

    @Test("Fifteen authored events, each with a free choice and probabilities that sum to one", arguments: EventId.allCases)
    func eventContract(_ e: EventId) {
        let p = PendingEvent(event: e, district: .cellars, unit: 100, cleanUnit: 50, influenceUnit: 10, createdAt: 0)
        let choices = Events.choices(p)
        #expect(choices.count >= 2)
        #expect(choices.contains { $0.cost.isFree && $0.requiresRole == nil }, "every event offers at least one free choice")
        for c in choices {
            let total = c.outcomes.reduce(0) { $0 + $1.chance }
            #expect(abs(total - 1) < 1e-9, "\(e) \(c.key) outcome chances sum to \(total)")
        }
        #expect(Set(choices.map(\.key)).count == choices.count)
    }

    @Test("Event roster size")
    func eventCount() { #expect(EventId.allCases.count == 15) }

    @Test("Six chapters with the documented objectives and rewards")
    func chapters() {
        #expect(Content.objectives(chapter: 1) == [.earnDirty(3000), .lineLevels(.glimmer, 6), .crewCount(2), .launder(1500)])
        #expect(Content.objectives(chapter: 2) == [.unlockDistrict(.docks), .ownLine(.cinder), .control(.docks, 55), .ownFront(.taxi)])
        #expect(Content.objectives(chapter: 3) == [.unlockDistrict(.neonMile), .ownLine(.velvet), .ownFront(.nightclub), .upgrades(3), .launder(60000)])
        #expect(Content.objectives(chapter: 4) == [.unlockDistrict(.foundry), .control(.foundry, 60), .crewCount(5), .ownFront(.construction), .influenceHeld(400)])
        #expect(Content.objectives(chapter: 5) == [.unlockDistrict(.crownHill), .ownLine(.halo), .ownFront(.gallery), .control(.crownHill, 50)])
        #expect(Content.objectives(chapter: 6).isEmpty)
        #expect(Content.chapterReward(1) == Cost(dirty: 1000))
        #expect(Content.chapterReward(2) == Cost(clean: 3000, influence: 20))
        #expect(Content.chapterReward(3) == Cost(clean: 20000, influence: 60))
        #expect(Content.chapterReward(4) == Cost(clean: 150_000, influence: 120))
        #expect(Content.chapterReward(5) == Cost(clean: 400_000, influence: 200))
    }

    @Test("Legacy perks and their rank limits")
    func perks() {
        #expect(PerkId.allCases.count == 6)
        #expect(PerkId.allCases.filter { $0 != .knownName }.allSatisfy { $0.maxRank == 5 })
        #expect(PerkId.knownName.maxRank == 3)
        #expect((0..<5).map { Content.perkCost(currentRank: $0) } == [1, 2, 3, 4, 5])
    }

    @Test("Seven-step briefing")
    func briefingSteps() {
        #expect(TutorialStep.allCases.filter { $0 != .done }.count == 7)
    }
}
