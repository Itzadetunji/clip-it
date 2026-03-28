//
//  RevenueCatBootstrap.swift
//  Clip-It
//

import Foundation
import RevenueCat

enum RevenueCatBootstrap {
  /// Call once at launch after the main bundle (and merged Info.plist) are available.
  static func configureIfNeeded() {
    guard !Purchases.isConfigured else { return }

    let apiKey =
      (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !apiKey.isEmpty else {
      NSLog(
        "RevenueCat: REVENUECAT_API_KEY is empty. Set it in Config.xcconfig, clean build folder, then build again."
      )
      return
    }

    Purchases.configure(withAPIKey: apiKey)
  }
}
