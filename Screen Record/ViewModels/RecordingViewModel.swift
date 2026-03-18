//
//  RecordingViewModel.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Foundation

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
    saveStatusMessage = "Saving last 10 seconds..."
  }

  private func refreshState() {
    isRecording = stateService.isRecordingActive()

    if let error = stateService.getLastSaveError(), !error.isEmpty {
      saveStatusIsError = true
      saveStatusMessage = "Save failed: \(error)"
      isSaveRequestPending = false
      return
    }

    // If the request was pending and extension no longer reports an error,
    // we treat that as a successful save.
    if isSaveRequestPending {
      saveStatusIsError = false
      saveStatusMessage = "Saved last 10 seconds to Photos."
      isSaveRequestPending = false
    }
  }

  /// Legacy API kept to avoid breaking other code paths.
  func recordingURLs() -> [URL] {
    []
  }
}
