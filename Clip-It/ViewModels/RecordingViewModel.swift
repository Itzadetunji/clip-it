//
//  RecordingViewModel.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Foundation
import Photos

@Observable
@MainActor
final class RecordingViewModel {
  var isRecording: Bool = false
  var saveStatusMessage: String?
  var saveStatusIsError = false
  var isSaveRequestPending = false

  private let stateService = BroadcastStateService()
  private var pollingTask: Task<Void, Never>?

  /// Starts polling shared App Group state from the extension.
  /// We poll because app + extension live in separate processes.
  func startMonitoring() {
    stopMonitoring()
    refreshState()

    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        self?.refreshState()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
  }

  func stopMonitoring() {
    pollingTask?.cancel()
    pollingTask = nil
  }

  /// Called when user taps Save.
  /// This sets a flag the extension will read and handle.
  func requestSaveLast10Seconds() {
    guard isRecording else { return }
    stateService.requestSaveLast10Seconds()
    isSaveRequestPending = true
    saveStatusIsError = false
    saveStatusMessage = "Saving clip..."
  }

  private func refreshState() {
    isRecording = stateService.isRecordingActive()

    if let error = stateService.getLastSaveError(), !error.isEmpty {
      saveStatusIsError = true
      saveStatusMessage = "Save failed: \(error)"
      isSaveRequestPending = false
      return
    }

    // Only show success when extension explicitly signals it finished successfully.
    if stateService.getAndClearLastSaveSucceeded() {
      saveStatusIsError = false
      saveStatusMessage = "Clip saved to Photos."
      isSaveRequestPending = false
    }
  }

  /// Legacy API kept to avoid breaking other code paths.
  func recordingURLs() -> [URL] {
    []
  }
}
