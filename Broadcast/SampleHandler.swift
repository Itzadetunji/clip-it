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
/// This class writes the stream to temporary files and can save the latest 10 seconds to Photos.
final class SampleHandler: RPBroadcastSampleHandler {
    private let stateService = BroadcastStateService()

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false
    private var isSavingClip = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?)
    {
        stateService.setRecording(true)
        stateService.clearSaveRequest()
        stateService.setLastSaveError(nil)
        prepareWriterForNextSegment()
    }

    override func broadcastPaused() {
        // Keep writer state intact; ReplayKit pauses sample delivery for us.
    }

    override func broadcastResumed() {
        // Sample delivery resumes automatically.
    }

    override func broadcastFinished() {
        stateService.setRecording(false)
        stateService.clearSaveRequest()
        finishCurrentWriter {
            self.resetWriterState()
        }
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        if stateService.shouldSaveLast10Seconds() && !isSavingClip {
            // Flip the flag first so one tap triggers one save.
            stateService.clearSaveRequest()
            handleSaveLast10SecondsRequest()
        }

        // While exporting/saving we skip incoming buffers to keep logic simple and safe.
        guard !isSavingClip else { return }
        guard let assetWriter else { return }

        switch sampleBufferType {
        case .video:
            if videoInput == nil {
                guard
                    let formatDescription = CMSampleBufferGetFormatDescription(
                        sampleBuffer
                    )
                else { return }
                let dimensions = CMVideoFormatDescriptionGetDimensions(
                    formatDescription
                )
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height,
                ]
                let input = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: videoSettings
                )
                input.expectsMediaDataInRealTime = true

                guard assetWriter.canAdd(input) else { return }
                assetWriter.add(input)
                videoInput = input
            }

            if !sessionStarted {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(
                    sampleBuffer
                )
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
                let input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: audioSettings
                )
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

    /// Finalizes the current recording file, exports only the last 10 seconds, saves to Photos,
    /// then starts a new writer so recording can continue.
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
                self?.stateService.setLastSaveError(
                    "No recording segment available to save."
                )
                self?.prepareWriterForNextSegment()
                self?.isSavingClip = false
                return
            }

            self.exportLast10Seconds(from: sourceURL) { result in
                switch result {
                case .success:
                    self.stateService.setLastSaveError(nil)
                case .failure(let error):
                    self.stateService.setLastSaveError(
                        error.localizedDescription
                    )
                }

                self.prepareWriterForNextSegment()
                self.isSavingClip = false
            }
        }
    }

    private func exportLast10Seconds(
        from sourceURL: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: sourceURL)

        Task {
            do {
                // Modern API: load duration asynchronously.
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                let clipLengthSeconds = max(0, min(10, durationSeconds))

                guard clipLengthSeconds > 0 else {
                    completion(
                        .failure(
                            NSError(
                                domain: "SampleHandler",
                                code: -2,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Not enough recorded data yet."
                                ]
                            )
                        )
                    )
                    return
                }

                guard
                    let exportSession = AVAssetExportSession(
                        asset: asset,
                        presetName: AVAssetExportPresetPassthrough
                    )
                else {
                    completion(
                        .failure(
                            NSError(
                                domain: "SampleHandler",
                                code: -3,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Failed to create export session."
                                ]
                            )
                        )
                    )
                    return
                }

                guard
                    let containerURL = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier:
                            "group.com.adetunji.Screen-Record"
                    )
                else {
                    completion(
                        .failure(
                            NSError(
                                domain: "SampleHandler",
                                code: -4,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "App Group not configured."
                                ]
                            )
                        )
                    )
                    return
                }

                let clipsURL = containerURL.appendingPathComponent(
                    "SavedClips",
                    isDirectory: true
                )
                try? FileManager.default.createDirectory(
                    at: clipsURL,
                    withIntermediateDirectories: true
                )

                let exportURL = clipsURL.appendingPathComponent(
                    "Last10-\(Date().timeIntervalSince1970).mp4"
                )
                try? FileManager.default.removeItem(at: exportURL)

                let endTime = duration
                let startSeconds = max(0, durationSeconds - clipLengthSeconds)
                let startTime = CMTime(
                    seconds: startSeconds,
                    preferredTimescale: duration.timescale == 0
                        ? 600 : duration.timescale
                )
                let timeRange = CMTimeRangeFromTimeToTime(
                    start: startTime,
                    end: endTime
                )

                exportSession.timeRange = timeRange

                // Modern iOS 18+ API for exporting without deprecated callbacks/status polling.
                try await exportSession.export(to: exportURL, as: .mp4)
                self.saveVideoToPhotos(url: exportURL, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func saveVideoToPhotos(
        url: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(
                atFileURL: url
            )
        }) { success, error in
            if success {
                completion(.success(()))
            } else {
                completion(
                    .failure(
                        error
                            ?? NSError(
                                domain: "SampleHandler",
                                code: -6,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Unable to save clip to Photos."
                                ]
                            )
                    )
                )
            }
        }
    }

    // MARK: - Writer Helpers

    private func prepareWriterForNextSegment() {
        resetWriterState()

        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier:
                    "group.com.adetunji.Screen-Record"
            )
        else {
            finishBroadcastWithError(
                NSError(
                    domain: "SampleHandler",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "App Group not configured"
                    ]
                )
            )
            return
        }

        let recordingsURL = containerURL.appendingPathComponent(
            "Recordings",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: recordingsURL,
            withIntermediateDirectories: true
        )

        let fileName = "Recording-\(Date().timeIntervalSince1970).mp4"
        let newOutputURL = recordingsURL.appendingPathComponent(fileName)

        do {
            assetWriter = try AVAssetWriter(
                outputURL: newOutputURL,
                fileType: .mp4
            )
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
