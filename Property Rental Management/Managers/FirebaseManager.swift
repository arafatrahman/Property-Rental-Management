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
    
    func forgotPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email, completion: completion)
    }

    func signOut(rentalManager: RentalManager) {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                rentalManager.clearData()
                rentalManager.loadData()
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
                completion(nil)
            }
        }
    }
    
    func deleteAccount(rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        let userId = user.uid
        user.delete { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            self?.db.collection("users").document(userId).delete { error in
                DispatchQueue.main.async {
                    rentalManager.clearData()
                    rentalManager.loadData()
                    completion(error)
                }
            }
        }
    }
}
