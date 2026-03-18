//
//  ContentView.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Photos
import ReplayKit
import SwiftUI

private let primaryColor = Color("PrimaryColor")
private let buttonCornerRadius: CGFloat = 32

struct ContentView: View {
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
                    NavigationLink {
                        ProView()
                    } label: {
                        Text("Go Pro")
                            .font(SofiaFont.semiBold(size: 18))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(primaryColor)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: buttonCornerRadius
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                ClipView(
                    recordingViewModel: recordingViewModel,
                    selectedDuration: $selectedDuration,
                    triggerRecordPicker: $triggerRecordPicker,
                    stateService: stateService
                )

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .onAppear {
                selectedDuration = stateService.getSaveDurationSeconds()
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
                recordingViewModel.startMonitoring()
            }
            .onDisappear {
                recordingViewModel.stopMonitoring()
            }
        }
    }
}

struct ProView: View {
    var body: some View {
        Text("Go Pro")
            .font(SofiaFont.bold(size: 24))
            .navigationTitle("Go Pro")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
