import Foundation

// Compile the producer against the pinned old core and the reader against the candidate. No tester data.
@main
struct SchemaOneProbe {
    static let clock: Int64 = 1_700_123_456_789

    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let mode = CommandLine.arguments[1]
        for scenario in ["unopened", "working", "unattended"] {
            let dir = root.appendingPathComponent(scenario, isDirectory: true)
            let disk = FlowSaveStore(directory: dir)
            if mode == "produce" {
                precondition(flowSchemaVersion == 1)
                var s = Flow.newGame(seed: 981, nowMs: clock)
                if scenario != "unopened" {
                    s = Flow.apply(s, .choose(.tools)).state
                    s.cash = 20_000
                    s.meta.favors = 73
                    s.meta.premium = true
                    s.meta.noAds = true
                    s.meta.starterBought = true
                    s.meta.dailyClaims = 4
                    s.meta.dailyLastDay = 21_000
                    for action: FlowAction in [.hireLead(.weed), .upgrade(.fleet, 1), .hireDispatcher] {
                        let result = Flow.apply(s, action)
                        precondition(result.isOK)
                        s = result.state
                    }
                    // Reach an actual sale, then accept an offer while a second trip is on its way.
                    for _ in 0..<400 {
                        Flow.advance(&s, seconds: 0.25, offline: false)
                        if s.counters.deliveries > 0 && s.trip != nil && !s.offers.isEmpty { break }
                    }
                    precondition(s.counters.deliveries > 0 && s.trip != nil && !s.offers.isEmpty)
                    let accepted = Flow.apply(s, .accept(s.offers[0].id))
                    precondition(accepted.isOK)
                    s = accepted.state
                    precondition(!s.orders.isEmpty && !s.ledger.isEmpty)
                    if scenario == "unattended" {
                        s = Flow.applyOffline(s, nowMs: clock + 240_000)
                        precondition(s.welcome != nil)
                    }
                }
                try disk.write(s, savedAtMs: s.lastWallClockMs)
            } else {
                precondition(mode == "consume")
                guard case let .loaded(s, backup) = disk.load(), !backup else { fatalError("Not loaded from primary: \(scenario)") }
                try disk.write(s, savedAtMs: s.lastWallClockMs)
                guard case let .loaded(again, restored) = disk.load(), !restored, again == s else { fatalError("Relaunch changed \(scenario)") }
            }
            print("SAVE_PROBE \(mode) \(scenario) schema=\(flowSchemaVersion)")
        }
    }
}
