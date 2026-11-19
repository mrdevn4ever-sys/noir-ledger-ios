import NoirCore
import SwiftUI
import UIKit

/// String-table keys for the 4.0 content. No player-facing text lives in the engine; every key returned here is
/// checked in both languages by `LocalizationTests`.
enum GoodText {
    static func name(_ g: Good) -> String { "good_" + g.rawValue.lowercased() }
    static func role(_ g: Good) -> String { "good_role_" + g.rawValue.lowercased() }
}

enum HintText {
    static func key(_ h: FlowHint) -> String { "l4_hint_" + h.rawValue }
}

enum NeckText {
    static func key(_ b: Bottleneck) -> String { "l4_neck_" + b.rawValue }
}

enum StartText {
    static func title(_ c: StartChoice) -> String { "l4_start_" + c.rawValue.lowercased() }
    static func desc(_ c: StartChoice) -> String { "l4_start_d_" + c.rawValue.lowercased() }
    static func effect(_ c: StartChoice) -> String { "l4_start_e_" + c.rawValue.lowercased() }
}

enum QuarterText {
    static func name(_ q: Quarter) -> String { "quarter_" + q.rawValue.lowercased() }
    static func desc(_ q: Quarter) -> String { "quarter_d_" + q.rawValue.lowercased() }

    /// Picture of the quarter (the old town uses the foundry plate until its own art arrives).
    static func art(_ q: Quarter) -> String {
        switch q {
        case .cellars: "DistrictCellars"
        case .oldTown: "DistrictFoundry"
        case .docks: "DistrictDocks"
        case .night: "DistrictNeon"
        case .crown: "DistrictCrown"
        }
    }
}

enum ContactText {
    static func name(_ id: String) -> String { "contact_" + id }
    static func desc(_ id: String) -> String { "contact_d_" + id }
}

enum ChapterText {
    static func title(_ n: Int) -> String { "l4_ch\(n)_title" }
    static func intro(_ n: Int) -> String { "l4_ch\(n)_intro" }
    static func outro(_ n: Int) -> String { "l4_ch\(n)_outro" }

    static func goal(_ goal: GoalDef, _ t: L10n) -> String {
        switch goal.kind {
        case .deliveries(let n): t("l4_g_deliveries", n)
        case .hireLead(let g): t("l4_g_lead", t(GoodText.name(g)))
        case .hireDispatcher: t("l4_g_dispatcher")
        case .orders(let n): t("l4_g_orders", n)
        case .earn(let x): t("l4_g_earn", t.money(x))
        case .unlockContact(let id): t("l4_g_contact", t(ContactText.name(id)))
        case .throughput(let g, let n): t("l4_g_flow", t.money(n), t(GoodText.name(g)))
        case .openGood(let g): t("l4_g_open", t(GoodText.name(g)))
        case .bigOrders(let n): t("l4_g_big", n)
        case .clubNight(let n): t("l4_g_club", t.money(n))
        case .trust(let contacts, let level): t("l4_g_trust", contacts, level)
        case .cityOrders(let n): t("l4_g_city", n)
        case .finale: t("l4_g_finale")
        }
    }
}

enum SpecialistText {
    static func crew(_ s: Specialist) -> String {
        switch s {
        case .okafor: "okafor"
        case .morgen: "morgen"
        case .sand: "sand"
        case .lind: "lind"
        case .kraus: "kraus"
        }
    }

    static func role(_ s: Specialist) -> String { "spec_" + s.rawValue.lowercased() }
    static func effect(_ s: Specialist) -> String { "spec_d_" + s.rawValue.lowercased() }
}

enum AbilityText {
    static func name(_ a: Ability) -> String { "ability_" + a.rawValue.lowercased() }
    static func desc(_ a: Ability) -> String { "ability_d_" + a.rawValue.lowercased() }
}

enum ChallengeText {
    static func name(_ c: ChallengeId) -> String { "challenge_" + c.rawValue.lowercased() }
    static func desc(_ c: ChallengeId) -> String { "challenge_d_" + c.rawValue.lowercased() }
    static func goal(_ c: ChallengeId, _ i: Int) -> String { "challenge_g_" + c.rawValue.lowercased() + "_\(i)" }
}

enum StationText {
    static func id(_ st: Station) -> String {
        switch st {
        case .bench(let g): "bench_" + g.rawValue
        case .shelf(let g): "shelf_" + g.rawValue
        case .fleet: "fleet"
        case .contact(let c): "contact_" + c
        }
    }

    static func title(_ st: Station, _ t: L10n) -> String {
        switch st {
        case .bench(let g): t("l4_bench_of", t(GoodText.name(g)))
        case .shelf(let g): t("l4_shelf_of", t(GoodText.name(g)))
        case .fleet: t("l4_fleet")
        case .contact(let c): t(ContactText.name(c))
        }
    }

    /// The station that would lift a bottleneck, if any.
    static func fix(_ neck: Bottleneck, good: Good, state: FlowState) -> Station? {
        switch neck {
        case .bench: return .bench(good)
        case .fleet: return .fleet
        case .shelf: return .shelf(good)
        case .demand:
            return Flow.contacts(state, of: good).first.map { .contact($0) }
        case .balanced: return nil
        }
    }

    /// Capacity of a station in its own unit, for the before/after line.
    static func capacity(_ st: Station, _ s: FlowState, _ t: L10n) -> String {
        switch st {
        case .bench(let g): t("l4_per_min_crates", t.money(Flow.benchRate(s, g) * 60))
        case .shelf(let g): t("l4_crates", t.money(Flow.shelfCapacity(s, g)))
        case .fleet: t("l4_per_trip", t.money(Flow.fleetCapacity(s)))
        case .contact(let c): t("l4_per_min_crates", t.money(Flow.contactAverageRate(s, c) * 60))
        }
    }
}

enum OrderText {
    static func kind(_ k: OrderKind) -> String { "order_kind_" + k.rawValue.lowercased() }

    static func items(_ offer: OrderOffer, _ t: L10n) -> String {
        Good.allCases.compactMap { g in
            offer.items[g].map { t("l4_items", t.money($0), t(GoodText.name(g))) }
        }.joined(separator: " · ")
    }
}
