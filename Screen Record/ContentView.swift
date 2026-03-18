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

                Spacer()

                Button {
                    triggerRecordPicker = true
                } label: {
                    Image(
                        systemName: recordingViewModel.isRecording
                            ? "stop.circle.fill" : "largecircle.fill.circle"
                    )
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.easeInOut(duration: 0.3), value: recordingViewModel.isRecording)
                    .frame(width: 120, height: 120)
                    .background(primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)
                .background(
                    BroadcastPickerView(trigger: $triggerRecordPicker)
                        .frame(width: 1, height: 1)
                        .opacity(0)
                        .accessibilityHidden(true)
                )

                HStack(spacing: 20) {
                    Picker("Duration", selection: $selectedDuration) {
                        Text("15").tag(15)
                        Text("30").tag(30)
                        Text("60").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .onChange(of: selectedDuration) { _, newValue in
                        stateService.setSaveDurationSeconds(newValue)
                    }

                    Button {
                        recordingViewModel.requestSaveLast10Seconds()
                    } label: {
                        Text("Clip")
                            .font(SofiaFont.semiBold(size: 18))
                            .foregroundColor(.white)
                            .frame(minHeight: 32)
                            .padding(.horizontal, 16)
                            .background(primaryColor)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: buttonCornerRadius
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!recordingViewModel.isRecording)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                Text("Saved to Photos. Just press record and tap Clip to save.")
                    .font(SofiaFont.regular(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                Spacer()
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
