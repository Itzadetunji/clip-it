//
//  ContentView.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Photos
import ReplayKit
import SwiftUI

struct ContentView: View {
  @State private var recordingViewModel = RecordingViewModel()

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        Text("Screen Record")
          .font(.title)
          .fontWeight(.bold)
          .padding(.top, 24)

        Text("Record your entire screen")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Spacer()

        VStack(spacing: 20) {
          Text("1. Tap the green button below")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          ZStack {
            RoundedRectangle(cornerRadius: 14)
              .fill(Color.green)
              .frame(width: 120, height: 120)

            BroadcastPickerView()
              .frame(width: 120, height: 120)
          }

          VStack(spacing: 8) {
            Text("2. A list will appear — choose \"Screen Recording\" to save to Photos")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }

          Text("3. Open Control Center (swipe down from top-right) and tap the record button")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          Text("4. Tap the red status bar when done to stop")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          Button("Save") {
            recordingViewModel.requestSaveLast10Seconds()
          }
          .buttonStyle(.borderedProminent)
          .disabled(!recordingViewModel.isRecording)

          Text(recordingViewModel.isRecording
            ? "Recording is active. Tap Save to export only the last 10 seconds."
            : "Start a screen recording first, then Save becomes available.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          if let saveStatusMessage = recordingViewModel.saveStatusMessage {
            Text(saveStatusMessage)
              .font(.caption2)
              .foregroundStyle(recordingViewModel.saveStatusIsError ? .red : .green)
              .multilineTextAlignment(.center)
          }

          Text("Recordings will be saved to your Photos app (Camera Roll)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemBackground))
      .onAppear {
        // Request Photos permission so the extension can save clips.
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        recordingViewModel.startMonitoring()
      }
      .onDisappear {
        recordingViewModel.stopMonitoring()
      }
    }
  }
}

#Preview {
  ContentView()
}
