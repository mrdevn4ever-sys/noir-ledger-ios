#if canImport(GoogleMobileAds)
import Foundation
@preconcurrency import GoogleMobileAds
import UIKit
#if canImport(UserMessagingPlatform)
@preconcurrency import UserMessagingPlatform
#endif

/// Rewarded videos from Google AdMob (Google Mobile Ads SDK 11, User Messaging Platform 2 for the consent form).
///
/// The ad unit comes from the Info.plist key `NoirRewardedAdUnit`; the app id from `GADApplicationIdentifier`.
/// Both ship with Google's public test identifiers and must be replaced with the real ones before release.
/// Every SDK callback is taken as `@Sendable` and hops to the main actor itself, so it does not matter which queue
/// the SDK answers on.
private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value
}

@MainActor
final class AdMobProvider: NSObject, AdProvider {
    var onReadyChange: (@MainActor (Bool) -> Void)?
    private var ad: GADRewardedAd?
    private var loading = false
    private var started = false
    private var earned = false
    private var completion: (@MainActor (AdOutcome) -> Void)?
    private var retryDelay = 4.0

    private var unitId: String {
        (Bundle.main.object(forInfoDictionaryKey: "NoirRewardedAdUnit") as? String) ?? ""
    }

    var hasPrivacyOptions: Bool {
        #if canImport(UserMessagingPlatform)
        return UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
        #else
        return false
        #endif
    }

    func start() {
        guard !started else { return }
        started = true
        #if canImport(UserMessagingPlatform)
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: UMPRequestParameters()) { @Sendable [weak self] _ in
            Task { @MainActor in self?.presentConsentIfRequired() }
        }
        #else
        startSDK()
        #endif
    }

    #if canImport(UserMessagingPlatform)
    private func presentConsentIfRequired() {
        guard let controller = Presenter.top else {
            startSDK()
            return
        }
        UMPConsentForm.loadAndPresentIfRequired(from: controller) { @Sendable [weak self] _ in
            Task { @MainActor in self?.startSDK() }
        }
    }
    #endif

    private func startSDK() {
        #if canImport(UserMessagingPlatform)
        guard UMPConsentInformation.sharedInstance.canRequestAds else { return }
        #endif
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        load()
    }

    private func load() {
        guard !loading, ad == nil, !unitId.isEmpty else { return }
        loading = true
        GADRewardedAd.load(withAdUnitID: unitId, request: GADRequest()) { @Sendable [weak self] loaded, _ in
            let box = Unchecked(value: loaded)
            Task { @MainActor in self?.finishLoad(box.value) }
        }
    }

    private func finishLoad(_ loaded: GADRewardedAd?) {
        loading = false
        ad = loaded
        loaded?.fullScreenContentDelegate = self
        onReadyChange?(loaded != nil)
        if loaded == nil {
            // No fill or no connection: try again later, backing off to at most two minutes.
            let delay = retryDelay
            retryDelay = min(120, retryDelay * 2)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                self?.load()
            }
        } else {
            retryDelay = 4
        }
    }

    func show(_ completion: @escaping @MainActor (AdOutcome) -> Void) {
        guard let ad, let controller = Presenter.top else {
            completion(.unavailable)
            return
        }
        self.completion = completion
        earned = false
        ad.present(fromRootViewController: controller) { @Sendable [weak self] in
            Task { @MainActor in self?.earned = true }
        }
    }

    private func finish(_ outcome: AdOutcome) {
        ad = nil
        onReadyChange?(false)
        let done = completion
        completion = nil
        done?(outcome)
        load()
    }

    func presentPrivacyOptions() {
        #if canImport(UserMessagingPlatform)
        guard let controller = Presenter.top else { return }
        UMPConsentForm.presentPrivacyOptionsForm(from: controller) { @Sendable _ in }
        #endif
    }
}

extension AdMobProvider: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in self.finish(self.earned ? .rewarded : .dismissed) }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finish(.unavailable) }
    }
}
#endif
