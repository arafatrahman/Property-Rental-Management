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
        if hasChosenGuestMode {
            MainTabView()
                .environmentObject(rentalManager)
                .environmentObject(settingsManager)
                .environmentObject(firebaseManager)
        } else {
            switch firebaseManager.authState {
            case .unknown:
                ProgressView()
            case .signedOut:
                AuthenticationView(onContinueAsGuest: setGuestMode)
                    .environmentObject(firebaseManager)
                    .environmentObject(rentalManager)
            case .signedIn:
                MainTabView()
                    .environmentObject(rentalManager)
                    .environmentObject(settingsManager)
                    .environmentObject(firebaseManager)
                    .onAppear {
                        NotificationManager.instance.requestAuthorization()
                        rentalManager.loadData()
                    }
                    .onChange(of: firebaseManager.authState) { _, newAuthState in
                        if newAuthState == .signedIn {
                            rentalManager.loadData()
                        }
                    }
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
