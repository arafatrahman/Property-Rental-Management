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
            // ✅ MODIFIED: The entire view logic is updated to prevent flickering.
            if hasChosenGuestMode {
                MainTabView()
                    .environmentObject(rentalManager)
                    .environmentObject(settingsManager)
                    .environmentObject(firebaseManager)
            } else {
                switch firebaseManager.authState {
                case .unknown:
                    // Show a loading view while Firebase checks the auth state.
                    ProgressView()
                case .signedOut:
                    // Once Firebase confirms the user is signed out, show the login view.
                    AuthenticationView(onContinueAsGuest: setGuestMode)
                        .environmentObject(firebaseManager)
                        .environmentObject(rentalManager)
                case .signedIn:
                    // Once Firebase confirms the user is signed in, show the main app.
                    MainTabView()
                        .environmentObject(rentalManager)
                        .environmentObject(settingsManager)
                        .environmentObject(firebaseManager)
                        .onAppear {
                            NotificationManager.instance.requestAuthorization()
                            rentalManager.loadData()
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                rentalManager.updateAllTenantBalances()
                            }
                        }
                        .onChange(of: firebaseManager.authState) { _, newAuthState in
                            if newAuthState == .signedIn {
                                rentalManager.loadData()
                            }
                        }
                }
            }
        }
    }
    
    func setGuestMode() {
        self.hasChosenGuestMode = true
    }
}
