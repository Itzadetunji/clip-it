//
//  MainContentView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import Photos
import ReplayKit
import SwiftUI
import UIKit
import UserNotifications

struct MainContentView: View {
  @State private var recordingViewModel = RecordingViewModel()
  @State private var selectedDuration: Int = 15
  @State private var triggerRecordPicker = false
  private let stateService = BroadcastStateService()

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        HStack {
          Text("Clip-It")
            .font(SofiaFont.bold(size: 28))

          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)

        ClipView(
          recordingViewModel: recordingViewModel,
          selectedDuration: $selectedDuration,
          triggerRecordPicker: $triggerRecordPicker,
          stateService: stateService
        )

        Spacer()
      }
      .overlay(EnableNotificationsView().allowsHitTesting(false))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemBackground))
      .onAppear {
        AppDelegate.applyPortraitOrientation()
        let stored = stateService.getSaveDurationSeconds()
        selectedDuration = stored
        stateService.setSaveDurationSeconds(stored)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        recordingViewModel.startMonitoring()
      }
      .onDisappear {
        recordingViewModel.stopMonitoring()
      }
      .onOpenURL { url in
        if url.host == "startRecording" {
          triggerRecordPicker = true
        }
      }
    }
  }
}

#Preview {
  MainContentView()
}
