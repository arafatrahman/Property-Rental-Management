//
//  AuthenticationView.swift
//  Property Rental Management
//
//  Created by Md Arafat Rahman on 30/09/2025.
//

import SwiftUI
import Combine
// GoogleSignIn imports removed

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
                            .textContentType(.emailAddress)

                        CustomTextField(placeholder: "Password", text: $password, iconName: "lock.fill", isSecure: true)
                             .textContentType(isSignUp ? .newPassword : .password)

                        if !isSignUp {
                            Button(action: handleForgotPassword) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        // Primary Action Button (Email/Password)
                        Button(action: handleAuthentication) {
                            HStack {
                                Spacer()
                                if isProcessing && !(errorMessage == nil && successMessage == nil) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 5)
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
                        
                        // Google Sign-In Button and Divider have been removed here.
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
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    } else if let successMessage = successMessage {
                        Text(successMessage)
                            .foregroundColor(.white)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    Spacer()

                    // Footer Buttons
                    VStack(spacing: 15) {
                        Button(action: {
                            withAnimation {
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
        .onDisappear {
            clearMessages()
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // Handles Email/Password Authentication
    private func handleAuthentication() {
        withAnimation {
            isProcessing = true
            clearMessages()
        }

        if isSignUp {
            firebaseManager.signUp(email: email, password: password, rentalManager: rentalManager) { error in
                handleAuthResult(error: error, isGoogleSignIn: false)
            }
        } else {
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
            withAnimation {
                isProcessing = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    successMessage = "Password reset email sent. Please check your inbox."
                }
            }
        }
    }

    private func handleAuthResult(error: Error?, isGoogleSignIn: Bool = false) {
         DispatchQueue.main.async {
             withAnimation {
                 if let error = error {
                     self.errorMessage = error.localizedDescription
                     self.isProcessing = false
                 } else {
                     if isGoogleSignIn {
                         self.successMessage = "Google sign in successful! Loading..."
                     } else {
                         self.successMessage = isSignUp ? "Account created! Logging in..." : "Sign in successful! Loading..."
                     }
                 }
             }
         }
     }
}

// Animated Background View
struct AnimatedBackground: View {
    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)

    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

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
                withAnimation {
                    self.start = UnitPoint(x: Double.random(in: -1...1), y: Double.random(in: -2...0))
                    self.end = UnitPoint(x: Double.random(in: -1...1), y: Double.random(in: 1...3))
                }
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
                .frame(width: 20)
            if isSecure {
                SecureField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
            } else {
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
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
