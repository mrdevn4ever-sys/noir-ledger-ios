import NoirCore
import Testing
@testable import NoirLedger

@Suite("The bottleneck slip follows the station, not the clock")
struct BottleneckTicketTests {
    private func cellar() -> FlowState {
        var s = Flow.newGame(seed: 41, nowMs: 1_000)
        s = Flow.apply(s, .choose(.cashbox)).state
        s.updateWorkshop(.weed) { $0.lead = true; $0.bench = 2; $0.stock = 20 }
        return s
    }

    @Test("No warning before the first delivery; the guide's full cellar links to its van")
    func destination() throws {
        var s = cellar()
        #expect(BottleneckTicket.current(s, forecast: Flow.forecast(s)) == nil)
        s.counters.deliveries = 3
        let f = Flow.forecast(s)
        let ticket = try #require(BottleneckTicket.current(s, forecast: f))
        let row = try #require(f.good(.weed))
        #expect(ticket.good == .weed && ticket.neck == .fleet && ticket.fix == .fleet)
        #expect(ticket.production == row.production && ticket.carried == row.carried && ticket.demand == row.demand)
    }

    @Test("Clock and wallet changes do not invalidate the slip; expanding the limiting station does")
    func changesThatMatter() throws {
        var s = cellar(); s.counters.deliveries = 1
        let original = try #require(BottleneckTicket.current(s, forecast: Flow.forecast(s)))
        s.cash += 10_000; s.time += 1
        #expect(BottleneckTicket.current(s, forecast: Flow.forecast(s)) == original)
        let result = Flow.apply(s, .upgrade(.fleet, 1))
        try #require(result.isOK)
        #expect(BottleneckTicket.current(result.state, forecast: Flow.forecast(result.state)) != original)
    }
}
