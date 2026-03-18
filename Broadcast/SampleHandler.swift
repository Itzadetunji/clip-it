//
//  SampleHandler.swift
//  Broadcast
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import AVFoundation
import Photos
import ReplayKit

/// Broadcast extension entry point.
/// Writes the stream to a file. On Save, finishes the file, exports last 10 seconds to Photos, then starts a new file.
final class SampleHandler: RPBroadcastSampleHandler {
    private let stateService = BroadcastStateService()

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false
    private var isSavingClip = false
    private let appGroupID = "group.com.adetunji.Screen-Record"

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        stateService.setRecording(true)
        stateService.clearSaveRequest()
        stateService.setLastSaveError(nil)
        prepareMainWriter()
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        stateService.setRecording(false)
        stateService.clearSaveRequest()
        stateService.removeAllSavedClips()
        finishCurrentWriter {
            self.resetWriterState()
        }
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        if stateService.shouldSaveLast10Seconds() && !isSavingClip {
            stateService.clearSaveRequest()
            handleSaveLast10SecondsRequest()
        }

        guard !isSavingClip else { return }
        guard let assetWriter else { return }

        switch sampleBufferType {
        case .video:
            if videoInput == nil {
                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height,
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                input.expectsMediaDataInRealTime = true
                guard assetWriter.canAdd(input) else { return }
                assetWriter.add(input)
                videoInput = input
            }

            if !sessionStarted {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: timestamp)
                sessionStarted = true
            }

            if let videoInput, videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }

        case .audioApp:
            if audioInput == nil {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                input.expectsMediaDataInRealTime = true
                if assetWriter.canAdd(input) {
                    assetWriter.add(input)
                    audioInput = input
                }
            }

            if let audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }

        case .audioMic:
            break

        @unknown default:
            break
        }
    }

    // MARK: - Clip Saving

    private func handleSaveLast10SecondsRequest() {
        guard !isSavingClip else { return }
        guard sessionStarted else {
            stateService.setLastSaveError("Recording has not started yet.")
            return
        }

        isSavingClip = true
        stateService.setLastSaveError(nil)

        let sourceURL = outputURL
        finishCurrentWriter { [weak self] in
            guard let self, let sourceURL else {
                self?.stateService.setLastSaveError("No recording segment available to save.")
                self?.prepareMainWriter()
                self?.isSavingClip = false
                return
            }

            Task {
                do {
                    let duration = try await AVURLAsset(url: sourceURL).load(.duration)
                    let durationSeconds = CMTimeGetSeconds(duration)
                    let clipLengthSeconds = max(0, min(10, durationSeconds))

                    guard clipLengthSeconds > 0 else {
                        self.stateService.setLastSaveError("Not enough recorded data yet.")
                        self.prepareMainWriter()
                        self.isSavingClip = false
                        return
                    }

                    guard let exportSession = AVAssetExportSession(
                        asset: AVURLAsset(url: sourceURL),
                        presetName: AVAssetExportPresetPassthrough
                    ) else {
                        self.stateService.setLastSaveError("Failed to create export session.")
                        self.prepareMainWriter()
                        self.isSavingClip = false
                        return
                    }

                    guard let containerURL = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: self.appGroupID
                    ) else {
                        self.stateService.setLastSaveError("App Group not configured.")
                        self.prepareMainWriter()
                        self.isSavingClip = false
                        return
                    }

                    let clipsURL = containerURL.appendingPathComponent("SavedClips", isDirectory: true)
                    try? FileManager.default.createDirectory(at: clipsURL, withIntermediateDirectories: true)
                    let exportURL = clipsURL.appendingPathComponent("Last10-\(Date().timeIntervalSince1970).mp4")
                    try? FileManager.default.removeItem(at: exportURL)

                    let endTime = duration
                    let startSeconds = max(0, durationSeconds - clipLengthSeconds)
                    let startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
                    let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)

                    exportSession.outputURL = exportURL
                    exportSession.outputFileType = .mp4
                    exportSession.timeRange = timeRange

                    try await exportSession.export(to: exportURL, as: .mp4)

                    let saveResult = self.saveVideoToPhotosSync(url: exportURL)
                    switch saveResult {
                    case .success:
                        self.stateService.setLastSaveError(nil)
                        self.stateService.setLastSaveSucceeded(true)
                        try? FileManager.default.removeItem(at: exportURL)
                    case .failure(let error):
                        self.stateService.setLastSaveError(error.localizedDescription)
                    }

                    self.prepareMainWriter()
                } catch {
                    self.stateService.setLastSaveError(error.localizedDescription)
                    self.prepareMainWriter()
                }
                self.isSavingClip = false
            }
        }
    }

    private func saveVideoToPhotosSync(url: URL) -> Result<Void, Error> {
        let authSemaphore = DispatchSemaphore(value: 0)
        var authStatus: PHAuthorizationStatus = .notDetermined
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            authStatus = status
            authSemaphore.signal()
        }
        _ = authSemaphore.wait(timeout: .now() + 5)

        guard authStatus == .authorized || authStatus == .limited else {
            return .failure(
                NSError(
                    domain: "SampleHandler",
                    code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "Photo Library access is required. Enable it in Settings."]
                )
            )
        }

        var result: Result<Void, Error> = .failure(
            NSError(domain: "SampleHandler", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unable to save clip to Photos."])
        )
        let semaphore = DispatchSemaphore(value: 0)

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            if success {
                result = .success(())
            } else {
                result = .failure(error ?? NSError(domain: "SampleHandler", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unable to save clip to Photos."]))
            }
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 15) == .timedOut {
            return .failure(NSError(domain: "SampleHandler", code: -7, userInfo: [NSLocalizedDescriptionKey: "Saving clip to Photos timed out."]))
        }
        return result
    }

    // MARK: - Main Writer Helpers

    private func prepareMainWriter() {
        resetWriterState()

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            finishBroadcastWithError(NSError(domain: "SampleHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "App Group not configured"]))
            return
        }

        let recordingsURL = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
        let fileName = "Recording-\(Date().timeIntervalSince1970).mp4"
        let newOutputURL = recordingsURL.appendingPathComponent(fileName)

        do {
            assetWriter = try AVAssetWriter(outputURL: newOutputURL, fileType: .mp4)
            outputURL = newOutputURL
            sessionStarted = false
        } catch {
            finishBroadcastWithError(error as NSError)
        }
    }

    private func finishCurrentWriter(completion: @escaping () -> Void) {
        guard let assetWriter else {
            completion()
            return
        }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        assetWriter.finishWriting {
            completion()
        }
    }

    private func resetWriterState() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        outputURL = nil
        sessionStarted = false
    }
}
