//
//  RentalManagementApp.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI

@main
struct RentalManagementApp: App {
    @StateObject private var rentalManager = RentalManager()
    @StateObject private var settingsManager = SettingsManager()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(rentalManager)
                .environmentObject(settingsManager)
                .onAppear(perform: NotificationManager.instance.requestAuthorization)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        rentalManager.updateAllTenantBalances()
                    }
                }
        }
    }
}
