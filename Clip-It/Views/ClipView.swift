//
//  ClipView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import Photos
import SwiftUI
import UIKit

private let primaryColor = Color("PrimaryColor")
private let recordingColor = Color(red: 0.95, green: 0.35, blue: 0.28)

private let buttonCornerRadius: CGFloat = 32

struct ClipView: View {
    var recordingViewModel: RecordingViewModel
    @Binding var selectedDuration: Int
    @Binding var triggerRecordPicker: Bool
    let stateService: BroadcastStateService
    let isPro: Bool
    let onUpgradeRequested: () -> Void

    @State private var photosAccessDenied: Bool = false
    @State private var useCustomDuration = false
    @State private var customDurationText = "60"
    @FocusState private var isCustomDurationFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            keyboardDismissibleSpacer
            Button {
                checkPhotoAccess {
                    stateService.syncBroadcastCaptureOrientationFromCurrentWindowScene()
                    triggerRecordPicker = true
                }
            } label: {
                Image(
                    systemName: recordingViewModel.isRecording
                        ? "stop.circle.fill" : "largecircle.fill.circle"
                )
                .font(.system(size: 64))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    value: recordingViewModel.isRecording
                )
                .animation(
                    .easeInOut(duration: 0.3),
                    value: recordingViewModel.isRecording
                )
                .frame(width: 120, height: 120)
                .background(
                    recordingViewModel.isRecording
                        ? recordingColor : primaryColor
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .background(
                BroadcastPickerView(trigger: $triggerRecordPicker)
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .accessibilityHidden(true)
            )

            VStack(spacing: 20) {
                if isPro {
                    proDurationControls
                } else {
                    freeDurationControls
                }

            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            Text(
                "Saved to Photos. Press record and tap Clip to save your selected duration."
            )
            .font(SofiaFont.regular(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)

            keyboardDismissibleSpacer
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissCustomDurationKeyboard()
                }
                .font(SofiaFont.semiBold(size: 16))
            }
        }
        .onAppear {
            if isPro {
                customDurationText = "\(selectedDuration)"
            } else {
                selectedDuration = 10
                stateService.setSaveDurationSeconds(10)
            }
        }
        .onChange(of: isPro) { _, newValue in
            if newValue {
                let proDefault = max(15, min(selectedDuration, 120))
                selectedDuration = proDefault
                stateService.setSaveDurationSeconds(proDefault)
                customDurationText = "\(proDefault)"
            } else {
                useCustomDuration = false
                selectedDuration = 10
                customDurationText = "10"
                stateService.setSaveDurationSeconds(10)
            }
        }
        .onChange(of: useCustomDuration) { _, newValue in
            if newValue {
                customDurationText = "\(selectedDuration)"
            } else {
                dismissCustomDurationKeyboard()
                if ![15, 30, 60].contains(selectedDuration) {
                    selectedDuration = 15
                    stateService.setSaveDurationSeconds(15)
                }
            }
        }
        .alert(isPresented: $photosAccessDenied, content: getAlert)
    }

    /// Tappable spacer so tapping empty areas dismisses the number pad when custom duration is active.
    private var keyboardDismissibleSpacer: some View {
        Spacer()
            .contentShape(Rectangle())
            .onTapGesture {
                guard isPro, useCustomDuration else { return }
                dismissCustomDurationKeyboard()
            }
    }

    private func dismissCustomDurationKeyboard() {
        isCustomDurationFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var freeDurationControls: some View {
        HStack {
            Picker(
                "Duration",
                selection: Binding(
                    get: { selectedDuration == 30 ? 30 : 10 },
                    set: { newValue in
                        if newValue == 30 {
                            selectedDuration = 10
                            stateService.setSaveDurationSeconds(10)
                            onUpgradeRequested()
                        } else {
                            selectedDuration = 10
                            stateService.setSaveDurationSeconds(10)
                        }
                    }
                )
            ) {
                Text("10").tag(10)
                Text("30").tag(30)
            }
            .pickerStyle(.segmented)
            .fixedSize()

            clipButton
        }

    }

    private var proDurationControls: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Text("Custom")
                Toggle("", isOn: $useCustomDuration)
                    .labelsHidden()
                    .tint(primaryColor)
            }
            .font(SofiaFont.regular(size: 14))

            if useCustomDuration {
                HStack(spacing: 8) {
                    TextField("10-120", text: $customDurationText)
                        .keyboardType(.numberPad)
                        .focused($isCustomDurationFieldFocused)
                        .textFieldStyle(.plain)
                        .font(SofiaFont.regular(size: 14))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .frame(width: 120)

                        .background(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                        .onChange(of: customDurationText) { _, newValue in
                            updateCustomDuration(from: newValue)
                        }

                    clipButton
                }
            } else {
                HStack {
                    Picker("Duration", selection: $selectedDuration) {
                        Text("15").tag(15)
                        Text("30").tag(30)
                        Text("60").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: .infinity)
                    .frame(maxWidth: 120)
                    .onChange(of: selectedDuration) { _, newValue in
                        stateService.setSaveDurationSeconds(newValue)
                    }
                    clipButton
                }
            }
        }
    }

    private var clipButton: some View {
        Button {
            checkPhotoAccess {
                stateService.setSaveDurationSeconds(selectedDuration)
                recordingViewModel.requestSaveLast10Seconds()
            }
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

    private func updateCustomDuration(from input: String) {
        let digitsOnly = input.filter(\.isNumber)
        if digitsOnly != input {
            customDurationText = digitsOnly
            return
        }

        guard let enteredValue = Int(digitsOnly) else {
            return
        }

        if enteredValue > 120 {
            customDurationText = "120"
            selectedDuration = 120
            stateService.setSaveDurationSeconds(120)
            return
        }

        guard enteredValue >= 10 else {
            return
        }

        selectedDuration = enteredValue
        stateService.setSaveDurationSeconds(enteredValue)
    }

    /// Checks Photos access. If granted, runs the action. If denied, shows alert.
    private func checkPhotoAccess(then performAction: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            performAction()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                Task { @MainActor in
                    if newStatus == .authorized || newStatus == .limited {
                        performAction()
                    } else {
                        photosAccessDenied = true
                    }
                }
            }
        case .denied, .restricted:
            photosAccessDenied = true
        @unknown default:
            break
        }
    }

    private func getAlert() -> Alert {
        Alert(
            title: Text("Photos Access Required"),
            message: Text(
                "Clip-It needs access to save your clips to Photos. Please enable it in Settings."
            ),
            primaryButton: .default(Text("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            },
            secondaryButton: .cancel()
        )
    }
}

#Preview {
    ClipView(
        recordingViewModel: RecordingViewModel(),
        selectedDuration: .constant(15),
        triggerRecordPicker: .constant(false),
        stateService: BroadcastStateService(),
        isPro: true,
        onUpgradeRequested: {}
    )
}
