import Testing
@testable import NoirLedger

@Suite("Workshop progress track")
struct CycleWidthsTests {
    @Test("The linear segments reproduce the previous draw at 120 Hz and at each bend")
    func matchesClock() {
        var worst = 0.0
        var count = 0
        for width in [0.0, 6, 7, 7.2, 155, 167, 170.75, 256] {
            for cycle in [0.0, 0.001, 0.045, 0.5, 0.999, 1] {
                for seconds in [0.05, 0.1, 2.5, 5, 8, 12] {
                    for scale in [0.25, 1.0, 2, 12, 100] {
                        let track = CycleWidths(cycle: cycle, seconds: seconds, width: width, interval: 0.25, timeScale: scale)
                        let stops = track.stops
                        let regular = (0...50).map { Double($0) / 120 }
                        let boundaries = stops.flatMap { [$0 - 1e-8, $0, $0 + 1e-8] }
                        for age in regular + boundaries + [-0.01, 0.375, 3] {
                            let elapsed = max(1, scale) * min(0.375, max(0, age))
                            let expected = max(7, width * min(1, cycle + elapsed / max(0.1, seconds)))
                            var value = track.value(at: track.duration)
                            if let i = stops.dropFirst().firstIndex(where: { $0 > age }) {
                                let a = stops[i - 1], b = stops[i]
                                let ratio = max(0, age - a) / (b - a)
                                value = track.value(at: a) * (1 - ratio) + track.value(at: b) * ratio
                            }
                            worst = max(worst, abs(value - expected))
                            count += 1
                        }
                    }
                }
            }
        }
        #expect(worst < 1e-9)
        #expect(count > 80_000)
        print("Cycle widths: \(count) comparisons, maximum deviation \(worst) pt")
    }
}
