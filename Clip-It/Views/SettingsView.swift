//
//  SettingsView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 24/03/2026.
//

import RevenueCat
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
    @State private var watermarkPosition:
        BroadcastStateService.WatermarkPosition = .topRight
    @State private var watermarkOpacityPercent: Double = 50
    @State private var proWatermarkEnabled = false

    private let stateService = BroadcastStateService()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    subscriptionSection

                    if subscriptionViewModel.isPro {
                        LogoSettingsSectionView(
                            viewModel: logoSettingsViewModel
                        )
                        watermarkSettingsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 96)
            }

            legalSection
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall, onDismiss: refreshSubscriptionState) {
            if Purchases.isConfigured {
                PaywallView(displayCloseButton: true)
            } else {
                paywallUnavailableView
            }
        }
        .task {
            await subscriptionViewModel.refreshStatus()
            loadWatermarkSettings()
        }
        .onChange(of: proWatermarkEnabled) { _, _ in
            saveWatermarkSettings()
        }
        .onChange(of: watermarkPosition) { _, _ in
            saveWatermarkSettings()
        }
        .onChange(of: watermarkOpacityPercent) { _, _ in
            saveWatermarkSettings()
        }
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clip-It Pro")
                .font(SofiaFont.semiBold(size: 18))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 16) {
                if subscriptionViewModel.isPro {
                    Text("You are currently Proooo 🚀")
                        .font(SofiaFont.regular(size: 16))
                        .foregroundStyle(.secondary)

                    Button {
                        openManageSubscriptions()
                    } label: {
                        Text("Manage Subscription")
                            .font(SofiaFont.semiBold(size: 16))
                            .foregroundStyle(.white)
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
                            subtitle: "Remove forced Clip-It logo watermark."
                        )
                        subscriptionContainer(
                            iconName: TablerIcons.marqueeOutlined,
                            title: "Use Your Own Logo",
                            subtitle: "Upload and place your logo watermark."
                        )
                        subscriptionContainer(
                            iconName: TablerIcons.clockEditOutlined,
                            title: "Custom Time Clips",
                            subtitle:
                                "Set custom clip length up to 120 seconds."
                        )
                        subscriptionContainer(
                            iconName: TablerIcons.starFilled,
                            title: "Premium Support",
                            subtitle: "Priority support for any issue"
                        )
                    }

                    Button {
                        Task {
                            await subscriptionViewModel.syncOfferingsIfNeeded()
                            showPaywall = true
                        }
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
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var watermarkSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watermark Settings")
                .font(SofiaFont.semiBold(size: 18))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 14) {
                Toggle("Use Watermark", isOn: $proWatermarkEnabled)
                    .font(SofiaFont.regular(size: 16))
                    .tint(primaryColor)

                Picker("Position", selection: $watermarkPosition) {
                    Text("Top Left").tag(
                        BroadcastStateService.WatermarkPosition.topLeft
                    )
                    Text("Top Right").tag(
                        BroadcastStateService.WatermarkPosition.topRight
                    )
                    Text("Bottom Left").tag(
                        BroadcastStateService.WatermarkPosition.bottomLeft
                    )
                    Text("Bottom Right").tag(
                        BroadcastStateService.WatermarkPosition.bottomRight
                    )
                }
                .pickerStyle(.menu)
                .font(SofiaFont.regular(size: 15))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Opacity: \(Int(watermarkOpacityPercent))%")
                        .font(SofiaFont.regular(size: 15))
                        .foregroundStyle(.secondary)

                    Slider(
                        value: $watermarkOpacityPercent,
                        in: 0...100,
                        step: 1
                    )
                    .tint(primaryColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func subscriptionContainer(
        iconName: UIImage,
        title: String,
        subtitle: String
    )
        -> some View
    {
        HStack(alignment: .top, spacing: 10) {
            Image(uiImage: iconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .foregroundStyle(Color("PrimaryColor"))
                .frame(width: 24, height: 24)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 100))
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(.accent, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SofiaFont.bold(size: 16))
                Text(subtitle)
                    .font(SofiaFont.regular(size: 14))
                    .foregroundStyle(Color.primary.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paywallUnavailableView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Purchases aren’t set up yet")
                    .font(SofiaFont.semiBold(size: 18))
                Text(
                    "Add your RevenueCat public API key to Config.xcconfig as REVENUECAT_API_KEY, then clean the build folder (Shift+⌘+K) and build again. SwiftUI previews don’t run app launch, so use the full app scheme."
                )
                .font(SofiaFont.regular(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showPaywall = false }
                }
            }
        }
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

    private func loadWatermarkSettings() {
        watermarkPosition = stateService.getWatermarkPosition()
        watermarkOpacityPercent = stateService.getWatermarkOpacity() * 100
        proWatermarkEnabled = stateService.isProWatermarkEnabled()
    }

    private func saveWatermarkSettings() {
        stateService.setWatermarkPosition(watermarkPosition)
        stateService.setWatermarkOpacity(watermarkOpacityPercent / 100)
        stateService.setProWatermarkEnabled(proWatermarkEnabled)
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
            loadWatermarkSettings()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SubscriptionViewModel())
    }
}
