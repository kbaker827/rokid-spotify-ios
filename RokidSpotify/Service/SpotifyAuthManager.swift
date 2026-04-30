import Foundation
import CryptoKit
import AuthenticationServices

// MARK: - Spotify OAuth PKCE Auth Manager

@MainActor
final class SpotifyAuthManager: NSObject {

    private let settings = SettingsStore.shared

    // MARK: - PKCE state

    private var codeVerifier: String?

    // MARK: - Login

    /// Opens Spotify login page via ASWebAuthenticationSession.
    func login(presentationAnchor: ASPresentationAnchor) async throws {
        let verifier   = generateCodeVerifier()
        let challenge  = generateCodeChallenge(from: verifier)
        codeVerifier   = verifier

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",             value: settings.clientId),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: SettingsStore.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "scope",                 value: SettingsStore.scopes),
        ]

        guard let authURL = comps.url else {
            throw SpotifyError.authFailed("Could not build auth URL")
        }

        let code = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "rokidspotify"
            ) { callbackURL, error in
                if let error {
                    cont.resume(throwing: SpotifyError.authFailed(error.localizedDescription))
                    return
                }
                guard let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    cont.resume(throwing: SpotifyError.authFailed("No auth code in callback"))
                    return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        try await exchangeCodeForTokens(code: code)
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw SpotifyError.authFailed("Missing code verifier")
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  SettingsStore.redirectURI,
            "client_id":     settings.clientId,
            "code_verifier": verifier
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyError.authFailed("Token exchange failed: HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        let tokenResp = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        settings.tokens = SpotifyTokens(
            accessToken:  tokenResp.accessToken,
            refreshToken: tokenResp.refreshToken ?? "",
            expiresAt:    Date().addingTimeInterval(TimeInterval(tokenResp.expiresIn))
        )
        codeVerifier = nil
    }

    // MARK: - Token refresh

    func refreshIfNeeded() async throws -> String {
        guard var tokens = settings.tokens else {
            throw SpotifyError.notAuthenticated
        }
        if !tokens.isExpired { return tokens.accessToken }

        // Refresh
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type":    "refresh_token",
            "refresh_token": tokens.refreshToken,
            "client_id":     settings.clientId
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            settings.logout()
            throw SpotifyError.notAuthenticated
        }

        let tokenResp = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        tokens.accessToken  = tokenResp.accessToken
        tokens.refreshToken = tokenResp.refreshToken ?? tokens.refreshToken
        tokens.expiresAt    = Date().addingTimeInterval(TimeInterval(tokenResp.expiresIn))
        settings.tokens = tokens
        return tokens.accessToken
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(128)
            .description
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data    = Data(verifier.utf8)
        let hash    = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
