import SwiftUI
import Combine
import AuthenticationServices
import GoogleSignIn
import FacebookLogin

class AuthViewModel: ObservableObject {
    @Published var name     = ""
    @Published var email    = ""
    @Published var password = ""
    @Published var phone    = ""
    @Published var confirmPassword = ""

    @Published var isLoading  = false
    @Published var errorMsg: String? = nil
    @Published var isLoggedIn = false

    private let auth = AuthService.shared

    // Check if token exists on launch
    func checkSession() async {
        guard TokenStore.accessToken != nil else { return }
        do {
            let user = try await auth.fetchMe()
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .userDidSignIn,
                    object: user
                )
                isLoggedIn = true
            }
        } catch {
            TokenStore.clear()
        }
    }

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            await setError("Please enter email and password")
            return
        }
        await setLoading(true)
        do {
            let user = try await auth.login(email: email.lowercased().trimmingCharacters(in: .whitespaces), password: password)
            await MainActor.run {
                NotificationCenter.default.post(name: .userDidSignIn, object: user)
                isLoggedIn = true
                isLoading  = false
                errorMsg   = nil
            }
        } catch let err as APIError {
            await setError(err.errorDescription ?? "Login failed")
        } catch {
            await setError(error.localizedDescription)
        }
    }

    func register() async {
        guard !name.isEmpty else { await setError("Name is required"); return }
        guard !email.isEmpty else { await setError("Email is required"); return }
        guard password.count >= 8 else { await setError("Password must be at least 8 characters"); return }
        guard password == confirmPassword else { await setError("Passwords do not match"); return }

        await setLoading(true)
        do {
            let user = try await auth.register(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                password: password,
                phone: phone.isEmpty ? nil : phone
            )
            await MainActor.run {
                NotificationCenter.default.post(name: .userDidSignIn, object: user)
                isLoggedIn = true
                isLoading  = false
                errorMsg   = nil
            }
        } catch let err as APIError {
            await setError(err.errorDescription ?? "Registration failed")
        } catch {
            await setError(error.localizedDescription)
        }
    }

    func logout() async {
        await auth.logout()
        await MainActor.run {
            isLoggedIn = false
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        await setLoading(true)
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData   = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                await setError("Apple sign in failed")
                return
            }
            let email = credential.email
            let nameParts = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
            let fullName = nameParts.isEmpty ? nil : nameParts.joined(separator: " ")
            do {
                let user = try await auth.signInWithApple(
                    identityToken: identityToken,
                    email: email,
                    fullName: fullName
                )
                await signInSuccess(user: user)
            } catch let err as APIError {
                await setError(err.errorDescription ?? "Apple sign in failed")
            } catch {
                await setError(error.localizedDescription)
            }
        case .failure(let error):
            // ASAuthorizationError.canceled (code 1001) means user dismissed — don't show error
            let nsError = error as NSError
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                await setLoading(false)
            } else {
                await setError(error.localizedDescription)
            }
        }
    }

    // MARK: - Google Sign In

    func loginWithGoogle() async {
        let rootVC = await MainActor.run { keyWindowRootViewController() }
        guard let rootVC else { return }
        await setLoading(true)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                await setError("Google sign in failed")
                return
            }
            let user = try await auth.signInWithGoogle(idToken: idToken)
            await signInSuccess(user: user)
        } catch let err as APIError {
            await setError(err.errorDescription ?? "Google sign in failed")
        } catch {
            await setError(error.localizedDescription)
        }
    }

    // MARK: - Facebook Sign In

    func loginWithFacebook() async {
        let rootVC = await MainActor.run { keyWindowRootViewController() }
        guard let rootVC else { return }
        await setLoading(true)
        do {
            let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                LoginManager().logIn(permissions: ["public_profile", "email"], from: rootVC) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let result, !result.isCancelled, let tokenString = result.token?.tokenString else {
                        continuation.resume(throwing: APIError.serverError(0, "Facebook sign in cancelled"))
                        return
                    }
                    continuation.resume(returning: tokenString)
                }
            }
            let user = try await auth.signInWithFacebook(accessToken: token)
            await signInSuccess(user: user)
        } catch let err as APIError {
            await setError(err.errorDescription ?? "Facebook sign in failed")
        } catch {
            await setError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func signInSuccess(user: APIUser) {
        NotificationCenter.default.post(name: .userDidSignIn, object: user)
        isLoggedIn = true
        isLoading  = false
        errorMsg   = nil
    }

    @MainActor
    private func keyWindowRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }

    @MainActor
    private func setLoading(_ v: Bool) { isLoading = v; if v { errorMsg = nil } }

    @MainActor
    private func setError(_ msg: String) { isLoading = false; errorMsg = msg }
}

extension Notification.Name {
    static let userDidSignIn  = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}
