//
//  Screen_RecordApp.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import SwiftData
import SwiftUI

@main
struct Screen_RecordApp: App {
  private let broadcastStateService = BroadcastStateService()

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
    // First app load cleanup:
    // if recording is currently inactive, clear old temporary clip files.
    broadcastStateService.removeSavedClipsIfNotRecording()
  }

  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
      }
      .navigationViewStyle(StackNavigationViewStyle())
    }
    .modelContainer(sharedModelContainer)
  }
}
