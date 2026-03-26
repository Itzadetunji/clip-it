//
//  LogoSettingsViewModel.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 26/03/2026.
//

import Combine
import Foundation

/// UI coordination for the logo settings screen; domain state lives in `LogoSettingsModel`.
@MainActor
final class LogoSettingsViewModel: ObservableObject {
  let model: LogoSettingsModel

  @Published var showDeleteConfirmation = false

  private var cancellables = Set<AnyCancellable>()

  init() {
    model = LogoSettingsModel()
    bindModelChanges()
  }

  init(model: LogoSettingsModel) {
    self.model = model
    bindModelChanges()
  }

  private func bindModelChanges() {
    model.objectWillChange
      .sink { [weak self] _ in
        self?.objectWillChange.send()
      }
      .store(in: &cancellables)
  }

  func presentDeleteConfirmation() {
    showDeleteConfirmation = true
  }

  func deleteLogo() {
    model.deleteLogo()
    showDeleteConfirmation = false
  }

  func importPhoto(data: Data) {
    model.importPhoto(data: data)
  }
}
