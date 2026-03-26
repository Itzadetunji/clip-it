//
//  ClipStateService.swift
//  ClipControls
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import Foundation

/// Shared state between the widget and Broadcast extension via App Group.
/// Uses the same UserDefaults keys as BroadcastStateService for duration.
private let appGroupID = "group.com.adetunji.ClipIt"
private let saveLastKey = "broadcast.saveLast10Seconds"
private let saveDurationKey = "broadcast.saveDurationSeconds"
private let minSaveDurationSeconds = 10
private let maxSaveDurationSeconds = 120
private let defaultSaveDurationSeconds = 15

struct ClipStateService {
  private let defaults = UserDefaults(suiteName: appGroupID)

  /// User-selected clip duration in seconds. Supports free/pro durations up to 120 seconds.
  /// Same logic as BroadcastStateService; used when Control Center "Save" uses app default.
  func getSaveDurationSeconds() -> Int {
    let value = defaults?.integer(forKey: saveDurationKey) ?? 0
    return sanitizedDuration(from: value)
  }

  func setSaveDurationSeconds(_ seconds: Int) {
    defaults?.set(sanitizedDuration(from: seconds), forKey: saveDurationKey)
  }

  func requestSave() {
    defaults?.set(true, forKey: saveLastKey)
  }

  private func sanitizedDuration(from seconds: Int) -> Int {
    guard seconds > 0 else { return defaultSaveDurationSeconds }
    return max(minSaveDurationSeconds, min(seconds, maxSaveDurationSeconds))
  }
}
