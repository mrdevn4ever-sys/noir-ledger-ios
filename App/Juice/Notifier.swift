import Foundation
import NoirCore
import UserNotifications

/// Local reminders, scheduled when the app goes to the background and removed when it returns. Nothing is sent to
/// a server: the notifications are computed from the save on the device.
@MainActor
final class Notifier {
    private struct Reminder: Sendable {
        let id: String
        let title: String
        let body: String
        let seconds: Double
    }

    private static let ids = ["noir.offlineFull", "noir.boostOver", "noir.daily"]
    private static let askedKey = "notifier.asked"

    /// Schedules the reminders for the state the player is leaving behind.
    func schedule(state: GameState, today: Int, enabled: Bool, t: L10n) {
        guard enabled, state.campaign.tutorial == .done else { return }
        var reminders: [Reminder] = []
        let cap = Double(Idle.offlineCapSeconds(state))
        reminders.append(Reminder(id: Self.ids[0], title: t("notif_offline_t"), body: t("notif_offline_b", t.duration(cap)), seconds: cap))
        if state.meta.boostSeconds > 300 {
            reminders.append(Reminder(id: Self.ids[1], title: t("notif_boost_t"), body: t("notif_boost_b"), seconds: state.meta.boostSeconds))
        }
        if state.meta.dailyLastDay >= today {
            // Tomorrow's reward: remind 20 hours after leaving, so it never fires in the same evening.
            reminders.append(Reminder(id: Self.ids[2], title: t("notif_daily_t"), body: t("notif_daily_b"), seconds: 20 * 3600))
        }
        let pending = reminders
        Task.detached { await Self.post(pending) }
    }

    /// Removes reminders that are no longer true now that the player is back.
    func clear() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.ids)
        center.removeDeliveredNotifications(withIdentifiers: Self.ids)
        center.setBadgeCount(0) { _ in }
    }

    private nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// Asks for permission once, when the first reminder would actually be useful.
    private nonisolated static func authorize() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: askedKey) { return false }
            defaults.set(true, forKey: askedKey)
            return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    private nonisolated static func post(_ reminders: [Reminder]) async {
        guard await authorize() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, reminder.seconds), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
