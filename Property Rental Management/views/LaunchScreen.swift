//
//  LaunchScreen.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 08/10/2025.
//

import SwiftUI

struct LaunchScreen: View {
    @EnvironmentObject private var firebaseManager: FirebaseManager
    @EnvironmentObject private var rentalManager: RentalManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @AppStorage("hasChosenGuestMode") private var hasChosenGuestMode: Bool = false

    var body: some View {
        Group {
            if hasChosenGuestMode {
                MainTabView()
                    .environmentObject(rentalManager)
                    .environmentObject(settingsManager)
                    .environmentObject(firebaseManager)
                    .onAppear {
                        rentalManager.loadData()
                    }
            } else {
                switch firebaseManager.authState {
                case .unknown:
                    ProgressView()
                case .signedOut:
                    AuthenticationView(onContinueAsGuest: setGuestMode)
                        .environmentObject(firebaseManager)
                        .environmentObject(rentalManager)
                case .signedIn:
                    // Show a progress view if we are migrating, otherwise show the main tab view.
                    if firebaseManager.isMigratingGuestData {
                        ProgressView("Migrating your data...")
                    } else {
                        MainTabView()
                            .environmentObject(rentalManager)
                            .environmentObject(settingsManager)
                            .environmentObject(firebaseManager)
                    }
                }
            }
        }
        .onAppear {
             // This ensures that if the app is launched while already signed in (and not migrating), data is loaded.
            if firebaseManager.authState == .signedIn && !firebaseManager.isMigratingGuestData {
                rentalManager.loadData()
            }
        }
    }
    
    func setGuestMode() {
        self.hasChosenGuestMode = true
    }
}

struct LaunchScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}
