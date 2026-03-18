//
//  SaveClipIntent.swift
//  ClipControls
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import AppIntents
import Foundation

/// App Intent that saves a clip when the Control Center button is tapped.
/// Uses the duration the user selected in the app (stored in UserDefaults).
struct StartClipIntent: AppIntent {
  static var title: LocalizedStringResource = "Start Recording"
  static var description = IntentDescription("Start Recording")

  func perform() async throws -> some IntentResult & OpensIntent {
    let url = URL(string: "clipit:startRecording")!
    return .result(opensIntent: OpenURLIntent(url))
  }
}
