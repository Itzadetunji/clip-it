//
//  ClipItApp.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Combine
import RevenueCat
import SwiftData
import SwiftUI

@main
struct ClipItApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  private let broadcastStateService = BroadcastStateService()
  @StateObject private var subscriptionViewModel = SubscriptionViewModel()

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Item.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  init() {
    let apiKey =
      (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !apiKey.isEmpty {
      Purchases.configure(withAPIKey: apiKey)
    } else {
      NSLog("RevenueCat key missing. Set REVENUECAT_API_KEY in Config.xcconfig.")
    }

    // First app load cleanup:
    // if recording is currently inactive, clear old temporary clip files.
    broadcastStateService.removeSavedClipsIfNotRecording()
    NotificationService.requestAuthorization()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
      }
      .navigationViewStyle(StackNavigationViewStyle())
      .environmentObject(subscriptionViewModel)
    }
    .modelContainer(sharedModelContainer)
  }
}
