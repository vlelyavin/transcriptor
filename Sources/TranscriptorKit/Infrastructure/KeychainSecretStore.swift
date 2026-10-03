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

/// Stores provider API keys as generic passwords in the user's **login**
/// keychain.
///
/// Every query is pinned to that one keychain. Without the pin, lookups walk
/// the whole user search list, so any extra keychain sitting in front of
/// `login` (e.g. a locked code-signing keychain) makes macOS ask for *that*
/// keychain's password, and stale copies of the same item left in other
/// keychains each trigger their own access prompt.
///
/// Prompt-free reads across rebuilds additionally need a stable code signature
/// (see `scripts/setup_local_signing_cert.sh`): the item's access list trusts
/// the app's designated requirement, which for an ad-hoc build is the cdhash
/// and changes on every build.
public struct KeychainSecretStore: SecretStore, @unchecked Sendable {
    public let service: String
    /// The keychain all items are read from and written to. `nil` falls back
    /// to the system defaults (only if the login keychain can't be resolved).
    /// `SecKeychain` is an immutable CF handle, safe to share across threads.
    private let keychain: SecKeychain?

    public init(service: String = "com.transcriptor.credentials") {
        self.service = service
        self.keychain = Self.userDefaultKeychain()
    }

    public func secret(for account: String) throws -> String? {
        var query = matchQuery(account: account)
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

    public func saveSecret(_ secret: String, for account: String) throws {
        guard let data = secret.data(using: .utf8), !secret.isEmpty else {
            throw SecretStoreError.invalidSecret
        }

        // Update in place when the item exists: an update keeps the item's
        // access list, so an "Always Allow" granted earlier stays valid.
        let updateStatus = SecItemUpdate(
            matchQuery(account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = itemAttributes(account: account)
            addQuery[kSecValueData as String] = data
            // Accessibility is an attribute of the stored item. It belongs on
            // the add only — in a lookup it would act as an extra filter.
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if let keychain {
                addQuery[kSecUseKeychain as String] = keychain
            }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecretStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw SecretStoreError.unexpectedStatus(updateStatus)
        }
    }

    public func deleteSecret(for account: String) throws {
        let status = SecItemDelete(matchQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    /// Attribute-only lookup: never returns secret data, so it doesn't need the
    /// item's access-list approval and never prompts.
    public func containsSecret(for account: String) throws -> Bool {
        var query = matchQuery(account: account)
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

    private func itemAttributes(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func matchQuery(account: String) -> [String: Any] {
        var query = itemAttributes(account: account)
        if let keychain {
            query[kSecMatchSearchList as String] = [keychain]
        }
        return query
    }

    private static func userDefaultKeychain() -> SecKeychain? {
        var keychain: SecKeychain?
        // Deprecated API, but it is the only way to name the login keychain
        // for the file-based keychain that self-signed apps use (the
        // data-protection keychain requires a provisioning profile and fails
        // with errSecMissingEntitlement for this app).
        guard SecKeychainCopyDomainDefault(.user, &keychain) == errSecSuccess else {
            return nil
        }
        return keychain
    }
}
