/// A workshop snapshot in real seconds. The short track ends at the same cap as the lift and van.
struct CycleWidths: Equatable {
    let cycle: Double
    let seconds: Double
    let width: Double
    let interval: Double
    let timeScale: Double

    var duration: Double { interval * 1.5 }
    private var span: Double { max(0.1, seconds) }

    func value(at age: Double) -> Double {
        let elapsed = SceneTickWindow(interval: interval, timeScale: timeScale).seconds(forAge: age)
        return max(7, width * min(1, cycle + elapsed / span))
    }

    /// Times of the two possible bends: leaving the seven-point dot and reaching full width.
    /// A linear track through these points never stretches the rounded end caps.
    var stops: [Double] {
        var times = [0.0]
        if width > 7 {
            let realSpan = span / max(1, timeScale)
            for edge in [7 / width, 1] {
                let t = (edge - cycle) * realSpan
                if t > times[times.count - 1], t < duration { times.append(t) }
            }
        }
        times.append(duration)
        return times
    }
}
