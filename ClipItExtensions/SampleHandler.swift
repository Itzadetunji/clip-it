//
//  SampleHandler.swift
//  Broadcast
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import AVFoundation
import Photos
import ReplayKit
import UIKit

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
  private let watermarkSize: CGFloat = 64
  private let watermarkPadding: CGFloat = 64

  /// Snapshot of App Group flag set by the main app when the user starts broadcast.
  private var broadcastCaptureIsLandscape = false

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    broadcastCaptureIsLandscape = stateService.isBroadcastCaptureLandscape()
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
    guard
      sampleBufferType == .video || sampleBufferType == .audioApp || sampleBufferType == .audioMic
    else {
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

  private func performSaveLast10Seconds(from snapshot: [SegmentMetadata]) async {
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
          presetName: AVAssetExportPresetHighestQuality
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

      if let exportComposition = try await makeExportVideoComposition(
        for: composition,
        videoTrack: videoTrack
      ) {
        exportSession.videoComposition = exportComposition
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

  // MARK: - Export orientation (ReplayKit buffer vs `UIInterfaceOrientation`)

  private func rotate90CW(naturalSize: CGSize) -> CGAffineTransform {
    CGAffineTransform(
      a: 0, b: 1, c: -1, d: 0, tx: naturalSize.height, ty: 0)
  }

  private func rotate90CCW(naturalSize: CGSize) -> CGAffineTransform {
    CGAffineTransform(
      a: 0, b: -1, c: 1, d: 0, tx: 0, ty: naturalSize.width)
  }

  /// 180° in natural coordinates (fixes upside‑down landscape‑left exports on iPad).
  private func rotate180(naturalSize: CGSize) -> CGAffineTransform {
    CGAffineTransform(
      a: -1, b: 0, c: 0, d: -1, tx: naturalSize.width, ty: naturalSize.height)
  }

  private func axisAlignedRenderSize(
    naturalSize: CGSize,
    layerTransform: CGAffineTransform
  ) -> CGSize {
    let r = CGRect(origin: .zero, size: naturalSize).applying(layerTransform)
    return CGSize(width: abs(r.width), height: abs(r.height))
  }

  /// Picks the layer transform and output size for export.
  ///
  /// **iPad:** `preferredTransform` alone matches **landscape right**; other orientations need a single
  /// extra transform (field‑tested): portrait / portrait‑upside‑down need ±90° to get upright portrait
  /// output; **landscape left** needs 180° (same aspect, not mirrored).
  ///
  /// **iPhone:** Landscape UI + portrait‑shaped buffer → one 90° CCW (see `broadcastCaptureIsLandscape`).
  private func exportLayerTransform(
    naturalSize: CGSize,
    preferredTransform: CGAffineTransform,
    captureOrientation: UIInterfaceOrientation
  ) -> (CGAffineTransform, CGSize, Bool) {
    let P = preferredTransform
    let baseline = P
    let baselineSize = axisAlignedRenderSize(
      naturalSize: naturalSize,
      layerTransform: baseline
    )

    func apply(_ extra: CGAffineTransform) -> (CGAffineTransform, CGSize, Bool) {
      let T = extra.concatenating(P)
      return (T, axisAlignedRenderSize(naturalSize: naturalSize, layerTransform: T), true)
    }

    if UIDevice.current.userInterfaceIdiom == .pad {
      switch captureOrientation {
      case .landscapeRight:
        return (baseline, baselineSize, false)
      case .landscapeLeft:
        return apply(rotate180(naturalSize: naturalSize))
      case .portrait:
        // Was CCW but output was upside down; CW matches ReplayKit’s portrait buffer on iPad.
        return apply(rotate90CW(naturalSize: naturalSize))
      case .portraitUpsideDown:
        return apply(rotate90CCW(naturalSize: naturalSize))
      default:
        return (baseline, baselineSize, false)
      }
    }

    let needsLandscapeFix =
      broadcastCaptureIsLandscape && baselineSize.width < baselineSize.height
    guard needsLandscapeFix else {
      return (baseline, baselineSize, false)
    }
    return apply(rotate90CCW(naturalSize: naturalSize))
  }

  /// Export composition: orientation normalization (ReplayKit buffer shape/orientation differs by device and
  /// `UIInterfaceOrientation`) plus optional watermark.
  private func makeExportVideoComposition(
    for composition: AVMutableComposition,
    videoTrack: AVMutableCompositionTrack
  ) async throws -> AVMutableVideoComposition? {
    let naturalSize = try await videoTrack.load(.naturalSize)
    let preferredTransform = try await videoTrack.load(.preferredTransform)
    let orientationRaw = stateService.getBroadcastCaptureInterfaceOrientationRaw()
    let captureOrientation = UIInterfaceOrientation(rawValue: orientationRaw) ?? .unknown
    let (layerTransform, renderSize, appliedOrientationFix) = exportLayerTransform(
      naturalSize: naturalSize,
      preferredTransform: preferredTransform,
      captureOrientation: captureOrientation
    )
    guard renderSize.width > 0, renderSize.height > 0 else { return nil }

    let isProUser = stateService.isProUser()
    let wantsWatermark: Bool
    let watermarkImage: UIImage?
    let position: BroadcastStateService.WatermarkPosition
    let opacity: CGFloat

    if isProUser {
      if stateService.isProWatermarkEnabled(), let logo = loadUserLogoImage() {
        wantsWatermark = true
        watermarkImage = logo
        position = stateService.getWatermarkPosition()
        opacity = CGFloat(stateService.getWatermarkOpacity())
      } else {
        wantsWatermark = false
        watermarkImage = nil
        position = .bottomRight
        opacity = 1
      }
    } else if let logo = loadClipItLogoImage() {
      wantsWatermark = true
      watermarkImage = logo
      position = .bottomRight
      opacity = 1
    } else {
      wantsWatermark = false
      watermarkImage = nil
      position = .bottomRight
      opacity = 1
    }

    if !appliedOrientationFix && !wantsWatermark {
      return nil
    }

    let videoComposition = AVMutableVideoComposition()
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.renderSize = renderSize

    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    layerInstruction.setTransform(layerTransform, at: .zero)
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]

    if wantsWatermark, let watermarkImage {
      let videoLayer = CALayer()
      videoLayer.frame = CGRect(origin: .zero, size: renderSize)

      let parentLayer = CALayer()
      parentLayer.frame = CGRect(origin: .zero, size: renderSize)
      parentLayer.addSublayer(videoLayer)

      let watermarkLayer = CALayer()
      watermarkLayer.contents = watermarkImage.cgImage
      watermarkLayer.contentsGravity = .resizeAspectFill
      watermarkLayer.masksToBounds = true
      watermarkLayer.cornerRadius = 8
      watermarkLayer.opacity = Float(opacity)
      watermarkLayer.frame = watermarkFrame(
        for: position,
        renderSize: renderSize
      )
      parentLayer.addSublayer(watermarkLayer)

      videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
        postProcessingAsVideoLayer: videoLayer,
        in: parentLayer
      )
    }

    return videoComposition
  }

  private func watermarkFrame(
    for position: BroadcastStateService.WatermarkPosition,
    renderSize: CGSize
  ) -> CGRect {
    switch position {
    case .topLeft:
      return CGRect(
        x: watermarkPadding, y: watermarkPadding, width: watermarkSize, height: watermarkSize)
    case .topRight:
      return CGRect(
        x: renderSize.width - watermarkSize - watermarkPadding,
        y: watermarkPadding,
        width: watermarkSize,
        height: watermarkSize
      )
    case .bottomLeft:
      return CGRect(
        x: watermarkPadding,
        y: renderSize.height - watermarkSize - watermarkPadding,
        width: watermarkSize,
        height: watermarkSize
      )
    case .bottomRight:
      return CGRect(
        x: renderSize.width - watermarkSize - watermarkPadding,
        y: renderSize.height - watermarkSize - watermarkPadding,
        width: watermarkSize,
        height: watermarkSize
      )
    }
  }

  private func loadUserLogoImage() -> UIImage? {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
      )
    else { return nil }

    let logoURL =
      containerURL
      .appendingPathComponent("Watermark", isDirectory: true)
      .appendingPathComponent("user-logo.jpg", isDirectory: false)

    guard
      FileManager.default.fileExists(atPath: logoURL.path),
      let data = try? Data(contentsOf: logoURL),
      let image = UIImage(data: data)
    else { return nil }
    return image
  }

  /// Free-tier watermark: app logo copied into App Group by the main app at launch (`free-watermark.png`).
  private func loadClipItLogoImage() -> UIImage? {
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupID
    ) {
      let appGroupWatermarkURL =
        containerURL
        .appendingPathComponent("Watermark", isDirectory: true)
        .appendingPathComponent("free-watermark.png", isDirectory: false)
      if let data = try? Data(contentsOf: appGroupWatermarkURL),
        let appGroupImage = UIImage(data: data)
      {
        return appGroupImage
      }
    }

    // Extension bundle usually does not include app assets; avoid text placeholder—return nil if unset.
    if let bundled = UIImage(named: "FreeWatermark") {
      return bundled
    }
    return nil
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
