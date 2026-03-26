//
//  SampleHandler.swift
//  Broadcast
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import AVFoundation
import ImageIO
import Photos
import ReplayKit

/// Broadcast extension entry point.
/// Implements a PS4-style rolling buffer with 1-second segments.
/// Recording stays continuous; Save exports the most recent selected duration.
final class SampleHandler: RPBroadcastSampleHandler {
    private let stateService = BroadcastStateService()
    private let segmentQueue = DispatchQueue(
        label: "com.adetunji.ScreenRecord.segment-queue"
    )
    private let saveQueue = DispatchQueue(
        label: "com.adetunji.ScreenRecord.save-queue"
    )

    private struct SegmentMetadata {
        let url: URL
        let startTime: CMTime
        let endTime: CMTime
    }

    private var segments: [SegmentMetadata] = []
    private var currentWriter: AVAssetWriter?
    private var currentVideoInput: AVAssetWriterInput?
    private var currentAudioAppInput: AVAssetWriterInput?
    private var currentAudioMicInput: AVAssetWriterInput?
    private var currentSegmentURL: URL?
    private var currentSegmentStartTime: CMTime?
    private var currentSegmentLastTime: CMTime?

    private var isSavingClip = false
    private let saveStateLock = NSLock()

    private let appGroupID = "group.com.adetunji.ClipIt"
    private let segmentDurationSeconds: Double = 1.0
    private let rollingWindowSeconds: Double = 120.0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?)
    {
        stateService.setRecording(true)
        stateService.clearSaveRequest()
        stateService.setLastSaveError(nil)
        stateService.setLastSaveSucceeded(false)
        segmentQueue.async {
            self.segments.removeAll()
            self.resetCurrentSegmentWriter()
            self.removeAllRollingSegments()
            self.ensureDirectories()
        }
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        stateService.setRecording(false)
        stateService.clearSaveRequest()
        stateService.setLastSaveSucceeded(false)
        stateService.removeAllSavedClips()
        segmentQueue.sync {
            self.finishCurrentSegmentAndRegisterIfPossible()
            self.resetCurrentSegmentWriter()
            self.removeAllRollingSegments()
            self.segments.removeAll()
        }
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        guard sampleBufferType == .video || sampleBufferType == .audioApp || sampleBufferType == .audioMic else {
            return
        }

        guard let sampleCopy = copySampleBuffer(sampleBuffer) else { return }
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleCopy)

        segmentQueue.async {
            if self.stateService.shouldSaveLast10Seconds() {
                self.stateService.clearSaveRequest()
                if self.currentSaveInProgress() {
                    // Requested behavior: ignore taps while save is already running.
                } else {
                    self.startSaveFromCurrentSegments()
                }
            }

            if sampleBufferType == .video,
                self.shouldRotateCurrentSegment(at: sampleTime)
            {
                self.rotateToNewSegment()
            }

            self.ensureCurrentWriterConfigured(
                for: sampleCopy,
                sampleType: sampleBufferType
            )

            guard let writer = self.currentWriter else { return }

            if self.currentSegmentStartTime == nil {
                writer.startWriting()
                writer.startSession(atSourceTime: sampleTime)
                self.currentSegmentStartTime = sampleTime
            }

            let targetInput: AVAssetWriterInput?
            switch sampleBufferType {
            case .video:
                targetInput = self.currentVideoInput
            case .audioApp:
                targetInput = self.currentAudioAppInput
            case .audioMic:
                targetInput = self.currentAudioMicInput
            default:
                targetInput = nil
            }

            guard let targetInput, targetInput.isReadyForMoreMediaData else {
                return
            }
            _ = targetInput.append(sampleCopy)
            self.currentSegmentLastTime = sampleTime
        }
    }

    // MARK: - Segment Rotation

    private func shouldRotateCurrentSegment(at sampleTime: CMTime) -> Bool {
        guard let start = currentSegmentStartTime else { return false }
        let elapsed = CMTimeSubtract(sampleTime, start)
        return CMTimeGetSeconds(elapsed) >= segmentDurationSeconds
    }

    private func rotateToNewSegment() {
        finishCurrentSegmentAndRegisterIfPossible()
        resetCurrentSegmentWriter()
    }

    private func finishCurrentSegmentAndRegisterIfPossible() {
        guard
            let writer = currentWriter,
            let videoInput = currentVideoInput,
            let segmentURL = currentSegmentURL,
            let segmentStart = currentSegmentStartTime,
            let segmentEnd = currentSegmentLastTime
        else {
            resetCurrentSegmentWriter()
            return
        }

        videoInput.markAsFinished()
        currentAudioAppInput?.markAsFinished()
        currentAudioMicInput?.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)

        if FileManager.default.fileExists(atPath: segmentURL.path) {
            segments.append(
                SegmentMetadata(
                    url: segmentURL,
                    startTime: segmentStart,
                    endTime: segmentEnd
                )
            )
            pruneOldSegments(referenceTime: segmentEnd)
        }
    }

    private func ensureCurrentWriterConfigured(
        for sampleBuffer: CMSampleBuffer,
        sampleType: RPSampleBufferType
    ) {
        if currentWriter == nil {
            guard let rollingURL = rollingSegmentsDirectoryURL() else { return }
            let fileURL = rollingURL.appendingPathComponent(
                "Segment-\(Date().timeIntervalSince1970).mp4"
            )
            try? FileManager.default.removeItem(at: fileURL)
            do {
                currentWriter = try AVAssetWriter(
                    outputURL: fileURL,
                    fileType: .mp4
                )
                currentSegmentURL = fileURL
            } catch {
                stateService.setLastSaveError(error.localizedDescription)
                return
            }
        }

        guard let writer = currentWriter else { return }

        switch sampleType {
        case .video:
            if currentVideoInput == nil {
                guard
                    let format = CMSampleBufferGetFormatDescription(
                        sampleBuffer
                    )
                else { return }
                let dimensions = CMVideoFormatDescriptionGetDimensions(format)
                let width = Int32(dimensions.width)
                let height = Int32(dimensions.height)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                ]
                let input = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: settings
                )
                input.expectsMediaDataInRealTime = true
                input.transform = videoTransform(
                    for: sampleBuffer,
                    width: width,
                    height: height
                )
                guard writer.canAdd(input) else { return }
                writer.add(input)
                currentVideoInput = input
                addAudioInputsIfNeeded(to: writer)
            }
        case .audioApp, .audioMic:
            break
        default:
            break
        }
    }

    /// Adds audio inputs before startWriting. Must be called when adding video input.
    /// Uses 48kHz stereo AAC - common ReplayKit format.
    private func addAudioInputsIfNeeded(to writer: AVAssetWriter) {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
        if currentAudioAppInput == nil {
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioSettings
            )
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                currentAudioAppInput = input
            }
        }
        if currentAudioMicInput == nil {
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioSettings
            )
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                currentAudioMicInput = input
            }
        }
    }

    private func pruneOldSegments(referenceTime: CMTime) {
        let cutoff = CMTimeSubtract(
            referenceTime,
            CMTime(seconds: rollingWindowSeconds, preferredTimescale: 600)
        )
        var kept: [SegmentMetadata] = []
        for segment in segments {
            if CMTimeCompare(segment.endTime, cutoff) < 0 {
                try? FileManager.default.removeItem(at: segment.url)
            } else {
                kept.append(segment)
            }
        }
        segments = kept.sorted { CMTimeCompare($0.startTime, $1.startTime) < 0 }
    }

    private func resetCurrentSegmentWriter() {
        currentWriter = nil
        currentVideoInput = nil
        currentAudioAppInput = nil
        currentAudioMicInput = nil
        currentSegmentURL = nil
        currentSegmentStartTime = nil
        currentSegmentLastTime = nil
    }

    // MARK: - Save Workflow

    private func startSaveFromCurrentSegments() {
        let snapshot = segments.sorted {
            CMTimeCompare($0.startTime, $1.startTime) < 0
        }
        guard !snapshot.isEmpty else {
            stateService.setLastSaveError("Not enough recorded data yet.")
            stateService.setLastSaveSucceeded(false)
            return
        }

        setSaveInProgress(true)
        stateService.setLastSaveError(nil)
        stateService.setLastSaveSucceeded(false)

        saveQueue.async { [weak self] in
            guard let self else { return }
            Task {
                await self.performSaveLast10Seconds(from: snapshot)
            }
        }
    }

    private func performSaveLast10Seconds(from snapshot: [SegmentMetadata])
        async
    {
        guard let latestSegment = snapshot.last else {
            stateService.setLastSaveError("Not enough recorded data yet.")
            setSaveInProgress(false)
            return
        }

        let saveWindowSeconds = Double(stateService.getSaveDurationSeconds())
        let windowEnd = latestSegment.endTime
        let windowStart = CMTimeSubtract(
            windowEnd,
            CMTime(seconds: saveWindowSeconds, preferredTimescale: 600)
        )

        let selectedSegments = snapshot.filter { segment in
            CMTimeCompare(segment.endTime, windowStart) > 0
                && CMTimeCompare(segment.startTime, windowEnd) < 0
        }

        guard !selectedSegments.isEmpty else {
            stateService.setLastSaveError("Not enough recorded data yet.")
            setSaveInProgress(false)
            return
        }

        guard
            let exportURL = savedClipsDirectoryURL()?.appendingPathComponent(
                "Last10-\(Date().timeIntervalSince1970).mp4"
            )
        else {
            stateService.setLastSaveError("Unable to prepare export path.")
            setSaveInProgress(false)
            return
        }
        try? FileManager.default.removeItem(at: exportURL)

        do {
            let composition = AVMutableComposition()
            guard
                let videoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
            else {
                throw NSError(
                    domain: "SampleHandler",
                    code: -20,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Unable to create composition video track."
                    ]
                )
            }

            let appAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            let micAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            var insertionTime = CMTime.zero
            for segment in selectedSegments {
                let asset = AVURLAsset(url: segment.url)
                let assetDuration = try await asset.load(.duration)
                let assetVideoTracks = try await asset.loadTracks(
                    withMediaType: .video
                )
                if let sourceVideoTrack = assetVideoTracks.first {
                    try videoTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: assetDuration),
                        of: sourceVideoTrack,
                        at: insertionTime
                    )
                }

                let assetAudioTracks = try await asset.loadTracks(
                    withMediaType: .audio
                )
                // First audio track = system/app audio, second = mic (if present)
                if let appTrack = assetAudioTracks.first, let appAudioTrack {
                    try appAudioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: assetDuration),
                        of: appTrack,
                        at: insertionTime
                    )
                }
                if assetAudioTracks.count > 1, let micTrack = assetAudioTracks.last, let micAudioTrack {
                    try micAudioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: assetDuration),
                        of: micTrack,
                        at: insertionTime
                    )
                }

                insertionTime = CMTimeAdd(insertionTime, assetDuration)
            }

            guard
                let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetPassthrough
                )
            else {
                throw NSError(
                    domain: "SampleHandler",
                    code: -21,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Unable to create export session."
                    ]
                )
            }

            try await exportSession.export(to: exportURL, as: .mp4)

            let saveResult = saveVideoToPhotosSync(url: exportURL)
            switch saveResult {
            case .success:
                stateService.setLastSaveError(nil)
                stateService.setLastSaveSucceeded(true)
                try? FileManager.default.removeItem(at: exportURL)
            case .failure(let error):
                stateService.setLastSaveError(error.localizedDescription)
                stateService.setLastSaveSucceeded(false)
            }
        } catch {
            stateService.setLastSaveError(error.localizedDescription)
            stateService.setLastSaveSucceeded(false)
        }

        setSaveInProgress(false)
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
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Photo Library access is required. Enable it in Settings."
                    ]
                )
            )
        }

        var result: Result<Void, Error> = .failure(
            NSError(
                domain: "SampleHandler",
                code: -6,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unable to save clip to Photos."
                ]
            )
        )
        let semaphore = DispatchSemaphore(value: 0)

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(
                atFileURL: url
            )
        }) { success, error in
            if success {
                result = .success(())
                LocalNotificationHelper.send(
                    title: "Clip Saved ✅",
                    body: "Your clip has been saved to Photos."
                )
            } else {
                result = .failure(
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
                LocalNotificationHelper.send(
                    title: "Clip Save Failed",
                    body: "Unable to save clip to Photos."
                )
            }
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 15) == .timedOut {
            LocalNotificationHelper.send(
                title: "Clip Save Failed",
                body: "Unable to save clip to Photos."
            )
            return .failure(
                NSError(
                    domain: "SampleHandler",
                    code: -7,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Saving clip to Photos timed out."
                    ]
                )

            )
        }

        return result
    }

    // MARK: - Path Helpers

    private func ensureDirectories() {
        _ = rollingSegmentsDirectoryURL()
        _ = savedClipsDirectoryURL()
    }

    private func rollingSegmentsDirectoryURL() -> URL? {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            )
        else {
            stateService.setLastSaveError("App Group not configured.")
            return nil
        }
        let rollingURL = container.appendingPathComponent(
            "RollingSegments",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: rollingURL,
            withIntermediateDirectories: true
        )
        return rollingURL
    }

    private func savedClipsDirectoryURL() -> URL? {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            )
        else {
            stateService.setLastSaveError("App Group not configured.")
            return nil
        }
        let clipsURL = container.appendingPathComponent(
            "SavedClips",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: clipsURL,
            withIntermediateDirectories: true
        )
        return clipsURL
    }

    private func removeAllRollingSegments() {
        guard let directory = rollingSegmentsDirectoryURL() else { return }
        if let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Video Orientation (iPad)

    /// Returns the transform for correct playback orientation on iPad.
    /// ReplayKit sends frames in device natural orientation; RPVideoSampleOrientationKey
    /// describes how to rotate for intended display.
    private func videoTransform(
        for sampleBuffer: CMSampleBuffer,
        width: Int32,
        height: Int32
    ) -> CGAffineTransform {
        guard
            let orientationAttachment = CMGetAttachment(
                sampleBuffer,
                key: RPVideoSampleOrientationKey as CFString,
                attachmentModeOut: nil
            ) as? NSNumber,
            let orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value)
        else {
            return .identity
        }
        let w = CGFloat(width)
        let h = CGFloat(height)
        switch orientation {
        case .right:
            return CGAffineTransform(rotationAngle: .pi / 2)
                .translatedBy(x: 0, y: -h)
        case .left:
            return CGAffineTransform(rotationAngle: -.pi / 2)
                .translatedBy(x: -w, y: 0)
        case .down:
            return CGAffineTransform(rotationAngle: .pi)
                .translatedBy(x: -w, y: -h)
        case .up, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return .identity
        @unknown default:
            return .identity
        }
    }

    // MARK: - Utilities

    private func copySampleBuffer(_ sampleBuffer: CMSampleBuffer)
        -> CMSampleBuffer?
    {
        var copy: CMSampleBuffer?
        let status = CMSampleBufferCreateCopy(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleBufferOut: &copy
        )
        guard status == noErr else { return nil }
        return copy
    }

    private func setSaveInProgress(_ inProgress: Bool) {
        saveStateLock.lock()
        isSavingClip = inProgress
        saveStateLock.unlock()
    }

    private func currentSaveInProgress() -> Bool {
        saveStateLock.lock()
        let value = isSavingClip
        saveStateLock.unlock()
        return value
    }
}
