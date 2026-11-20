import Testing
@testable import NoirLedger

@Suite("Parked van display clock")
struct ParkedVanTests {
    private let normal = SceneTickWindow(interval: 0.25, timeScale: 1)

    private func trip(left: Double) -> TripMotion {
        TripMotion(left: left, duration: 20, loaded: true)
    }

    @Test("No trip or lift-only work has no display clock")
    func parked() {
        #expect(!normal.vanNeedsFrames(for: nil, animating: true))
        #expect(!normal.vanNeedsFrames(for: trip(left: 20), animating: true))
        #expect(!normal.vanNeedsFrames(for: trip(left: 10.376), animating: true))
    }

    @Test("The clock wakes when interpolation can first reach departure")
    func departure() {
        let departing = trip(left: 10.375)
        #expect(departing.phase(after: 0) < 0.5)
        #expect(departing.phase(after: normal.seconds(forAge: 5)) == 0.5)
        #expect(normal.vanNeedsFrames(for: departing, animating: true))
        for left in [10.0, 7.5, 5.0, 2.5, 0.0] {
            #expect(normal.vanNeedsFrames(for: trip(left: left), animating: true))
        }
    }

    @Test("An accelerated clock uses a scaled interpolation window")
    func accelerated() {
        let fast = SceneTickWindow(interval: 0.25, timeScale: 8)
        #expect(fast.seconds(forAge: -1) == 0)
        #expect(fast.seconds(forAge: 5) == 3)
        #expect(!fast.vanNeedsFrames(for: trip(left: 13.001), animating: true))
        #expect(fast.vanNeedsFrames(for: trip(left: 13), animating: true))
        #expect(!normal.vanNeedsFrames(for: trip(left: 13), animating: true))
    }

    @Test("The scene animation gate wins even during travel")
    func sceneGate() {
        // Covered, scrolled away and Reduce Motion all arrive as animating == false.
        let fast = SceneTickWindow(interval: 0.25, timeScale: 8)
        for left in [13.0, 10.0, 7.5, 5.0, 2.5] {
            let moving = trip(left: left)
            #expect(!fast.vanNeedsFrames(for: moving, animating: false))
            #expect(fast.vanNeedsFrames(for: moving, animating: true))
        }
    }
}
