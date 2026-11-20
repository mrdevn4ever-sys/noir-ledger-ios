import Foundation
import Observation
import StoreKit

/// In-app purchases through StoreKit 2. This type only talks to the App Store and verifies transactions; what a
/// purchase is worth is decided by `StoreItem.grant` and booked by the game through `deliver`, which writes the grant
/// and the transaction id to the save together. A transaction is finished only after that write succeeded, so an
/// interrupted or failed booking is delivered again by the App Store and booked exactly once.
@MainActor
@Observable
final class StoreService {
    enum Status: Equatable {
        case loading, ready, unavailable
    }

    enum Outcome: Equatable {
        /// Paid and booked in the save.
        case purchased
        case pending, cancelled, failed
        /// Paid, but the game could not save it yet: the transaction stays open and is booked on the next attempt.
        case notBooked
    }

    /// What to do with a verified transaction after asking the game.
    struct Settlement: Equatable {
        /// Tell the App Store it is done (never before the booking is on disk).
        let finish: Bool
        /// The purchase is in the save (now or from an earlier delivery).
        let booked: Bool
    }

    private(set) var status: Status = .loading
    private(set) var prices: [StoreItem: String] = [:]
    /// The product whose purchase sheet is open.
    private(set) var purchasing: StoreItem?
    private(set) var restoring = false

    /// Books a verified purchase in the game together with its transaction id.
    @ObservationIgnored var deliver: (@MainActor (StoreItem, String) -> PurchaseBooking)?
    /// Moves transaction ids an earlier version kept outside the save into the save. Returns true once they are on disk.
    @ObservationIgnored var adoptDelivered: (@MainActor ([String]) -> Bool)?
    @ObservationIgnored private var products: [StoreItem: Product] = [:]
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults

    /// Where versions before the schema-2 save remembered delivered consumables. Read, never written again.
    static let legacyDeliveredKey = "store.deliveredTransactions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Starts listening for transactions, moves old delivery markers into the save, retries every unfinished
    /// transaction (without waiting for the catalogue), then loads the catalogue and the permanent purchases.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { [weak self] in
            self?.adoptLegacyMarkers()
            await self?.retryUnfinished()
            await self?.loadProducts()
            await self?.syncEntitlements()
        }
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: StoreItem.allCases.map(\.rawValue))
            var map: [StoreItem: Product] = [:]
            var labels: [StoreItem: String] = [:]
            for product in loaded {
                guard let item = StoreItem(rawValue: product.id) else { continue }
                map[item] = product
                labels[item] = product.displayPrice
            }
            products = map
            prices = labels
            status = map.isEmpty ? .unavailable : .ready
        } catch {
            status = .unavailable
        }
    }

    func available(_ item: StoreItem) -> Bool { products[item] != nil }

    func purchase(_ item: StoreItem) async -> Outcome {
        guard let product = products[item], purchasing == nil else { return .failed }
        purchasing = item
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified = result else { return .failed }
                return await handle(result) ? .purchased : .notBooked
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Asks the App Store for this account's purchases and books the permanent ones again.
    func restore() async {
        restoring = true
        defer { restoring = false }
        try? await AppStore.sync()
        await syncEntitlements()
    }

    /// Books every permanent product the account owns (a transaction already in the save is not granted again).
    func syncEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  let item = StoreItem(rawValue: transaction.productID), !item.isConsumable else { continue }
            _ = deliver?(item, String(transaction.id))
        }
    }

    /// Transactions that were paid but never finished (a crash, a failed save): booked now, at most once.
    func retryUnfinished() async {
        for await result in Transaction.unfinished {
            await handle(result)
        }
    }

    /// Returns whether the purchase is booked in the save.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else { return false }
        let outcome = settle(productID: transaction.productID, transactionID: String(transaction.id),
                             revoked: transaction.revocationDate != nil)
        if outcome.finish { await transaction.finish() }
        return outcome.booked
    }

    /// The decision for one verified transaction, separate from the App Store so it can be tested with plain values.
    func settle(productID: String, transactionID: String, revoked: Bool) -> Settlement {
        guard let item = StoreItem(rawValue: productID) else { return Settlement(finish: true, booked: false) }
        if revoked { return Settlement(finish: true, booked: false) }
        if item.isConsumable && legacyDelivered(transactionID) {
            // Booked by an earlier version; finish only once the id is also in the save.
            let adopted = adoptDelivered?([transactionID]) ?? false
            return Settlement(finish: adopted, booked: true)
        }
        switch deliver?(item, transactionID) ?? .notBooked {
        case .booked, .alreadyBooked: return Settlement(finish: true, booked: true)
        case .notBooked: return Settlement(finish: false, booked: false)
        }
    }

    /// Copies the old markers into the save (they stay readable in the defaults as a fallback).
    func adoptLegacyMarkers() {
        let ids = defaults.stringArray(forKey: Self.legacyDeliveredKey) ?? []
        guard !ids.isEmpty else { return }
        _ = adoptDelivered?(ids)
    }

    private func legacyDelivered(_ id: String) -> Bool {
        (defaults.stringArray(forKey: Self.legacyDeliveredKey) ?? []).contains(id)
    }
}
