//
//  NotificationService.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import UserNotifications

/// Handles notification permission requests at app launch.
struct NotificationService {
  /// Requests authorization for alerts, badges, and sounds.
  /// Call this at app entry (e.g. in App init).
  static func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { _, _ in }
  }
}
