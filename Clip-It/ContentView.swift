//
//  ContentView.swift
//  Clip-It
//
//  Created by Adetunji Adeyinka on 17/03/2026.
//

import SwiftUI
import UIKit
import RevenueCat

struct ContentView: View {
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false


    init (){
        Purchases.configure(withAPIKey: "test_yRqREihRCwAvLeRVfCqsJzeHJaJ")
    }

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
                .onAppear {
                    AppDelegate.applyPortraitOrientation()
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedWelcome)
    }
}

#Preview {
    ContentView()
}
