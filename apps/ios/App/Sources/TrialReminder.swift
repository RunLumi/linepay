import Foundation
import UserNotifications

/// One optional, on-device reminder before a free trial turns into a paid year. It is scheduled
/// only after the worker starts a trial with the reminder switched on and allows notifications.
/// No data leaves the iPhone; LinePaycheck has no server to send it to.
@MainActor
enum TrialReminder {
    static let identifier = "linepay.trial-reminder"
    static let leadDays = 2

    /// The day the reminder fires: `leadDays` before the trial ends.
    static func reminderDate(trialEnds: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .day, value: -leadDays, to: trialEnds)
    }

    /// Asks for permission if it has not been decided, then schedules the reminder. Returns the
    /// date it will fire, or nil when notifications are off or the trial ends too soon to warn.
    static func schedule(trialEnds: Date, renewalPrice: String, now: Date = .now) async -> Date? {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true,
            let fire = reminderDate(trialEnds: trialEnds), fire > now.addingTimeInterval(60)
        else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "Your LinePaycheck Pro trial ends in \(leadDays) days"
        content.body =
            "Your annual plan (\(renewalPrice)) starts \(trialEnds.formatted(date: .abbreviated, time: .omitted)). To avoid being charged, cancel at least 24 hours before in Settings > your name > Subscriptions."
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(
            identifier: identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(request)
            return fire
        } catch {
            LinePayLog.storeKit.error("Trial reminder could not be scheduled")
            return nil
        }
    }

    /// Removes a pending reminder once it no longer applies: the trial was cancelled or ended.
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier])
    }
}
