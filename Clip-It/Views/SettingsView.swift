//
//  SettingsView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 24/03/2026.
//

import RevenueCatUI
import SwiftUI
import TablerIcons

private let primaryColor = Color("PrimaryColor")
private let clipItBaseURL = "https://get-clip-it.vercel.app"

struct SettingsView: View {
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @StateObject private var logoSettingsViewModel = LogoSettingsViewModel()

    var body: some View {
        VStack(alignment: .leading) {
            subscriptionSection
            Spacer()
            legalSection
        }
        .padding(24)

        .background(Color(.systemBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall, onDismiss: refreshSubscriptionState) {
            PaywallView(displayCloseButton: true)
        }
        .task {
            await subscriptionViewModel.refreshStatus()
        }
    }

    var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 32) {

            VStack(alignment: .leading) {
                Text("Clip-It Pro")
                    .font(SofiaFont.semiBold(size: 18))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 24) {

                    if !subscriptionViewModel.isPro {
                        Text("You are currently Proooo 🚀")
                            .font(SofiaFont.regular(size: 16))
                            .foregroundStyle(.secondary)

                        Button {
                            openManageSubscriptions()
                        } label: {
                            HStack {
                                Text("Manage Subscription")
                                    .font(SofiaFont.semiBold(size: 16))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(primaryColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            subscriptionContainer(
                                iconName: TablerIcons.cancelOutlined,
                                title: "Remove Watermarks",
                                subtitle: "No more watermarks on your clips"
                            )
                            subscriptionContainer(
                                iconName: TablerIcons.marqueeOutlined,
                                title: "Add Your Logo",
                                subtitle:
                                    "Every Clip You Make Now Has Your logo on it"
                            )
                            subscriptionContainer(
                                iconName: TablerIcons.clockEditOutlined,
                                title: "Custom Time Clips",
                                subtitle:
                                    "No more 10s limit, set your own custom time"
                            )
                            subscriptionContainer(
                                iconName: TablerIcons.starFilled,
                                title: "Premium Support",
                                subtitle: "Priority support for any issue"
                            )
                        }

                        Button {
                            showPaywall = true
                        } label: {
                            Text("Go Pro 🚀")
                                .font(SofiaFont.semiBold(size: 16))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(primaryColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxWidth: 400, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            }

            if !subscriptionViewModel.isPro {
                LogoSettingsSectionView(viewModel: logoSettingsViewModel)
            }
        }
    }

    private func subscriptionContainer(
        iconName: UIImage,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Image(uiImage: iconName)
                    .renderingMode(.template)  // allow tint color
                    .resizable()  // allow manual sizing
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color("PrimaryColor"))
            }
            .frame(width: 24, height: 24)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 100))
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .stroke(.accent, lineWidth: 2)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(
                    SofiaFont.bold(size: 16)
                )
                Text(subtitle).font(
                    SofiaFont.regular(size: 14)
                )
                .foregroundStyle(Color.primary.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legalSection: some View {
        HStack(alignment: .center, spacing: 32) {
            Button("Privacy") {
                openPath("/privacy")
            }
            .buttonStyle(.plain)
            .font(SofiaFont.regular(size: 16))
            .foregroundStyle(primaryColor)

            Button("Support") {
                openPath("/support")
            }
            .buttonStyle(.plain)
            .font(SofiaFont.regular(size: 16))
            .foregroundStyle(primaryColor)

            Button("Terms") {
                openPath("/terms")
            }
            .buttonStyle(.plain)
            .font(SofiaFont.regular(size: 16))
            .foregroundStyle(primaryColor)
        }
        .padding(16)
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity)
    }

    private func openPath(_ path: String) {
        guard let url = URL(string: clipItBaseURL + path) else { return }
        openURL(url)
    }

    private func openManageSubscriptions() {
        guard
            let url = URL(
                string: "https://apps.apple.com/account/subscriptions"
            )
        else { return }
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
