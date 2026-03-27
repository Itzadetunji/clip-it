//
//  LogoSettingsModel.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 26/03/2026.
//

import Combine
import UIKit

/// Persisted user logo: image data and on-disk storage only.
@MainActor
final class LogoSettingsModel: ObservableObject {
  @Published private(set) var logoImage: UIImage?

  private let appGroupID = "group.com.adetunji.ClipIt"
  private let fileName = "user-logo.jpg"

  private var logoFileURL: URL {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
      )
    else {
      let fallbackDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      if !FileManager.default.fileExists(atPath: fallbackDirectory.path) {
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
      }
      return fallbackDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    let logoDirectory = containerURL.appendingPathComponent("Watermark", isDirectory: true)
    if !FileManager.default.fileExists(atPath: logoDirectory.path) {
      try? FileManager.default.createDirectory(at: logoDirectory, withIntermediateDirectories: true)
    }
    return logoDirectory.appendingPathComponent(fileName, isDirectory: false)
  }

  init() {
    loadFromDisk()
  }

  func loadFromDisk() {
    guard FileManager.default.fileExists(atPath: logoFileURL.path),
      let data = try? Data(contentsOf: logoFileURL),
      let image = UIImage(data: data)
    else {
      logoImage = nil
      return
    }
    logoImage = image
  }

  func importPhoto(data: Data) {
    guard let image = UIImage(data: data),
      let jpeg = image.jpegData(compressionQuality: 0.9)
    else { return }

    do {
      try jpeg.write(to: logoFileURL, options: Data.WritingOptions.atomic)
      logoImage = image
    } catch {}
  }

  func deleteLogo() {
    try? FileManager.default.removeItem(at: logoFileURL)
    logoImage = nil
  }

  /// Path for other layers (e.g. watermark) to read the saved file.
  var savedLogoFileURL: URL? {
    FileManager.default.fileExists(atPath: logoFileURL.path) ? logoFileURL : nil
  }
}
