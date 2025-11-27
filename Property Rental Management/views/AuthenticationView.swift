//
//  AuthenticationView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 30/09/2025.
//

import SwiftUI
import Combine
import GoogleSignIn // <-- Import
import GoogleSignInSwift // <-- Import

struct AuthenticationView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var rentalManager: RentalManager

    var onContinueAsGuest: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            // Animated Gradient Background
            AnimatedBackground()
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 50)

                    // App Icon and Title
                    VStack(alignment: .center, spacing: 10) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .shadow(radius: 10)

                        Text("Property Rental Management")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 40)

                    // Glassmorphic Card
                    VStack(spacing: 20) {
                        Text(isSignUp ? "Create Your Account" : "Welcome Back")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))

                        CustomTextField(placeholder: "Email", text: $email, iconName: "envelope.fill")
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textContentType(.emailAddress) // Added for autofill

                        CustomTextField(placeholder: "Password", text: $password, iconName: "lock.fill", isSecure: true)
                             .textContentType(isSignUp ? .newPassword : .password) // Added for autofill

                        if !isSignUp {
                            Button(action: handleForgotPassword) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing) // Align right
                        }

                        // Primary Action Button (Email/Password)
                        Button(action: handleAuthentication) {
                            HStack { // Use HStack for ProgressView alignment
                                Spacer()
                                if isProcessing && !(errorMessage == nil && successMessage == nil) { // Show ProgressView only during email/pass processing
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 5) // Add padding if needed
                                }
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.teal.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .disabled(isProcessing)


                        Divider()
                            .background(Color.white.opacity(0.5))


                        // --- Start: Added Google Sign-In Button ---
                        GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: isProcessing ? .disabled : .normal)) { // Disable button while processing
                             handleGoogleSignIn()
                         }
                         .disabled(isProcessing) // Also disable interaction
                         .padding(.bottom, 5) // Add some bottom padding
                         // --- End: Added Google Sign-In Button ---

                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .shadow(radius: 20)
                    .padding(.horizontal, 20)

                    // Error and Success Messages
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding(10) // Add padding
                            .frame(maxWidth: .infinity) // Make it full width
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .transition(.opacity) // Add transition
                    } else if let successMessage = successMessage {
                        Text(successMessage)
                            .foregroundColor(.white)
                            .padding(10) // Add padding
                            .frame(maxWidth: .infinity) // Make it full width
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .transition(.opacity) // Add transition
                    }

                    Spacer()

                    // Footer Buttons
                    VStack(spacing: 15) {
                        Button(action: {
                            withAnimation { // Add animation for toggle
                                isSignUp.toggle()
                                clearMessages()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .fontWeight(.bold)
                            }
                            .font(.footnote)
                            .foregroundColor(.white)
                        }

                        Button(action: onContinueAsGuest) {
                            Text("Continue as Guest")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .disabled(isProcessing)
                    .padding(.bottom, 20)
                }
            }
        }
        // Clear messages when view disappears
        .onDisappear {
            clearMessages()
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // Renamed function specific to Google Sign In
    private func handleGoogleSignIn() {
         isProcessing = true
         clearMessages()
         firebaseManager.signInWithGoogle(rentalManager: rentalManager) { error in
             handleAuthResult(error: error, isGoogleSignIn: true) // Pass flag
         }
     }

    // Handles Email/Password Authentication
    private func handleAuthentication() {
        withAnimation { // Wrap state changes in animation
            isProcessing = true
            clearMessages()
        }

        if isSignUp {
            // *** FIX HERE ***
            // Wrap the call in a closure to match the expected signature.
            firebaseManager.signUp(email: email, password: password, rentalManager: rentalManager) { error in
                handleAuthResult(error: error, isGoogleSignIn: false)
            }
        } else {
            // *** FIX HERE ***
            // Wrap the call in a closure to match the expected signature.
            firebaseManager.signIn(email: email, password: password, rentalManager: rentalManager) { error in
                handleAuthResult(error: error, isGoogleSignIn: false)
            }
        }
    }

    private func handleForgotPassword() {
        withAnimation {
             isProcessing = true
             clearMessages()
         }

        firebaseManager.forgotPassword(email: email) { error in
            withAnimation { // Animate message appearance
                isProcessing = false // Reset processing state *after* completion
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    successMessage = "Password reset email sent. Please check your inbox."
                }
            }
        }
    }

    // Updated to handle both auth types and reset isProcessing
    private func handleAuthResult(error: Error?, isGoogleSignIn: Bool = false) {
         // Always reset processing state on the main thread after completion
         DispatchQueue.main.async {
             withAnimation {
                 if let error = error {
                     self.errorMessage = error.localizedDescription
                     self.isProcessing = false // Reset on error
                 } else {
                     // Determine success message based on auth type
                     if isGoogleSignIn {
                         self.successMessage = "Google sign in successful! Loading..."
                     } else {
                         self.successMessage = isSignUp ? "Account created! Logging in..." : "Sign in successful! Loading..."
                     }
                     // Keep isProcessing true on success, as the view will transition away
                 }
             }
         }
     }
}

// Animated Background View (No changes needed)
struct AnimatedBackground: View {
    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)

    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    // New, more professional color palette
    let colors = [
        Color(red: 0.1, green: 0.3, blue: 0.5), // Deep Blue
        Color.cyan,
        Color.teal,
        Color(red: 0.2, green: 0.5, blue: 0.4)  // Dark Green
    ]

    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors), startPoint: start, endPoint: end)
            .animation(Animation.easeInOut(duration: 6).repeatForever(), value: start)
            .onReceive(timer) { _ in
                // Simplified animation logic slightly
                withAnimation {
                    self.start = UnitPoint(x: Double.random(in: -1...1), y: Double.random(in: -2...0))
                    self.end = UnitPoint(x: Double.random(in: -1...1), y: Double.random(in: 1...3))
                }
            }
    }
}


// Custom Text Field View (No changes needed)
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var iconName: String
    var isSecure: Bool = false

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20) // Give icon consistent width
            if isSecure {
                SecureField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white) // Ensure text color is white
            } else {
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white) // Ensure text color is white
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// Helper for placeholder color (No changes needed)
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
