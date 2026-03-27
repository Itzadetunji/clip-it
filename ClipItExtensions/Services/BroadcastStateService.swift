//
//  BroadcastStateService.swift
//  Broadcast
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Foundation

/// Shared state between the app process and the broadcast extension process.
/// We store lightweight flags in App Group UserDefaults.
struct BroadcastStateService {
  enum WatermarkPosition: String, CaseIterable {
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
  }

  private static let appGroupID = "group.com.adetunji.ClipIt"
  private static let isRecordingKey = "broadcast.isRecording"
  private static let saveLast10SecondsKey = "broadcast.saveLast10Seconds"
  private static let saveDurationSecondsKey = "broadcast.saveDurationSeconds"
  private static let lastSaveErrorKey = "broadcast.lastSaveError"
  private static let lastSaveSucceededKey = "broadcast.lastSaveSucceeded"
  private static let isProUserKey = "broadcast.isProUser"
  private static let watermarkPositionKey = "broadcast.watermarkPosition"
  private static let watermarkOpacityKey = "broadcast.watermarkOpacity"
  private static let proWatermarkEnabledKey = "broadcast.proWatermarkEnabled"
  private static let minSaveDurationSeconds = 10
  private static let maxSaveDurationSeconds = 120
  private static let defaultSaveDurationSeconds = 15
  private static let defaultWatermarkOpacity = 0.5

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

  /// Reads Pro status synced by the app so extension can enforce free/pro behavior.
  func isProUser() -> Bool {
    sharedDefaults?.bool(forKey: Self.isProUserKey) ?? false
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
    let value = sharedDefaults?.integer(forKey: Self.saveDurationSecondsKey) ?? 0
    return sanitizedDuration(from: value)
  }

  func setSaveDurationSeconds(_ seconds: Int) {
    sharedDefaults?.set(
      sanitizedDuration(from: seconds),
      forKey: Self.saveDurationSecondsKey
    )
  }

  /// Reads user-selected watermark placement. Falls back to top-right if missing.
  func getWatermarkPosition() -> WatermarkPosition {
    guard
      let rawValue = sharedDefaults?.string(forKey: Self.watermarkPositionKey),
      let position = WatermarkPosition(rawValue: rawValue)
    else { return .topRight }
    return position
  }

  /// Reads persisted watermark opacity in 0...1 range.
  func getWatermarkOpacity() -> Double {
    let rawOpacity = sharedDefaults?.double(forKey: Self.watermarkOpacityKey) ?? Self.defaultWatermarkOpacity
    return sanitizedOpacity(from: rawOpacity)
  }

  func isProWatermarkEnabled() -> Bool {
    sharedDefaults?.bool(forKey: Self.proWatermarkEnabledKey) ?? false
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

  func setLastSaveSucceeded(_ succeeded: Bool) {
    sharedDefaults?.set(succeeded, forKey: Self.lastSaveSucceededKey)
  }

  /// Removes all temporary 10-second clips from App Group storage.
  /// This does not touch files already saved to Photos.
  func removeAllSavedClips() {
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroupID
    ) else { return }

    let savedClipsURL = containerURL.appendingPathComponent("SavedClips", isDirectory: true)
    guard FileManager.default.fileExists(atPath: savedClipsURL.path) else { return }

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

  private func sanitizedOpacity(from opacity: Double) -> Double {
    max(0.0, min(opacity, 1.0))
  }
}
