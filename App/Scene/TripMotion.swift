/// The part of a simulation trip that the scene draws between ticks.
struct TripMotion: Equatable {
    var left: Double
    var duration: Double
    var loaded: Bool

    func phase(after seconds: Double) -> Double {
        min(1, max(0, 1 - max(0, left - seconds) / max(0.1, duration)))
    }
}

struct SceneTickWindow {
    let interval: Double
    let timeScale: Double

    private var maxAge: Double { interval * 1.5 }

    func seconds(forAge age: Double) -> Double {
        let real = min(maxAge, max(0, age))
        return timeScale > 1 ? real * timeScale : real
    }

    /// Park only if even the furthest interpolated frame still belongs to the lift.
    /// The next simulation snapshot reevaluates this without a running van timeline.
    func vanNeedsFrames(for trip: TripMotion?, animating: Bool) -> Bool {
        guard animating, let trip else { return false }
        return trip.phase(after: seconds(forAge: maxAge)) >= 0.5
    }
}
