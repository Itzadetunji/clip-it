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
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @State private var recordingViewModel = RecordingViewModel()
    @State private var selectedDuration: Int = 15
    @State private var triggerRecordPicker = false
    @State private var showSettings = false
    private let stateService = BroadcastStateService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ClipView(
                    recordingViewModel: recordingViewModel,
                    selectedDuration: $selectedDuration,
                    triggerRecordPicker: $triggerRecordPicker,
                    stateService: stateService,
                    isPro: subscriptionViewModel.isPro,
                    onUpgradeRequested: { showSettings = true }
                )

                Spacer()
            }
            .overlay(EnableNotificationsView().allowsHitTesting(false))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Clip-It")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .onAppear {
                Task {
                    await subscriptionViewModel.refreshStatus()
                    let stored = stateService.getSaveDurationSeconds()
                    let initialDuration =
                        subscriptionViewModel.isPro ? stored : 10
                    selectedDuration = initialDuration
                    stateService.setSaveDurationSeconds(initialDuration)
                }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
                recordingViewModel.startMonitoring()
            }
            .onDisappear {
                recordingViewModel.stopMonitoring()
            }
            .onOpenURL { url in
                if url.host == "startRecording" {
                    stateService
                        .syncBroadcastCaptureOrientationFromCurrentWindowScene()
                    triggerRecordPicker = true
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

/// Liquid Glass toolbar control on iOS 26+; plain on earlier OS versions.
private struct SettingsToolbarGlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.borderless)
        }
    }
}

#Preview {
    MainContentView()
        .environmentObject(SubscriptionViewModel())
}
