//
//  ContentView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import SwiftUI
import UIKit

struct ContentView: View {
  @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
  @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

  var body: some View {
    Group {
      if hasCompletedWelcome {
        MainContentView()
          .transition(.opacity)
      } else {
        FirstWelcomeView(
          isPresented: Binding(
            get: { !hasCompletedWelcome },
            set: { if !$0 { hasCompletedWelcome = true } }
          )
        )
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.35), value: hasCompletedWelcome)
    .task {
      await subscriptionViewModel.refreshStatus()
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(SubscriptionViewModel())
}
