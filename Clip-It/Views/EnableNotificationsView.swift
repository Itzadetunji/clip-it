//
//  EnableNotificationsView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import SwiftUI
import UserNotifications

/// Checks notification access on appear and shows an alert if denied.
/// Add as an overlay to your root view so it runs when the app opens.
struct EnableNotificationsView: View {
    @State private var showAccessDeniedAlert = false

    var body: some View {
        Color.clear
            .onAppear {
                checkNotificationAccess()
            }
            .alert("Notifications Access Required", isPresented: $showAccessDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Clip-It needs notifications to tell you when clips are saved. Please enable them in Settings.")
            }
    }

    private func checkNotificationAccess() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                if settings.authorizationStatus == .denied {
                    showAccessDeniedAlert = true
                }
            }
        }
    }
}

#Preview {
    EnableNotificationsView()
}
