//
//  LoginView.swift
//  Tabs
//
//  Created by Aaditya Rana on 3/22/26.
//
//  Requires:
//    - FirebaseAuth (from firebase-ios-sdk)
//    - GoogleSignIn + GoogleSignInSwift (from https://github.com/google/GoogleSignIn-iOS)
//    - "Sign in with Apple" capability enabled in Xcode → Signing & Capabilities
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var vm: AppViewModel

    @State private var currentNonce: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.tabsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon + title
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.tabsPrimary)
                            .frame(width: 84, height: 84)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 22, height: 32)
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.white)
                                    .frame(width: 20, height: 13)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.tabsGreen)
                                    .frame(width: 20, height: 13)
                            }
                        }
                    }

                    Text("Log in to Tabs")
                        .font(.tabsTitle(32))
                        .foregroundColor(.tabsPrimary)
                }

                Spacer()

                // Error message
                if let err = errorMessage ?? vm.authError {
                    Text(err)
                        .font(.tabsBody(13))
                        .foregroundColor(.tabsRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                }

                // Auth buttons
                VStack(spacing: 12) {

                    // ── Sign in with Apple ──────────────────────────────────
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            guard
                                let appleCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                                let nonce = currentNonce,
                                let tokenData = appleCredential.identityToken,
                                let tokenString = String(data: tokenData, encoding: .utf8)
                            else {
                                errorMessage = "Apple sign-in failed. Please try again."
                                return
                            }
                            let credential = OAuthProvider.appleCredential(
                                withIDToken: tokenString,
                                rawNonce: nonce,
                                fullName: appleCredential.fullName
                            )
                            Task {
                                isLoading = true
                                await vm.signInWithApple(
                                    credential: credential,
                                    fullName: appleCredential.fullName
                                )
                                isLoading = false
                            }
                        case .failure(let error):
                            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(.tabsPillRadius)

                    // ── Sign in with Google ─────────────────────────────────
                    Button {
                        Task { await signInWithGoogle() }
                    } label: {
                        HStack(spacing: 12) {
                            // Google "G" logo
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 24, height: 24)
                                Text("G")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                            }
                            Text("Continue with Google")
                                .font(.tabsBody(16, weight: .semibold))
                                .foregroundColor(.tabsPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.tabsCard)
                        .cornerRadius(.tabsPillRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: .tabsPillRadius)
                                .strokeBorder(Color.tabsPrimary.opacity(0.15), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
        .overlay { if isLoading { LoadingOverlay() } }
    }

    // MARK: - Google Sign-In

    private func signInWithGoogle() async {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else { return }

        isLoading = true
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in failed: missing token."
                isLoading = false
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let name  = result.user.profile?.name  ?? "Player"
            let email = result.user.profile?.email ?? ""
            await vm.signInWithGoogle(credential: credential, name: name, email: email)
        } catch {
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    // MARK: - Nonce Helpers (required by Firebase for Sign in with Apple)

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
