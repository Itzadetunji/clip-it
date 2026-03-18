//
//  BroadcastPickerView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import ReplayKit
import SwiftUI

/// A button that opens the system broadcast picker for full-screen recording.
/// When tapped, the user can select this app and start recording from Control Center.
/// Uses a trigger binding so a custom SwiftUI-styled button can open the picker.
struct BroadcastPickerView: UIViewRepresentable {
  let preferredExtension: String?
  @Binding var trigger: Bool

  init(
    preferredExtension: String? = "com.adetunji.ClipIt.ClipIt",
    trigger: Binding<Bool> = .constant(false)
  ) {
    self.preferredExtension = preferredExtension
    self._trigger = trigger
  }

  func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
    let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    picker.preferredExtension = preferredExtension
    picker.showsMicrophoneButton = false
    context.coordinator.picker = picker
    return picker
  }

  func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
    if trigger {
      context.coordinator.triggerPicker()
      DispatchQueue.main.async { trigger = false }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator {
    weak var picker: RPSystemBroadcastPickerView?

    func triggerPicker() {
      guard let picker else { return }
      for view in picker.subviews {
        if let button = view as? UIButton {
          button.sendActions(for: .touchUpInside)
          break
        }
      }
    }
  }
}
