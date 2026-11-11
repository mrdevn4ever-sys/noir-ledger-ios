import Foundation
import Observation
import StoreKit

/// In-app purchases through StoreKit 2. This type only talks to the App Store and verifies transactions; what a
/// purchase is worth is decided by `StoreItem.grant` and booked by the game engine through `deliver`.
@MainActor
@Observable
final class StoreService {
    enum Status: Equatable {
        case loading, ready, unavailable
    }

    enum Outcome: Equatable {
        case purchased, pending, cancelled, failed
    }

    private(set) var status: Status = .loading
    private(set) var prices: [StoreItem: String] = [:]
    /// The product whose purchase sheet is open.
    private(set) var purchasing: StoreItem?
    private(set) var restoring = false

    /// Books a verified purchase in the game. Returns false while the game is not ready to take it.
    @ObservationIgnored var deliver: ((StoreItem) -> Bool)?
    @ObservationIgnored private var products: [StoreItem: Product] = [:]
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults

    private static let deliveredKey = "store.deliveredTransactions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Starts listening for transactions (purchases finished elsewhere, approvals, refunds) and loads the catalogue.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { [weak self] in
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
                await handle(result)
                if case .verified = result { return .purchased }
                return .failed
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

    /// Books every permanent product the account owns (idempotent in the engine).
    func syncEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  let item = StoreItem(rawValue: transaction.productID), !item.isConsumable else { continue }
            _ = deliver?(item)
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard let item = StoreItem(rawValue: transaction.productID) else {
            await transaction.finish()
            return
        }
        if transaction.revocationDate != nil {
            await transaction.finish()
            return
        }
        if item.isConsumable && wasDelivered(transaction.id) {
            await transaction.finish()
            return
        }
        // Finish only after the game has booked it, so an interrupted purchase is delivered on the next launch.
        guard deliver?(item) == true else { return }
        if item.isConsumable { markDelivered(transaction.id) }
        await transaction.finish()
    }

    private func wasDelivered(_ id: UInt64) -> Bool {
        (defaults.stringArray(forKey: Self.deliveredKey) ?? []).contains(String(id))
    }

    private func markDelivered(_ id: UInt64) {
        var list = defaults.stringArray(forKey: Self.deliveredKey) ?? []
        list.append(String(id))
        if list.count > 200 { list.removeFirst(list.count - 200) }
        defaults.set(list, forKey: Self.deliveredKey)
    }
}
