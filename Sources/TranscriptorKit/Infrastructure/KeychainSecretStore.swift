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

public struct KeychainSecretStore: SecretStore, Sendable {
    public let service: String

    public init(service: String = "com.transcriptor.credentials") {
        self.service = service
    }

    public func secret(for account: String) throws -> String? {
        var query = baseQuery(account: account)
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

        let query = baseQuery(account: account)
        let attributesToUpdate = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecretStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw SecretStoreError.unexpectedStatus(updateStatus)
        }
    }

    public func deleteSecret(for account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    public func containsSecret(for account: String) throws -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
    }
}
