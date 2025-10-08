//
//  RentalManagementApp.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI
import Firebase

@main
struct RentalManagementApp: App {
    @StateObject private var firebaseManager: FirebaseManager
    @StateObject private var rentalManager: RentalManager
    
    @StateObject private var settingsManager = SettingsManager()
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage("hasChosenGuestMode") private var hasChosenGuestMode: Bool = false

    init() {
        FirebaseApp.configure()
        
        let fm = FirebaseManager()
        _firebaseManager = StateObject(wrappedValue: fm)
        _rentalManager = StateObject(wrappedValue: RentalManager(firebaseManager: fm))
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(rentalManager)
                .environmentObject(settingsManager)
                .environmentObject(firebaseManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        rentalManager.updateAllTenantBalances()
                    }
                }
        }
    }
    
    func setGuestMode() {
        self.hasChosenGuestMode = true
    }
}
