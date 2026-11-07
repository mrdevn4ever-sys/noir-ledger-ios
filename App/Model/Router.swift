import NoirCore
import Observation
import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case ledger, ops, city, money, network

    var titleKey: String {
        switch self {
        case .ledger: "nav_ledger"
        case .ops: "nav_ops"
        case .city: "nav_city"
        case .money: "nav_money"
        case .network: "nav_network"
        }
    }

    var symbol: String {
        switch self {
        case .ledger: "book.closed"
        case .ops: "gearshape.2"
        case .city: "map"
        case .money: "banknote"
        case .network: "person.3"
        }
    }

    /// Which section a briefing step is played on.
    static func forTutorial(_ step: TutorialStep) -> AppTab? {
        switch step {
        case .startLine, .stockUp: .ops
        case .openRoute, .earn: .city
        case .buyFront, .launder: .money
        case .heatBriefing: .ledger
        case .done: nil
        }
    }
}

enum Route: Hashable {
    case district(DistrictId)
    case finalOp
    case legacy
    case epilogue
}

enum NetworkSection: String, CaseIterable, Identifiable {
    case crew, improvements, legacy
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .crew: "tab_crew"
        case .improvements: "tab_upgrades"
        case .legacy: "tab_legacy"
        }
    }
}

/// UI navigation state shared by the tab roots (not persisted; the game state is).
@MainActor
@Observable
final class Router {
    var tab: AppTab = .ledger
    var ledgerPath: [Route] = []
    var cityPath: [Route] = []
    var networkPath: [Route] = []
    var networkSection: NetworkSection = .crew
    var showSettings = false
    var eventOpen = false

    /// "Show me" from the briefing coach: jump to where the current step is played.
    func showTutorialTarget(_ step: TutorialStep) {
        guard let target = AppTab.forTutorial(step) else { return }
        tab = target
        if step == .openRoute { cityPath = [.district(.cellars)] }
    }

    func openLegacy() {
        tab = .ledger
        ledgerPath = [.legacy]
    }

    func resetNavigation() {
        tab = .ledger
        ledgerPath = []
        cityPath = []
        networkPath = []
        networkSection = .crew
        eventOpen = false
    }
}
