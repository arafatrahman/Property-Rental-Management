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
    private var db = Firestore.firestore()

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // Update the authState based on the user's status.
            if user != nil {
                self?.authState = .signedIn
            } else {
                self?.authState = .signedOut
            }
        }
    }

    func signIn(email: String, password: String, rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                completion(error)
                return
            }
            // On successful sign-in, clear any existing data before loading the new data.
            DispatchQueue.main.async {
                rentalManager.clearData()
                rentalManager.loadData()
                completion(nil)
            }
        }
    }

    func signUp(email: String, password: String, rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                completion(error)
                return
            }
            // After a successful sign-up, clear existing data and save the local data to Firebase.
            DispatchQueue.main.async {
                rentalManager.clearData()
                self?.saveData(appData: rentalManager.appData())
                completion(nil)
            }
        }
    }
    
    // Add this new function for password reset
    func forgotPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error)
        }
    }

    func signOut(rentalManager: RentalManager) {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                rentalManager.clearData()
                rentalManager.loadData() // This will now load the local data
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    func saveData(appData: AppData) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try db.collection("users").document(userId).setData(from: appData)
        } catch {
            print("Error saving data to Firestore: \(error.localizedDescription)")
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
                print("Document does not exist or error fetching document: \(error?.localizedDescription ?? "")")
                completion(nil)
            }
        }
    }
    
    func deleteAccount(rentalManager: RentalManager, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        // 1. Delete user data from Firestore
        db.collection("users").document(user.uid).delete { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            // 2. Delete user authentication record
            user.delete { error in
                if let error = error {
                    completion(error)
                } else {
                    self?.authState = .signedOut
                    rentalManager.clearData()
                    rentalManager.loadData()
                    completion(nil)
                }
            }
        }
    }
}
