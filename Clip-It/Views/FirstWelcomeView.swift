//
//  FirstWelcomeView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 18/03/2026.
//

import SwiftUI

private let primaryColor = Color("PrimaryColor")
private let buttonCornerRadius: CGFloat = 32

struct FirstWelcomeView: View {
    @Binding var isPresented: Bool
    @State private var currentStep: Int = 0

    private let steps: [WelcomeStep] = [
        WelcomeStep(
            icon: "gamecontroller.fill",
            title: "Never Miss the Moment",
            description:
                "Gaming and you just one shotted someone but forgot to record? Use Clip It."
        ),
        WelcomeStep(
            icon: "plus.circle.fill",
            title: "Add to Control Centre",
            description:
                "Add Clip It to your Control Centre so you can start recording anytime."
        ),
        WelcomeStep(
            icon: "record.circle.fill",
            title: "Record & Clip",
            description:
                "Press Record in the app. Once you hit your moment, press the Clip button in the Control Centre."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) {
                    index,
                    step in
                    WelcomeStepView(step: step)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            stepIndicator

            nextButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentStep
                            ? primaryColor : Color(.systemGray4)
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 24)
    }

    private var nextButton: some View {
        Button {
            if currentStep < steps.count - 1 {
                withAnimation {
                    currentStep += 1
                }
            } else {
                isPresented = false
            }
        } label: {
            Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                .font(SofiaFont.semiBold(size: 18))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

private struct WelcomeStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

private struct WelcomeStepView: View {
    let step: WelcomeStep

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: step.icon)
                .font(.system(size: 80))
                .foregroundStyle(primaryColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text(step.title)
                    .font(SofiaFont.bold(size: 24))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(SofiaFont.regular(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

#Preview {
    FirstWelcomeView(isPresented: .constant(true))
}
