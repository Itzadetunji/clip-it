//
//  SettingsView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 24/03/2026.
//

import RevenueCatUI
import SwiftUI

private let settingsPrimaryColor = Color("PrimaryColor")
private let clipItBaseURL = "https://get-clip-it.vercel.app"

struct SettingsView: View {
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Settings")
                .font(SofiaFont.bold(size: 28))

            subscriptionSection
            Spacer()
            legalSection
        }
        .padding(24)

        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall, onDismiss: refreshSubscriptionState) {
            PaywallView(displayCloseButton: true)
        }
        .task {
            await subscriptionViewModel.refreshStatus()
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clip-It Pro")
                .font(SofiaFont.semiBold(size: 18))
                .foregroundStyle(.primary)

            if subscriptionViewModel.isPro {
                Text("You are currently on Pro.")
                    .font(SofiaFont.regular(size: 14))
                    .foregroundStyle(.secondary)

                Button {
                    // Placeholder for future logo picker/upload flow.
                } label: {
                    HStack {
                        Text("Add Logo")
                            .font(SofiaFont.semiBold(size: 16))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "photo")
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(settingsPrimaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                Text("Upgrade to set custom clip durations up to 120 seconds.")
                    .font(SofiaFont.regular(size: 14))
                    .foregroundStyle(.secondary)

                Button {
                    showPaywall = true
                } label: {
                    Text("Go Pro")
                        .font(SofiaFont.semiBold(size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(settingsPrimaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var legalSection: some View {
        HStack(alignment: .center, spacing: 32) {
            Button("Privacy") {
                openPath("/privacy")
            }
            .buttonStyle(.plain)
            .font(SofiaFont.regular(size: 16))
            .foregroundStyle(settingsPrimaryColor)

            Button("Support") {
                openPath("/support")
            }
            .buttonStyle(.plain)
            .font(SofiaFont.regular(size: 16))
            .foregroundStyle(settingsPrimaryColor)

            Button("Terms") {
                openPath("/terms")
            }
            .buttonStyle(.plain)
            .font(SofiaFont.regular(size: 16))
            .foregroundStyle(settingsPrimaryColor)
        }
        .padding(16)
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity)
    }

    private func openPath(_ path: String) {
        guard let url = URL(string: clipItBaseURL + path) else { return }
        openURL(url)
    }

    private func refreshSubscriptionState() {
        Task {
            await subscriptionViewModel.refreshStatus()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SubscriptionViewModel())
    }
}
