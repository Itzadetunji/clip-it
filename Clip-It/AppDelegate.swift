//
//  AppDelegate.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    RevenueCatBootstrap.configureIfNeeded()
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Shows notifications when the app is in the foreground (e.g. when user taps Clip from in-app UI).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }
}
