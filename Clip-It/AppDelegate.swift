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
}
