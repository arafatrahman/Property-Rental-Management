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

class FirebaseManager: ObservableObject {
    @Published var isSignedIn = false
    private var db = Firestore.firestore()

    // ✅ ADDED: An init() method to start listening for auth changes immediately.
    init() {
        // This listener is the key. It automatically updates `isSignedIn` whenever a user
        // signs in or out, which in turn causes the UI to update.
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isSignedIn = user != nil
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            completion(error)
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            completion(error)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
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
}
