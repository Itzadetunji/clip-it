//
//  BroadcastStateService.swift
//  Broadcast
//
//  Created by Cursor on 17/03/2026.
//

import Foundation

/// Shared state between the app process and the broadcast extension process.
/// We store lightweight flags in App Group UserDefaults.
struct BroadcastStateService {
  private static let appGroupID = "group.com.adetunji.Screen-Record"
  private static let isRecordingKey = "broadcast.isRecording"
  private static let saveLast10SecondsKey = "broadcast.saveLast10Seconds"
  private static let lastSaveErrorKey = "broadcast.lastSaveError"

  private let sharedDefaults: UserDefaults?

  init() {
    sharedDefaults = UserDefaults(suiteName: Self.appGroupID)
  }

  func setRecording(_ isRecording: Bool) {
    sharedDefaults?.set(isRecording, forKey: Self.isRecordingKey)
  }

  func isRecordingActive() -> Bool {
    sharedDefaults?.bool(forKey: Self.isRecordingKey) ?? false
  }

  /// Called by the app when the user taps Save.
  /// The extension watches this flag and performs the export/save flow.
  func requestSaveLast10Seconds() {
    sharedDefaults?.set(true, forKey: Self.saveLast10SecondsKey)
  }

  func shouldSaveLast10Seconds() -> Bool {
    sharedDefaults?.bool(forKey: Self.saveLast10SecondsKey) ?? false
  }

  func clearSaveRequest() {
    sharedDefaults?.set(false, forKey: Self.saveLast10SecondsKey)
  }

  func setLastSaveError(_ message: String?) {
    if let message {
      sharedDefaults?.set(message, forKey: Self.lastSaveErrorKey)
    } else {
      sharedDefaults?.removeObject(forKey: Self.lastSaveErrorKey)
    }
  }

  func getLastSaveError() -> String? {
    sharedDefaults?.string(forKey: Self.lastSaveErrorKey)
  }
}
