import Foundation

/// The one thing worth doing first after coming back, always something the player can do right now.
public enum ReturnAdvice: Sendable, Equatable {
    /// Hire the missing lead of a workshop (affordable).
    case hireLead(Good)
    /// Hire the dispatcher (affordable).
    case hireDispatcher
    /// The whole chain runs on its own: the station that lifts its bottleneck (affordable).
    case upgrade(Station)
    /// Crates wait on a shelf and nobody drives: send the van by hand.
    case sendVan
    /// A workshop without a lead stands still with room on its shelf: start a cycle by hand.
    case startBench(Good)

    /// The player action that carries the advice out (only ever on the player's tap).
    public var action: FlowAction {
        switch self {
        case .hireLead(let g): .hireLead(g)
        case .hireDispatcher: .hireDispatcher
        case .upgrade(let st): .upgrade(st, 1)
        case .sendVan: .tapFleet
        case .startBench(let g): .tapBench(g)
        }
    }
}

extension Flow {

    /// The station that would lift a bottleneck, if any.
    public static func fixStation(_ neck: Bottleneck, good: Good, state s: FlowState) -> Station? {
        switch neck {
        case .bench: .bench(good)
        case .fleet: .fleet
        case .shelf: .shelf(good)
        case .demand: contacts(s, of: good).first.map { Station.contact($0) }
        case .balanced: nil
        }
    }

    /// The next missing person of the chain and the price: workshop leads first (they make the goods), then the
    /// dispatcher (he sells them). nil when everyone is hired.
    public static func nextHire(_ s: FlowState) -> (advice: ReturnAdvice, cost: Double)? {
        for g in s.openGoods where s.workshop(g)?.lead != true {
            return (.hireLead(g), FlowContent.good(g).leadCost)
        }
        return s.dispatcher ? nil : (.hireDispatcher, FlowContent.dispatcherCost)
    }

    /// What to do first after time away. Only a fully staffed chain is advised to upgrade (the forecast assumes every
    /// station runs); otherwise an affordable hire comes first, then the manual step that moves goods now. Never a
    /// step that would be rejected: while the van is on the road it is not suggested again.
    public static func returnAdvice(_ s: FlowState) -> ReturnAdvice? {
        guard s.start != nil else { return nil }
        func doable(_ a: ReturnAdvice) -> Bool { apply(s, a.action).isOK }
        if let hire = nextHire(s) {
            if s.cash + 1e-9 >= hire.cost, doable(hire.advice) { return hire.advice }
            if !s.dispatcher && s.trip == nil {
                let sent = apply(s, .tapFleet)
                if sent.isOK && sent.state.trip != nil { return .sendVan }
            }
            for g in s.openGoods {
                guard let w = s.workshop(g), !w.lead, w.cycle == nil, w.stock < shelfCapacity(s, g) - 1e-9 else { continue }
                if doable(.startBench(g)) { return .startBench(g) }
            }
            return nil
        }
        let f = forecast(s)
        for g in s.openGoods.reversed() {
            guard let gf = f.good(g), let st = fixStation(gf.bottleneck, good: g, state: s) else { continue }
            if cost(s, st, 1) <= s.cash + 1e-9, doable(.upgrade(st)) { return .upgrade(st) }
        }
        return nil
    }
}
