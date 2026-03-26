//
//  BroadcastStateService.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Foundation

/// Shared state between the app process and the broadcast extension process.
/// We store lightweight flags in App Group UserDefaults.
struct BroadcastStateService {
  private static let appGroupID = "group.com.adetunji.ClipIt"
  private static let isRecordingKey = "broadcast.isRecording"
  private static let saveLast10SecondsKey = "broadcast.saveLast10Seconds"
  private static let saveDurationSecondsKey = "broadcast.saveDurationSeconds"
  private static let lastSaveErrorKey = "broadcast.lastSaveError"
  private static let lastSaveSucceededKey = "broadcast.lastSaveSucceeded"
  private static let minSaveDurationSeconds = 10
  private static let maxSaveDurationSeconds = 120
  private static let defaultSaveDurationSeconds = 15

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

  /// User-selected clip duration in seconds. Supports free/pro durations up to 120 seconds.
  func getSaveDurationSeconds() -> Int {
    let value =
      sharedDefaults?.integer(forKey: Self.saveDurationSecondsKey) ?? 0
    return sanitizedDuration(from: value)
  }

  func setSaveDurationSeconds(_ seconds: Int) {
    sharedDefaults?.set(
      sanitizedDuration(from: seconds),
      forKey: Self.saveDurationSecondsKey
    )
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

  /// Extension sets this when save to Photos succeeds. App reads and clears it.
  func setLastSaveSucceeded(_ succeeded: Bool) {
    sharedDefaults?.set(succeeded, forKey: Self.lastSaveSucceededKey)
  }

  func getAndClearLastSaveSucceeded() -> Bool {
    let value =
      sharedDefaults?.bool(forKey: Self.lastSaveSucceededKey) ?? false
    sharedDefaults?.set(false, forKey: Self.lastSaveSucceededKey)
    return value
  }

  /// Removes all temporary 10-second clips from App Group storage.
  /// This does not touch files already saved to Photos.
  func removeAllSavedClips() {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: Self.appGroupID
      )
    else { return }

    let savedClipsURL = containerURL.appendingPathComponent(
      "SavedClips",
      isDirectory: true
    )
    guard FileManager.default.fileExists(atPath: savedClipsURL.path) else {
      return
    }

    if let clipURLs = try? FileManager.default.contentsOfDirectory(
      at: savedClipsURL,
      includingPropertiesForKeys: nil
    ) {
      for clipURL in clipURLs {
        try? FileManager.default.removeItem(at: clipURL)
      }
    }
  }

  /// Convenience helper for app launch:
  /// if recording is not active, clear old temporary clips.
  func removeSavedClipsIfNotRecording() {
    guard !isRecordingActive() else { return }
    removeAllSavedClips()
  }

  private func sanitizedDuration(from seconds: Int) -> Int {
    guard seconds > 0 else { return Self.defaultSaveDurationSeconds }
    return max(Self.minSaveDurationSeconds, min(seconds, Self.maxSaveDurationSeconds))
  }
}
