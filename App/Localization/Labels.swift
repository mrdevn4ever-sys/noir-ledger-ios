import Foundation
import NoirCore

/// Maps engine identifiers to string-table keys. No player-facing text lives in the engine.
/// Every key returned here is verified against both languages by `LocalizationTests` and `scripts/check_l10n.py`.
enum Labels {
    static func product(_ p: ProductId) -> String {
        switch p {
        case .glimmer: "product_glimmer"
        case .cinder: "product_cinder"
        case .velvet: "product_velvet"
        case .halo: "product_halo"
        }
    }

    static func productDesc(_ p: ProductId) -> String {
        switch p {
        case .glimmer: "desc_glimmer"
        case .cinder: "desc_cinder"
        case .velvet: "desc_velvet"
        case .halo: "desc_halo"
        }
    }

    static func district(_ d: DistrictId) -> String {
        switch d {
        case .cellars: "district_cellars"
        case .docks: "district_docks"
        case .neonMile: "district_neon"
        case .foundry: "district_foundry"
        case .crownHill: "district_crown"
        }
    }

    static func districtDesc(_ d: DistrictId) -> String {
        switch d {
        case .cellars: "ddesc_cellars"
        case .docks: "ddesc_docks"
        case .neonMile: "ddesc_neon"
        case .foundry: "ddesc_foundry"
        case .crownHill: "ddesc_crown"
        }
    }

    static func districtSpecial(_ d: DistrictId) -> String {
        switch d {
        case .cellars: "dspecial_cellars"
        case .docks: "dspecial_docks"
        case .neonMile: "dspecial_neon"
        case .foundry: "dspecial_foundry"
        case .crownHill: "dspecial_crown"
        }
    }

    static func front(_ f: FrontId) -> String {
        switch f {
        case .laundromat: "front_laundromat"
        case .taxi: "front_taxi"
        case .nightclub: "front_nightclub"
        case .construction: "front_construction"
        case .gallery: "front_gallery"
        }
    }

    static func frontDesc(_ f: FrontId) -> String {
        switch f {
        case .laundromat: "fdesc_laundromat"
        case .taxi: "fdesc_taxi"
        case .nightclub: "fdesc_nightclub"
        case .construction: "fdesc_construction"
        case .gallery: "fdesc_gallery"
        }
    }

    static func role(_ r: CrewRole) -> String {
        switch r {
        case .foreman: "role_foreman"
        case .courier: "role_courier"
        case .enforcer: "role_enforcer"
        case .accountant: "role_accountant"
        case .lawyer: "role_lawyer"
        case .fixer: "role_fixer"
        }
    }

    static func roleEffect(_ r: CrewRole) -> String {
        switch r {
        case .foreman: "roleeff_foreman"
        case .courier: "roleeff_courier"
        case .enforcer: "roleeff_enforcer"
        case .accountant: "roleeff_accountant"
        case .lawyer: "roleeff_lawyer"
        case .fixer: "roleeff_fixer"
        }
    }

    static func trait(_ t: Trait) -> String {
        switch t {
        case .loyal: "trait_loyal"
        case .greedy: "trait_greedy"
        case .hothead: "trait_hothead"
        case .discreet: "trait_discreet"
        case .connected: "trait_connected"
        case .meticulous: "trait_meticulous"
        }
    }

    static func traitDesc(_ t: Trait) -> String {
        switch t {
        case .loyal: "traitd_loyal"
        case .greedy: "traitd_greedy"
        case .hothead: "traitd_hothead"
        case .discreet: "traitd_discreet"
        case .connected: "traitd_connected"
        case .meticulous: "traitd_meticulous"
        }
    }

    static func branch(_ b: UpgradeBranch) -> String {
        switch b {
        case .logistics: "branch_logistics"
        case .production: "branch_production"
        case .security: "branch_security"
        case .finance: "branch_finance"
        case .network: "branch_network"
        }
    }

    static func upgrade(_ u: UpgradeId) -> String { "up_" + u.rawValue.lowercased() }
    static func upgradeDesc(_ u: UpgradeId) -> String { "upd_" + u.rawValue.lowercased() }

    static func achievement(_ a: AchievementId) -> String { "ach_" + a.rawValue.lowercased() }

    /// What an achievement asks for, with its target filled in.
    static func achievementGoal(_ a: AchievementId, _ t: L10n) -> String {
        let target = Idle.achievementTarget(a)
        let count = Int(target)
        switch a {
        case .earn1, .earn2, .earn3, .earn4, .earn5: return t("achg_earn", t.money(target))
        case .clean1, .clean2, .clean3: return t("achg_clean", t.money(target))
        case .districts2, .districts5: return t("achg_districts", count)
        case .fronts3, .fronts5: return t("achg_fronts", count)
        case .crew3, .crew6: return t("achg_crew", count)
        case .allLines: return t("achg_lines")
        case .stage25, .stage50, .stage100: return t("achg_stage", count)
        case .survivor: return t("achg_survivor")
        case .raided: return t("achg_raided")
        case .decisions10: return t("achg_decisions", count)
        case .prestige1, .prestige5, .prestige10: return t("achg_prestige", count)
        case .win1, .win3: return t("achg_win", count)
        case .taps100, .taps2500: return t("achg_taps", count)
        }
    }

    static func perk(_ p: PerkId) -> String { "perk_" + p.rawValue.lowercased() }
    static func perkDesc(_ p: PerkId) -> String { "perkd_" + p.rawValue.lowercased() }

    static func lineStatus(_ s: LineStatus) -> String {
        switch s {
        case .idle: "line_status_idle"
        case .running: "line_status_running"
        case .storageFull: "line_status_full"
        case .noCash: "line_status_nocash"
        case .emergency: "line_status_emergency"
        }
    }

    static func track(_ t: LineTrack) -> String {
        switch t {
        case .capacity: "track_capacity"
        case .speed: "track_speed"
        case .quality: "track_quality"
        }
    }

    static func chapterTitle(_ c: Int) -> String { "ch_title_\(min(max(c, 0), 6))" }
    static func chapterIntro(_ c: Int) -> String { "ch_intro_\(min(max(c, 0), 6))" }

    static func error(_ e: ActionError) -> String {
        switch e {
        case .notAffordable: "err_not_affordable"
        case .locked: "err_locked"
        case .maxLevel: "err_max"
        case .tutorial: "err_tutorial"
        case .roleOccupied: "err_role"
        case .cooldown: "err_cooldown"
        case .invalid: "err_invalid"
        case .requirements: "err_requirements"
        }
    }

    static func phaseTitle(_ p: FinalPhase) -> String {
        switch p {
        case .cityHall: "fp_city_hall_t"
        case .convoy: "fp_convoy_t"
        case .ledger: "fp_ledger_t"
        }
    }

    static func phaseBody(_ p: FinalPhase) -> String {
        switch p {
        case .cityHall: "fp_city_hall_b"
        case .convoy: "fp_convoy_b"
        case .ledger: "fp_ledger_b"
        }
    }

    static func finalChoice(_ key: String) -> String { "fc_" + key }

    private static func eventStem(_ e: EventId) -> String { "ev_" + e.rawValue.lowercased() }
    static func eventTitle(_ e: EventId) -> String { eventStem(e) + "_t" }
    static func eventBody(_ e: EventId) -> String { eventStem(e) + "_b" }
    static func eventChoice(_ e: EventId, _ key: String) -> String { eventStem(e) + "_" + key }

    static func tutorialTitle(_ s: TutorialStep) -> String { "tut_" + tutorialStem(s) + "_t" }
    static func tutorialBody(_ s: TutorialStep) -> String { "tut_" + tutorialStem(s) + "_b" }
    private static func tutorialStem(_ s: TutorialStep) -> String {
        switch s {
        case .startLine: "start_line"
        case .stockUp: "stock_up"
        case .openRoute: "open_route"
        case .earn: "earn"
        case .buyFront: "buy_front"
        case .launder: "launder"
        case .heatBriefing, .done: "heat"
        }
    }

    static func prologueChoice(_ c: PrologueChoice) -> (title: String, detail: String) {
        switch c {
        case .cashBox: ("pro_choice_cash", "pro_choice_cash_d")
        case .contacts: ("pro_choice_contacts", "pro_choice_contacts_d")
        case .tools: ("pro_choice_tools", "pro_choice_tools_d")
        }
    }

    static func requirement(_ k: FinalRequirement.Kind) -> String {
        switch k {
        case .control: "req_control"
        case .clean: "req_clean"
        case .influence: "req_influence"
        case .heat: "req_heat"
        }
    }

    /// Stable "account number" for a business, so the books read like books.
    static func accountNumber(_ key: String) -> String {
        var h: UInt32 = 2_166_136_261
        for b in key.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return String(1000 + Int(h % 9000))
    }
}
