//
//  AppDelegate.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  static var orientationLock: UIInterfaceOrientationMask = .portrait

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
}
