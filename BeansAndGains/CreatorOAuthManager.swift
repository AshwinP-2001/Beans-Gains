import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class CreatorOAuthManager: NSObject,
    ASWebAuthenticationPresentationContextProviding {

    static let shared = CreatorOAuthManager()

    private var authSession: ASWebAuthenticationSession?

    // MARK: - Authorization

    func authorize() async throws {
        let verifier = Self.randomVerifier()
        let challenge = Self.base64URL(
            SHA256.hash(data: Data(verifier.utf8))
        )

        let authorizationURL = CreatorConfiguration.accountsBaseURL
            .appendingPathComponent("oauth/v2/auth")

        guard var components = URLComponents(
            url: authorizationURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw CreatorTestError.message(
                "Could not build the Zoho authorization URL."
            )
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: CreatorConfiguration.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: CreatorConfiguration.redirectURI),
            URLQueryItem(name: "scope", value: CreatorConfiguration.requestedScopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        guard let authURL = components.url else {
            throw CreatorTestError.message(
                "Could not construct the authorization URL."
            )
        }

        let callback = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.ashwinppersonalteam.UntitledProject"
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(
                        throwing: CreatorTestError.message("Zoho did not return a callback URL.")
                    )
                }
            }

            session.presentationContextProvider = self
            self.authSession = session

            if !session.start() {
                self.authSession = nil
                continuation.resume(
                    throwing: CreatorTestError.message("Could not start authentication session.")
                )
            }
        }

        authSession = nil

        guard let callbackComponents = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw CreatorTestError.message("No authorization code returned by Zoho.")
        }

        try await exchange(code: code, verifier: verifier)
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async throws {
        guard let refreshToken = CreatorTokenStore.refreshToken(),
              !refreshToken.isEmpty else {
            throw CreatorTestError.message("No refresh token found. Please re-authenticate.")
        }

        let tokenURL = CreatorConfiguration.accountsBaseURL
            .appendingPathComponent("oauth/v2/token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: CreatorConfiguration.clientID),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        guard let bodyData = form.percentEncodedQuery?.data(using: .utf8) else {
            throw CreatorTestError.message("Could not encode refresh request.")
        }

        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw CreatorTestError.message("Token refresh failed: \(body)")
        }

        let tokens = try JSONDecoder().decode(CreatorTokenResponse.self, from: data)

        try CreatorTokenStore.save(
            accessToken: tokens.access_token,
            refreshToken: tokens.refresh_token ?? refreshToken
        )
    }

    // MARK: - Presentation

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    // MARK: - Token Exchange

    private func exchange(code: String, verifier: String) async throws {
        let tokenURL = CreatorConfiguration.accountsBaseURL
            .appendingPathComponent("oauth/v2/token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: CreatorConfiguration.clientID),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: CreatorConfiguration.redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]

        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CreatorTestError.message("Token exchange failed: \(body)")
        }

        let tokens = try JSONDecoder().decode(CreatorTokenResponse.self, from: data)
        try CreatorTokenStore.save(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
    }

    // MARK: - PKCE Helpers

    private static func randomVerifier() -> String {
        let characters = Array(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        )

        var bytes = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            fatalError("Could not generate a secure PKCE verifier.")
        }

        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    private static func base64URL<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Token Response & Errors

private struct CreatorTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
}

enum CreatorTestError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        if case .message(let message) = self {
            return message
        }
        return nil
    }
}
