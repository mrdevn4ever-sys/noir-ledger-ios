import Foundation
import NoirCore

/// The store products of NOIR LEDGER. Identifiers must match App Store Connect and `StoreKit/Products.storekit`.
enum StoreItem: String, CaseIterable, Identifiable, Sendable {
    case starter = "io.puredevn.noirledger.starter"
    case premium = "io.puredevn.noirledger.premium2x"
    case noAds = "io.puredevn.noirledger.noads"
    case favorsSmall = "io.puredevn.noirledger.favors.small"
    case favorsMedium = "io.puredevn.noirledger.favors.medium"
    case favorsLarge = "io.puredevn.noirledger.favors.large"
    case favorsVault = "io.puredevn.noirledger.favors.vault"

    var id: String { rawValue }

    /// Non-consumables are restored from the App Store and booked at most once.
    var isConsumable: Bool {
        switch self {
        case .starter, .premium, .noAds: false
        case .favorsSmall, .favorsMedium, .favorsLarge, .favorsVault: true
        }
    }

    var grant: Grant {
        switch self {
        case .starter: .starter
        case .premium: .premium
        case .noAds: .noAds
        case .favorsSmall: .favors(80)
        case .favorsMedium: .favors(500)
        case .favorsLarge: .favors(1_200)
        case .favorsVault: .favors(3_000)
        }
    }

    var favors: Int {
        if case .favors(let n) = grant { return n }
        return 0
    }

    var titleKey: String {
        switch self {
        case .starter: "shop_starter_t"
        case .premium: "shop_premium_t"
        case .noAds: "shop_noads_t"
        case .favorsSmall: "shop_favors_small_t"
        case .favorsMedium: "shop_favors_medium_t"
        case .favorsLarge: "shop_favors_large_t"
        case .favorsVault: "shop_favors_vault_t"
        }
    }

    var symbol: String {
        switch self {
        case .starter: "shippingbox.fill"
        case .premium: "crown.fill"
        case .noAds: "bolt.fill"
        case .favorsSmall, .favorsMedium: "seal.fill"
        case .favorsLarge, .favorsVault: "lock.square.stack.fill"
        }
    }

    static let offers: [StoreItem] = [.starter, .premium, .noAds]
    static let favorPacks: [StoreItem] = [.favorsSmall, .favorsMedium, .favorsLarge, .favorsVault]

    /// Whether the player already owns this one-time product.
    func owned(_ meta: MetaState) -> Bool {
        switch self {
        case .starter: meta.starterBought
        case .premium: meta.premium
        case .noAds: meta.noAds
        default: false
        }
    }
}
