//
//  ClipStateService.swift
//  ClipControls
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import Foundation

/// Shared state between the widget and Broadcast extension via App Group.
/// Uses the same UserDefaults keys as BroadcastStateService for duration.
private let appGroupID = "group.com.adetunji.Screen-Record"
private let saveLastKey = "broadcast.saveLast10Seconds"
private let saveDurationKey = "broadcast.saveDurationSeconds"

struct ClipStateService {
  private let defaults = UserDefaults(suiteName: appGroupID)

  /// User-selected clip duration in seconds (15, 30, or 60). Default 15.
  /// Same logic as BroadcastStateService; used when Control Center "Save" uses app default.
  func getSaveDurationSeconds() -> Int {
    let value = defaults?.integer(forKey: saveDurationKey) ?? 0
    return [15, 30, 60].contains(value) ? value : 15
  }

  func setSaveDurationSeconds(_ seconds: Int) {
    defaults?.set(seconds, forKey: saveDurationKey)
  }

  func requestSave() {
    defaults?.set(true, forKey: saveLastKey)
  }
}
