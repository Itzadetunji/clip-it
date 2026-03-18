//
//  SampleHandler.swift
//  ClipItExtension
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import ReplayKit
import AVFoundation

/// Records the full device screen when the user starts screen recording from Control Center.
/// Requires App Group: group.com.adetunji.ClipIt
class SampleHandler: RPBroadcastSampleHandler {

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var outputURL: URL?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.adetunji.ClipIt"
        ) else {
            finishBroadcastWithError(NSError(domain: "SampleHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "App Group not configured"]))
            return
        }

        let recordingsURL = containerURL.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true)

        let fileName = "Recording-\(Date().timeIntervalSince1970).mp4"
        outputURL = recordingsURL.appendingPathComponent(fileName)

        guard let outputURL else { return }

        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            finishBroadcastWithError(error as NSError)
            return
        }

        sessionStarted = false
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard let assetWriter else { return }

        switch sampleBufferType {
        case .video:
            if videoInput == nil {
                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: dimensions.width,
                    AVVideoHeightKey: dimensions.height
                ]
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput?.expectsMediaDataInRealTime = true
                if assetWriter.canAdd(videoInput!) {
                    assetWriter.add(videoInput!)
                }
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
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1
                ]
                audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput?.expectsMediaDataInRealTime = true
                if let audioInput, assetWriter.canAdd(audioInput) {
                    assetWriter.add(audioInput)
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

    override func broadcastPaused() {
        // Optional: handle pause
    }

    override func broadcastResumed() {
        // Optional: handle resume
    }

    override func broadcastFinished() {
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            self?.assetWriter = nil
            self?.videoInput = nil
            self?.audioInput = nil
        }
    }
}
