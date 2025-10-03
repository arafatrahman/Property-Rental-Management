//
//  AuthenticationView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 30/09/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var rentalManager: RentalManager // Add this line

    // This property will hold the function passed from the parent view.
    var onContinueAsGuest: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    // A state to disable the buttons while an operation is in progress.
    @State private var isProcessing = false

    var body: some View {
        VStack {
            Text("Property Rental Management")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)

            TextField("Email", text: $email)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5.0)
                .padding(.bottom, 20)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(5.0)
                .padding(.bottom, 20)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if let successMessage = successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .padding()
            }

            Button(action: {
                // The button action is now in a separate function.
                handleAuthentication()
            }) {
                // Show a progress indicator while processing.
                if isProcessing {
                    ProgressView()
                } else {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(width: 220, height: 60)
            .background(Color.blue)
            .cornerRadius(15.0)
            // Disable the button while processing to prevent multiple taps.
            .disabled(isProcessing)
            .padding(.bottom, 10)

            // Disable other buttons while processing
            Group {
                Button(action: {
                    isSignUp.toggle()
                    // Clear messages when toggling
                    errorMessage = nil
                    successMessage = nil
                }) {
                    Text(isSignUp ? "Have an account? Sign In" : "Don't have an account? Sign Up")
                }
                
                Button(action: {
                    // Call the function that was passed in from the parent.
                    onContinueAsGuest()
                }) {
                    Text("Continue without an account")
                }.padding(.top, 20)
            }
            .disabled(isProcessing)
            
        }
        .padding()
    }

    // A dedicated function to handle the logic.
    private func handleAuthentication() {
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        // ✅ CORRECTED LOGIC: Call the appropriate function directly.
        if isSignUp {
            firebaseManager.signUp(email: email, password: password, rentalManager: rentalManager) { error in
                handleAuthResult(error: error)
            }
        } else {
            firebaseManager.signIn(email: email, password: password) { error in
                handleAuthResult(error: error)
            }
        }
    }

    // ✅ ADDED: A helper function to handle the result from Firebase.
    private func handleAuthResult(error: Error?) {
        if let error = error {
            self.errorMessage = error.localizedDescription
            self.isProcessing = false // Re-enable buttons on error
        } else {
            // Show success message. The transition will now happen automatically.
            self.successMessage = isSignUp ? "Account created! Logging in..." : "Sign in successful! Loading..."
            // The isProcessing flag remains true to keep the UI disabled during the view switch.
        }
    }
}
