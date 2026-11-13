import Foundation
import Observation
import UIKit

enum AdOutcome: Sendable, Equatable {
    /// The video ran to the end: pay the reward.
    case rewarded
    /// The player closed the video early: no reward.
    case dismissed
    /// No video could be shown.
    case unavailable
}

/// A source of rewarded sponsor videos.
@MainActor
protocol AdProvider: AnyObject {
    var onReadyChange: (@MainActor (Bool) -> Void)? { get set }
    /// Whether the player can open the advertising privacy choices.
    var hasPrivacyOptions: Bool { get }
    func start()
    func show(_ completion: @escaping @MainActor (AdOutcome) -> Void)
    func presentPrivacyOptions()
}

/// Rewarded sponsor videos. The game only ever asks "is a video ready" and "show one"; which network serves it is
/// decided here. Without the advertising SDK in the build, no video is ever ready and the game says so.
@MainActor
@Observable
final class AdService {
    private(set) var ready = false
    private(set) var showing = false
    @ObservationIgnored private let provider: AdProvider?

    init(provider: AdProvider?) {
        self.provider = provider
        provider?.onReadyChange = { [weak self] ready in self?.ready = ready }
    }

    /// The provider for this build: an instant stand-in for automated tests, otherwise the advertising SDK.
    static func makeDefault() -> AdService {
        #if NOIR_QA
        if ProcessInfo.processInfo.arguments.contains("-qa-ads") { return AdService(provider: InstantAdProvider()) }
        // Automated runs never start the advertising SDK: its consent form is a web view that covers the screen.
        if Router.isAutomatedRun { return AdService(provider: nil) }
        #endif
        #if canImport(GoogleMobileAds)
        return AdService(provider: AdMobProvider())
        #else
        return AdService(provider: nil)
        #endif
    }

    var hasPrivacyOptions: Bool { provider?.hasPrivacyOptions ?? false }

    func start() { provider?.start() }

    func show(_ completion: @escaping @MainActor (AdOutcome) -> Void) {
        guard let provider, ready, !showing else {
            completion(.unavailable)
            return
        }
        showing = true
        provider.show { [weak self] outcome in
            self?.showing = false
            completion(outcome)
        }
    }

    func presentPrivacyOptions() { provider?.presentPrivacyOptions() }
}

/// The view controller a full-screen video is presented from.
@MainActor
enum Presenter {
    static var top: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

#if NOIR_QA
/// Debug/UI-test stand-in: every video "finishes" at once. Compiled out of Release.
@MainActor
final class InstantAdProvider: AdProvider {
    var onReadyChange: (@MainActor (Bool) -> Void)?
    var hasPrivacyOptions: Bool { false }
    func start() { onReadyChange?(true) }
    func show(_ completion: @escaping @MainActor (AdOutcome) -> Void) { completion(.rewarded) }
    func presentPrivacyOptions() {}
}
#endif
