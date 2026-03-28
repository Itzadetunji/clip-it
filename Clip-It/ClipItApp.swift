//
//  ClipItApp.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Combine
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    // RevenueCat is configured in AppDelegate so the main bundle / Info.plist are fully resolved.

    // First app load cleanup:
    // if recording is currently inactive, clear old temporary clip files.
    broadcastStateService.removeSavedClipsIfNotRecording()
    seedFreeWatermarkImageForExtension()
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

  /// Copies the bundled free watermark image into App Group storage so the extension can read it.
  private func seedFreeWatermarkImageForExtension() {
    #if canImport(UIKit)
    // Standalone asset so `UIImage(named:)` works reliably (App Icon set images are not always named images).
    let bundledImage =
      UIImage(named: "FreeWatermark")
      ?? ["Apple-1", "Apple"].compactMap { UIImage(named: $0) }.first

    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.adetunji.ClipIt"
      ),
      let image = bundledImage,
      let pngData = image.pngData()
    else { return }

    let watermarkDirectory = containerURL.appendingPathComponent("Watermark", isDirectory: true)
    if !FileManager.default.fileExists(atPath: watermarkDirectory.path) {
      try? FileManager.default.createDirectory(at: watermarkDirectory, withIntermediateDirectories: true)
    }

    let freeWatermarkURL = watermarkDirectory.appendingPathComponent("free-watermark.png", isDirectory: false)
    try? pngData.write(to: freeWatermarkURL, options: .atomic)
    #endif
  }
}
