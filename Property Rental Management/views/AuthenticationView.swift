//
//  AuthenticationView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 30/09/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var rentalManager: RentalManager

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

            if !isSignUp { // Only show password field for Sign In
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(5.0)
                    .padding(.bottom, 20)
            } else { // Show password field for Sign Up
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(5.0)
                    .padding(.bottom, 20)
            }


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
                handleAuthentication()
            }) {
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
            .disabled(isProcessing)
            .padding(.bottom, 10)

            Group {
                Button(action: {
                    isSignUp.toggle()
                    clearMessages()
                }) {
                    Text(isSignUp ? "Have an account? Sign In" : "Don't have an account? Sign Up")
                }
                .padding(.bottom, 10)
                
                // Add the "Forgot Password?" button
                if !isSignUp {
                    Button(action: handleForgotPassword) {
                        Text("Forgot Password?")
                    }
                    .padding(.bottom, 20)
                }
                
                Button(action: onContinueAsGuest) {
                    Text("Continue without an account")
                }
                .padding(.top, 20)
            }
            .disabled(isProcessing)
        }
        .padding()
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func handleAuthentication() {
        isProcessing = true
        clearMessages()
        
        if isSignUp {
            firebaseManager.signUp(email: email, password: password, rentalManager: rentalManager, completion: handleAuthResult)
        } else {
            firebaseManager.signIn(email: email, password: password, completion: handleAuthResult)
        }
    }
    
    private func handleForgotPassword() {
        isProcessing = true
        clearMessages()
        
        firebaseManager.forgotPassword(email: email) { error in
            isProcessing = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                successMessage = "Password reset email sent successfully. Please check your inbox."
            }
        }
    }

    private func handleAuthResult(error: Error?) {
        if let error = error {
            self.errorMessage = error.localizedDescription
            self.isProcessing = false
        } else {
            self.successMessage = isSignUp ? "Account created! Logging in..." : "Sign in successful! Loading..."
        }
    }
}
