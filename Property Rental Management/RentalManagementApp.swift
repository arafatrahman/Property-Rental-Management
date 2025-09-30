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
    @StateObject private var rentalManager = RentalManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var firebaseManager = FirebaseManager()
    @Environment(\.scenePhase) var scenePhase
    
    @AppStorage("hasChosenGuestMode") private var hasChosenGuestMode: Bool = false

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if !firebaseManager.isSignedIn && !hasChosenGuestMode {
                // ✅ MODIFIED: Pass the setGuestMode function directly
                AuthenticationView(onContinueAsGuest: setGuestMode)
                    .environmentObject(firebaseManager)
            } else {
                MainTabView()
                    .environmentObject(rentalManager)
                    .environmentObject(settingsManager)
                    .environmentObject(firebaseManager)
                    .onAppear {
                        NotificationManager.instance.requestAuthorization()
                        if firebaseManager.isSignedIn {
                            rentalManager.loadDataFromFirebase()
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            rentalManager.updateAllTenantBalances()
                        }
                    }
            }
        }
    }
    
    // ✅ This function is now passed directly to the view
    func setGuestMode() {
        self.hasChosenGuestMode = true
    }
}
