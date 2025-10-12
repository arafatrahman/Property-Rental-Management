//
//  AuthenticationView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 30/09/2025.
//

import SwiftUI
import Combine

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
                        
                        CustomTextField(placeholder: "Password", text: $password, iconName: "lock.fill", isSecure: true)
                        
                        if !isSignUp {
                            Button(action: handleForgotPassword) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        // Primary Action Button
                        Button(action: handleAuthentication) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        // Updated button color to match the new theme
                        .background(Color.teal.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .disabled(isProcessing)
                        
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
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    } else if let successMessage = successMessage {
                        Text(successMessage)
                            .foregroundColor(.white)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()

                    // Footer Buttons
                    VStack(spacing: 15) {
                        Button(action: {
                            isSignUp.toggle()
                            clearMessages()
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
            firebaseManager.signIn(email: email, password: password, rentalManager: rentalManager, completion: handleAuthResult)
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
                successMessage = "Password reset email sent. Please check your inbox."
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

// Animated Background View
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
                self.start = UnitPoint(x: 4, y: 0)
                self.end = UnitPoint(x: 0, y: 2)
                self.start = UnitPoint(x: -4, y: 20)
                self.start = UnitPoint(x: 4, y: 0)
            }
    }
}

// Custom Text Field View
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var iconName: String
    var isSecure: Bool = false

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.white.opacity(0.7))
            if isSecure {
                SecureField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
            } else {
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .foregroundColor(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// Helper for placeholder color
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
