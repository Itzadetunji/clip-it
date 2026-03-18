//
//  BroadcastPickerView.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import ReplayKit
import SwiftUI

/// A button that opens the system broadcast picker for full-screen recording.
/// When tapped, the user can select this app and start recording from Control Center.
struct BroadcastPickerView: UIViewRepresentable {
  let preferredExtension: String?

  init(preferredExtension: String? = "com.adetunji.Screen-Record.Broadcast") {
    self.preferredExtension = preferredExtension
  }

  func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
    let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    picker.preferredExtension = preferredExtension
    picker.showsMicrophoneButton = true

    // Make the system button fill the view
    if let button = picker.subviews.first as? UIButton {
      button.setTitle(nil, for: .normal)
    }

    return picker
  }

  func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
