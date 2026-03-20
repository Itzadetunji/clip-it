//
//  LocalNotificationHelper.swift
//  Broadcast
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import UserNotifications

/// Sends local notifications from the Broadcast extension.
struct LocalNotificationHelper {
    /// Schedules a local notification with the given title and body.
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    ///   - delay: Seconds before the notification fires. Default 1.
    static func send(title: String, body: String, delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
