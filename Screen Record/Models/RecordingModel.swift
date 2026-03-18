//
//  RecordingModel.swift
//  Screen Record
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import Foundation

@Observable
final class RecordingModel {
    var isRecording: Bool = false

    func toggleRecording() {
        isRecording.toggle()
    }
}

