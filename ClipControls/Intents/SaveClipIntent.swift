//
//  SaveClipIntent.swift
//  ClipControls
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import AppIntents
import Foundation

/// App Intent that saves a clip when the Control Center button is tapped.
/// Uses the duration the user selected in the app (stored in UserDefaults).
struct SaveClipIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Clip"
    static var description = IntentDescription(
        "Saves the last recorded seconds to Photos."
    )

    // Runs when the user taps on the button
    func perform() async throws -> some IntentResult {
        let stateService = ClipStateService()
        stateService.setSaveDurationSeconds(stateService.getSaveDurationSeconds())
        stateService.requestSave()
        return .result()
    }
}
