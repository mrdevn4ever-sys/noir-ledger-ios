import NoirCore
import Testing
@testable import NoirLedger

@Suite("Room artwork follows the actual bench upgrade")
struct FloorPrewarmTests {
    @Test("Only the current stage is requested on entry, including at every visual milestone")
    func currentFloors() {
        var state = Flow.newGame(seed: 3, nowMs: 0)
        for (level, stage) in [(1, 0), (9, 0), (10, 1), (24, 1), (25, 2), (49, 2), (50, 3),
                               (99, 3), (100, 4), (199, 4), (200, 5), (201, 5)] {
            for good in Good.allCases {
                var room = WorkshopState()
                room.bench = level
                state.workshops[good] = room
            }
            let floors = SceneArt.prewarmList(state).filter { $0.name.hasPrefix("Floor") }
            #expect(floors.count == Good.allCases.count * 3)
            for good in Good.allCases {
                let prefix = "Floor" + SceneArt.name(good) + String(stage)
                #expect(floors.contains { $0.name == prefix && $0.frames == 1 })
                #expect(floors.contains { $0.name == prefix + "Lit" && $0.frames == 1 })
                #expect(floors.contains { $0.name == prefix + "Run4" && $0.frames == 4 })
            }
        }
    }

    @Test("A bulk preview prepares the purchased look even when it skips a milestone")
    func bulkPreview() {
        let start = Flow.apply(Flow.newGame(seed: 3, nowMs: 0), .choose(.cashbox)).state
        let after = Flow.upgraded(start, .bench(.weed), 50)
        let preview = SceneArt.floorSheets(.weed, level: Flow.level(after, .bench(.weed)))
        #expect(preview.map(\.name) == ["FloorWeed3", "FloorWeed3Lit", "FloorWeed3Run4"])
        #expect(preview.map(\.frames) == [1, 1, 4])
        let names = Set(SceneArt.prewarmList(after).map(\.name))
        #expect(Set(preview.map(\.name)).isSubset(of: names))
    }
}
