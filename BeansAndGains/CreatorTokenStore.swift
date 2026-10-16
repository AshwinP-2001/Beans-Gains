import Foundation
import Security

enum CreatorTokenStore {
    private static let service =
        "com.ashwinppersonalteam.UntitledProject.creator-fetch-test"

    static func save(
        accessToken: String,
        refreshToken: String?
    ) throws {
        try saveValue(accessToken, account: "access")

        if let refreshToken, !refreshToken.isEmpty {
            try saveValue(refreshToken, account: "refresh")
        }
    }

    static func accessToken() -> String? {
        readValue(account: "access")
    }

    static func refreshToken() -> String? {
        readValue(account: "refresh")
    }

    // Clears saved tokens from the Keychain so you can re-authenticate
    static func clear() {
        let accessQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "access"
        ]
        let refreshQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "refresh"
        ]
        SecItemDelete(accessQuery as CFDictionary)
        SecItemDelete(refreshQuery as CFDictionary)
    }

    static var tokenStatus: String {
        let hasAccessToken = accessToken()?.isEmpty == false
        let hasRefreshToken = refreshToken()?.isEmpty == false

        return """
        SAVED TOKEN STATUS

        Access token saved: \(hasAccessToken ? "Yes" : "No")
        Refresh token saved: \(hasRefreshToken ? "Yes" : "No")
        """
    }

    private static func saveValue(
        _ value: String,
        account: String
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CreatorTestError.message(
                "Keychain error: \(status)"
            )
        }
    }

    private static func readValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        guard SecItemCopyMatching(
            query as CFDictionary,
            &result
        ) == errSecSuccess,
        let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
