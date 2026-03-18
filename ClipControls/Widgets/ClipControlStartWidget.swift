//
//  ClipControlWidget.swift
//  ClipControls
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import SwiftUI
import WidgetKit

struct ClipControlStartWidget: ControlWidget {
    static let kind = "com.adetunji.Screen-Record.ClipControl.Start"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartClipIntent()) {
                Label("Record", systemImage: "recordingtape")
            }
        }
        .displayName("Start Recording")
        .description(
            "Start recording so you can clip it"
        )
    }
}
