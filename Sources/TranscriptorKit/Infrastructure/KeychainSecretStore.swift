import Foundation
import Security

public enum SecretStoreError: Error, LocalizedError, Equatable, Sendable {
    case invalidSecret
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidSecret:
            "The provided secret could not be encoded for secure storage."
        case let .unexpectedStatus(status):
            SecCopyErrorMessageString(status, nil) as String? ?? "The Keychain returned OSStatus \(status)."
        }
    }
}

public protocol SecretStore: Sendable {
    func secret(for account: String) throws -> String?
    func saveSecret(_ secret: String, for account: String) throws
    func deleteSecret(for account: String) throws
    func containsSecret(for account: String) throws -> Bool
}

/// Stores provider API keys as generic passwords in the **data-protection**
/// keychain (keychain-access-groups entitlement, embedded by
/// `scripts/build_release.sh`).
///
/// The DP keychain is keyed by the app's access group, not by the code
/// signature's cdhash, so reads stay prompt-free across rebuilds even for
/// ad-hoc–signed CI builds (the legacy file-based keychain re-prompts on
/// every rebuild because the item ACL pins the build's cdhash).
///
/// Migration: when a secret exists in the legacy login keychain but not in
/// the DP keychain, the first read copies it over (may ask once) and the
/// legacy item is left in place as a backup. If the DP keychain is
/// unavailable (errSecMissingEntitlement), every call transparently falls
/// back to the legacy login-keychain behavior.
/// Mutable holder so the lazy DP-disable flag survives inside a struct
/// passed as an existential (the store lives long in AppState).
private final class DPStateBox: @unchecked Sendable {
    var useDataProtectionIsEnabled = true
}

public struct KeychainSecretStore: SecretStore, @unchecked Sendable {
    public let service: String
    private let legacyKeychain: SecKeychain?
    private let dpState = DPStateBox()
    private var useDataProtectionIsEnabled: Bool {
        get { dpState.useDataProtectionIsEnabled }
        nonmutating set { dpState.useDataProtectionIsEnabled = newValue }
    }

    public init(service: String = "com.transcriptor.credentials") {
        self.service = service
        self.legacyKeychain = Self.userDefaultKeychain()
    }

    private var accessGroup: String { service }

    public func secret(for account: String) throws -> String? {
        if useDataProtectionIsEnabled {
            var query = itemAttributes(account: account)
            query[kSecUseDataProtectionKeychain as String] = true
            query[kSecAttrAccessGroup as String] = accessGroup
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            switch status {
            case errSecSuccess:
                guard
                    let data = result as? Data,
                    let secret = String(data: data, encoding: .utf8)
                else {
                    throw SecretStoreError.invalidSecret
                }
                return secret
            case errSecItemNotFound:
                if let legacy = try legacySecret(account: account) {
                    try? saveSecretDPOnly(secret: legacy, account: account)
                    return legacy
                }
                return nil
            case errSecMissingEntitlement, errSecNoSuchKeychain:
                useDataProtectionIsEnabled = false
                return try legacySecret(account: account)
            default:
                throw SecretStoreError.unexpectedStatus(status)
            }
        }
        return try legacySecret(account: account)
    }

    public func saveSecret(_ secret: String, for account: String) throws {
        guard let data = secret.data(using: .utf8), !secret.isEmpty else {
            throw SecretStoreError.invalidSecret
        }
        if useDataProtectionIsEnabled {
            var updateQuery = itemAttributes(account: account)
            updateQuery[kSecUseDataProtectionKeychain as String] = true
            updateQuery[kSecAttrAccessGroup as String] = accessGroup
            let updateStatus = SecItemUpdate(
                updateQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            switch updateStatus {
            case errSecSuccess:
                return
            case errSecItemNotFound:
                var addQuery = itemAttributes(account: account)
                addQuery[kSecUseDataProtectionKeychain as String] = true
                addQuery[kSecAttrAccessGroup as String] = accessGroup
                addQuery[kSecValueData as String] = data
                addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
                let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
                if addStatus == errSecSuccess { return }
                if addStatus == errSecMissingEntitlement || addStatus == errSecNoSuchKeychain {
                    useDataProtectionIsEnabled = false
                    try legacySave(secret: secret, account: account)
                    return
                }
                throw SecretStoreError.unexpectedStatus(addStatus)
            case errSecMissingEntitlement, errSecNoSuchKeychain:
                useDataProtectionIsEnabled = false
                try legacySave(secret: secret, account: account)
                return
            default:
                throw SecretStoreError.unexpectedStatus(updateStatus)
            }
        }
        try legacySave(secret: secret, account: account)
    }

    public func deleteSecret(for account: String) throws {
        if useDataProtectionIsEnabled {
            var query = itemAttributes(account: account)
            query[kSecUseDataProtectionKeychain as String] = true
            query[kSecAttrAccessGroup as String] = accessGroup
            let status = SecItemDelete(query as CFDictionary)
            switch status {
            case errSecSuccess, errSecItemNotFound:
                try? legacyDelete(account: account)
                return
            case errSecMissingEntitlement, errSecNoSuchKeychain:
                useDataProtectionIsEnabled = false
            default:
                throw SecretStoreError.unexpectedStatus(status)
            }
        }
        try legacyDelete(account: account)
    }

    /// Attribute-only lookup: never returns secret data, so it doesn't need
    /// the item's access-list approval and never prompts.
    public func containsSecret(for account: String) throws -> Bool {
        if useDataProtectionIsEnabled {
            var query = itemAttributes(account: account)
            query[kSecUseDataProtectionKeychain as String] = true
            query[kSecAttrAccessGroup as String] = accessGroup
            query[kSecReturnAttributes as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            switch status {
            case errSecSuccess:
                return true
            case errSecItemNotFound:
                return try legacyContains(account: account)
            case errSecMissingEntitlement, errSecNoSuchKeychain:
                useDataProtectionIsEnabled = false
            default:
                throw SecretStoreError.unexpectedStatus(status)
            }
        }
        return try legacyContains(account: account)
    }

    // MARK: - Data-protection helpers

    private func saveSecretDPOnly(secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8), !secret.isEmpty else {
            throw SecretStoreError.invalidSecret
        }
        var addQuery = itemAttributes(account: account)
        addQuery[kSecUseDataProtectionKeychain as String] = true
        addQuery[kSecAttrAccessGroup as String] = accessGroup
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecretStoreError.unexpectedStatus(addStatus)
        }
    }

    // MARK: - Legacy (login keychain) helpers

    private func legacySecret(account: String) throws -> String? {
        var query = legacyMatchQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let secret = String(data: data, encoding: .utf8)
            else {
                throw SecretStoreError.invalidSecret
            }
            return secret
        case errSecItemNotFound:
            return nil
        default:
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    private func legacyContains(account: String) throws -> Bool {
        var query = legacyMatchQuery(account: account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    private func legacySave(secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8), !secret.isEmpty else {
            throw SecretStoreError.invalidSecret
        }
        let updateStatus = SecItemUpdate(
            legacyMatchQuery(account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = itemAttributes(account: account)
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if let legacyKeychain {
                addQuery[kSecUseKeychain as String] = legacyKeychain
            }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecretStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw SecretStoreError.unexpectedStatus(updateStatus)
        }
    }

    private func legacyDelete(account: String) throws {
        let status = SecItemDelete(legacyMatchQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    private func itemAttributes(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func legacyMatchQuery(account: String) -> [String: Any] {
        var query = itemAttributes(account: account)
        if let legacyKeychain {
            query[kSecMatchSearchList as String] = [legacyKeychain]
        }
        return query
    }

    private static func userDefaultKeychain() -> SecKeychain? {
        var keychain: SecKeychain?
        // Deprecated API, but it is the only way to name the login keychain
        // for the file-based keychain.
        guard SecKeychainCopyDomainDefault(.user, &keychain) == errSecSuccess else {
            return nil
        }
        return keychain
    }
}
