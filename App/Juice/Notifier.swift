import Foundation
import NoirCore
import UserNotifications

/// Local reminders, scheduled when the app goes to the background and removed when it returns. Nothing is sent to
/// a server: the notifications are computed from the save on the device.
@MainActor
final class Notifier {
    private static let ids = ["noir.offlineFull", "noir.boostOver", "noir.daily"]
    private static let askedKey = "notifier.asked"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Asks for permission once, after the briefing, when the first reminder would actually be useful.
    private func authorize() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            if defaults.bool(forKey: Self.askedKey) { return false }
            defaults.set(true, forKey: Self.askedKey)
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Schedules the reminders for the state the player is leaving behind.
    func schedule(state: GameState, today: Int, enabled: Bool, t: L10n) {
        guard enabled, state.campaign.tutorial == .done else { return }
        var requests: [(id: String, title: String, body: String, seconds: Double)] = []
        let cap = Double(Idle.offlineCapSeconds(state))
        requests.append((Self.ids[0], t("notif_offline_t"), t("notif_offline_b", t.duration(cap)), cap))
        if state.meta.boostSeconds > 300 {
            requests.append((Self.ids[1], t("notif_boost_t"), t("notif_boost_b"), state.meta.boostSeconds))
        }
        if state.meta.dailyLastDay >= today {
            // Tomorrow's reward: remind 20 hours after leaving, so it never fires in the same evening.
            requests.append((Self.ids[2], t("notif_daily_t"), t("notif_daily_b"), 20 * 3600))
        }
        let pending = requests
        Task {
            guard await self.authorize() else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: Self.ids)
            for item in pending {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, item.seconds), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    /// Removes reminders that are no longer true now that the player is back.
    func clear() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.ids)
        center.removeDeliveredNotifications(withIdentifiers: Self.ids)
        center.setBadgeCount(0) { _ in }
    }
}
