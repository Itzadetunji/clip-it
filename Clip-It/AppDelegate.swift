//
//  AppDelegate.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  static var orientationLock: UIInterfaceOrientationMask = .portrait

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    Self.orientationLock
  }

  /// Applies portrait orientation lock. Use instead of deprecated attemptRotationToDeviceOrientation.
  static func applyPortraitOrientation() {
    orientationLock = .portrait
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first(where: { $0.isKeyWindow }),
          let rootViewController = window.rootViewController else { return }
    rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
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
