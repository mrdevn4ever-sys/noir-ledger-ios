import NoirCore

/// The information on the warning slip and the exact station its button opens. No clock, cash or live stock.
struct BottleneckTicket: Equatable, Sendable {
    let good: Good
    let neck: Bottleneck
    let production: Double
    let carried: Double
    let demand: Double
    let fix: Station

    /// A full shelf has priority; otherwise use the highest lost income as before. Keep the first equal score.
    static func current(_ state: FlowState, forecast: Forecast) -> Self? {
        guard state.counters.deliveries > 0 else { return nil }
        var ticket: Self?
        var best = -Double.infinity
        for good in state.openGoods {
            guard let row = forecast.good(good), let w = state.workshop(good),
                  let fix = Flow.fixStation(row.bottleneck, good: good, state: state) else { continue }
            let price = row.sold > 0 ? row.income / row.sold : 1
            let lost = max(0, max(row.production, row.demand) - row.sold) * price
            let full = w.stock >= Flow.shelfCapacity(state, good) - 1e-9
            let score = lost + (full ? 1e30 : 0)
            if ticket == nil || score > best {
                best = score
                ticket = Self(good: good, neck: row.bottleneck, production: row.production,
                              carried: row.carried, demand: row.demand, fix: fix)
            }
        }
        return ticket
    }
}
