//
//  SubscriptionViewModel.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 24/03/2026.
//

import Foundation
import RevenueCat
import Combine

@MainActor
final class SubscriptionViewModel: ObservableObject {
  @Published private(set) var isPro = false
  @Published private(set) var isLoading = false
  private let stateService = BroadcastStateService()

  func refreshStatus() async {
    guard Purchases.isConfigured else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      let customerInfo = try await Purchases.shared.customerInfo()
      isPro = !customerInfo.entitlements.active.isEmpty
      stateService.setIsProUser(isPro)
    } catch {
      // Keep previous state when refresh fails to avoid flipping paid users to free unexpectedly.
    }
  }

  /// Refreshes offerings from RevenueCat / StoreKit before showing the paywall (rate-limited by the SDK).
  func syncOfferingsIfNeeded() async {
    guard Purchases.isConfigured else { return }
    do {
      _ = try await Purchases.shared.syncAttributesAndOfferingsIfNeeded()
    } catch {
      // Paywall will use last cached offerings if sync fails.
    }
  }
}
