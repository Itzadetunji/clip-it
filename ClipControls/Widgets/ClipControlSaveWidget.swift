//
//  ClipControlWidget.swift
//  ClipControls
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import SwiftUI
import WidgetKit

struct ClipControlSaveWidget: ControlWidget {
    static let kind = "com.adetunji.ClipIt.ClipControl.Save"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: SaveClipIntent()) {
                Label("Save Clip", image: "clip-it-logo.symbols")
                        .symbolEffect(.pulse)
            }
        }
        .displayName("Save Clip")
        .description(
            "Save the last recorded seconds to Photos. Uses the duration you set in the app."
        )
    }
}
