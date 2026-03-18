//
//  ClipView.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//
import SwiftUI

private let primaryColor = Color("PrimaryColor")
private let buttonCornerRadius: CGFloat = 32

struct ClipView: View {
    var recordingViewModel: RecordingViewModel
    @Binding var selectedDuration: Int
    @Binding var triggerRecordPicker: Bool
    let stateService: BroadcastStateService

    var body: some View {
        VStack(spacing: 24) {
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
                .animation(
                    .easeInOut(duration: 0.3),
                    value: recordingViewModel.isRecording
                )
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
    }
}

#Preview {
    ClipView(
        recordingViewModel: RecordingViewModel(),
        selectedDuration: .constant(15),
        triggerRecordPicker: .constant(false),
        stateService: BroadcastStateService()
    )
}
