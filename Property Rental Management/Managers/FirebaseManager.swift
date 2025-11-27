//
//  FirebaseManager.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 30/09/2025.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import GoogleSignIn // <-- Import GoogleSignIn
import GoogleSignInSwift // <-- Import for SwiftUI button (optional but recommended)
import SwiftUI // <-- Import SwiftUI for UIApplication access

// An enum to represent the different authentication states.
enum AuthState {
    case unknown, signedIn, signedOut
}

class FirebaseManager: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var isMigratingGuestData = false // Flag to prevent race conditions
    private var db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if user != nil {
                    self?.authState = .signedIn
                } else {
                    self?.authState = .signedOut
                }
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signIn(email: String, password: String, rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                completion(error)
                return
            }
            DispatchQueue.main.async {
                rentalManager.clearData()
                // The authState listener in RentalManagementApp will now correctly trigger loadData()
                completion(nil)
            }
        }
    }

    func signUp(email: String, password: String, rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        // 1. Set the flag to true. This immediately blocks any premature data loading listeners.
        self.isMigratingGuestData = true

        // 2. Capture the current guest data that's in memory.
        let guestData = rentalManager.appData()

        // 3. Create the user account in Firebase Authentication.
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                // If user creation fails, reset the flag and report the error.
                self.isMigratingGuestData = false
                completion(error)
                return
            }

            guard let userId = authResult?.user.uid else {
                self.isMigratingGuestData = false
                completion(NSError(domain: "SignUpError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User object not found after creation."]))
                return
            }

            // 4. Explicitly upload the captured guest data to the new user's Firestore document.
            do {
                try self.db.collection("users").document(userId).setData(from: guestData) { saveError in
                    // 5. After the upload attempt, reset the flag on the main thread.
                    DispatchQueue.main.async {
                        self.isMigratingGuestData = false
                        if let saveError = saveError {
                            completion(saveError)
                        } else {
                            print("Guest data successfully migrated to new user account.")
                            // The authState change will now correctly trigger the data load in RentalManagementApp.
                            completion(nil)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isMigratingGuestData = false
                    completion(error)
                }
            }
        }
    }

    // --- Start: Added Google Sign-In Function ---
    @MainActor // <-- Ensure function runs on main thread
    func signInWithGoogle(rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        // 1. Get the top view controller (needed for the sign-in presentation)
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            completion(NSError(domain: "AppAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller."]))
            return
        }

        // 2. Start the Google Sign-In flow
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] signInResult, error in
            guard let self = self else { return }

            if let error = error {
                // Check if the error is user cancellation
                 if (error as NSError).code == GIDSignInError.canceled.rawValue {
                     print("Google Sign-In cancelled by user.")
                     // Call completion with nil error, as it's not a technical failure
                     completion(nil)
                 } else {
                     print("Google Sign-In Error: \(error.localizedDescription)")
                     completion(error)
                 }
                return
            }

            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Google Sign-In Error: Missing user or ID token.")
                completion(NSError(domain: "AppAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In failed: Missing user or ID token."]))
                return
            }

            // 3. Create Firebase credential with Google ID token
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: user.accessToken.tokenString)

            // 4. Sign in to Firebase with the credential
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Google Auth Error: \(error.localizedDescription)")
                    completion(error)
                    return
                }

                // Sign-in successful
                print("Successfully signed into Firebase with Google.")
                // Clear local data before loading from Firebase
                // The authState listener in RentalManagementApp will trigger loadData()
                DispatchQueue.main.async {
                     rentalManager.clearData()
                     completion(nil)
                }
            }
        }
    }
    // --- End: Added Google Sign-In Function ---


    func forgotPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email, completion: completion)
    }

    func signOut(rentalManager: RentalManager) {
        // Sign out from Google as well if the user signed in with Google
        GIDSignIn.sharedInstance.signOut()

        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                rentalManager.clearData()
                // No need to call loadData here, guest mode/signed out state handles it
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }


    func saveData(appData: AppData, completion: ((Error?) -> Void)? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in."]))
            return
        }
        do {
            try db.collection("users").document(userId).setData(from: appData) { error in
                if error == nil {
                    print("Data saved to Firebase successfully.")
                }
                completion?(error)
            }
        } catch {
            print("Error encoding data for Firestore: \(error.localizedDescription)")
            completion?(error)
        }
    }

    func loadData(completion: @escaping (AppData?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                do {
                    let appData = try document.data(as: AppData.self)
                    completion(appData)
                } catch {
                    print("Error decoding data from Firestore: \(error.localizedDescription)")
                    completion(nil)
                }
            } else {
                print("Document does not exist or error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil) // Return nil if no data exists, allowing signup to potentially migrate data
            }
        }
    }

    func deleteAccount(rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }

        let userId = user.uid

        // Delete Firestore data first
        db.collection("users").document(userId).delete { [weak self] firestoreError in
            if let firestoreError = firestoreError {
                print("Error deleting Firestore data: \(firestoreError.localizedDescription)")
                 // Decide if you want to proceed with account deletion even if Firestore deletion fails
                 // For now, we'll stop and report the error
                 completion(firestoreError)
                 return
            }

            // If Firestore deletion is successful, delete the Auth account
            user.delete { error in
                 DispatchQueue.main.async {
                     if let error = error {
                         print("Error deleting Auth account: \(error.localizedDescription)")
                         completion(error)
                     } else {
                         print("Account deleted successfully.")
                         // Clear local data after successful deletion
                         rentalManager.clearData()
                         // The auth state listener will handle UI changes
                         completion(nil)
                     }
                 }
             }
        }
    }
}
