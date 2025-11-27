//
//  RentalManagementApp.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 25/09/2025.
//

import SwiftUI
import Firebase
import GoogleSignIn // <-- Import GoogleSignIn

@main
struct RentalManagementApp: App {
    @StateObject private var firebaseManager: FirebaseManager
    @StateObject private var rentalManager: RentalManager

    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var themeManager = ThemeManager()
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
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        rentalManager.updateAllTenantBalances()
                    }
                }
                .onChange(of: firebaseManager.authState) { _, newAuthState in
                    // This is the key: Only load data if the user is signed in AND we are not in the middle of a guest data migration.
                    if newAuthState == .signedIn && !firebaseManager.isMigratingGuestData {
                        rentalManager.loadData()
                    }
                }
                .onOpenURL { url in // <-- Add this modifier to handle Google Sign-In redirect
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    func setGuestMode() {
        self.hasChosenGuestMode = true
    }
}
