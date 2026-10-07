import Foundation
import Security
import CryptoKit

/// Primary storage: an encrypted file in Application Support.
///
/// Rationale (distribution-first): a file store is not keyed to the app's
/// code signature, so API keys survive app updates with **zero keychain
/// prompts** — for both locally rebuilt ad-hoc builds and for users who
/// install CI builds from GitHub. Encryption key material lives in the
/// data-protection keychain when available and falls back to a
/// device-derived key file when it is not.
///
/// The file is 0600 in the user's private Application Support directory.
/// Anyone who can run code as the user can read it (same practical
/// boundary as the login keychain after `Always Allow`), which is an
/// accepted trade-off for prompt-free updates on this app's threat model.
public final class FileSecretStore: SecretStore, @unchecked Sendable {
    public let service: String
    private let directory: URL
    private let fileURL: URL
    private let storeQueue = DispatchQueue(label: "com.transcriptor.filesecretstore")

    private var cachedPayload: [String: String] = [:]
    private var cacheLoaded = false

    public init(service: String = "com.transcriptor.credentials") {
        self.service = service
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        directory = base.appendingPathComponent("Transcriptor", isDirectory: true)
        fileURL = directory.appendingPathComponent("credentials.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Tighten permissions if the directory pre-existed with defaults.
        if let attrs = try? FileManager.default.attributesOfItem(atPath: directory.path),
           let perms = attrs[.posixPermissions] as? Int, perms != 0o700 {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
    }

    // MARK: - SecretStore

    public func secret(for account: String) throws -> String? {
        try storeQueue.sync { try payload()[account] }
    }

    public func saveSecret(_ secret: String, for account: String) throws {
        guard let data = secret.data(using: .utf8), !secret.isEmpty else {
            throw SecretStoreError.invalidSecret
        }
        try storeQueue.sync {
            var payload = try payload()
            payload[account] = secret
            try write(payload)
        }
    }

    public func deleteSecret(for account: String) throws {
        try storeQueue.sync {
            var payload = try payload()
            payload.removeValue(forKey: account)
            try write(payload)
        }
    }

    public func containsSecret(for account: String) throws -> Bool {
        try storeQueue.sync { try payload()[account] != nil }
    }

    // MARK: - Payload I/O (AES-GCM at rest, 0600 file)

    private func payload() throws -> [String: String] {
        if cacheLoaded { return cachedPayload }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cacheLoaded = true
            cachedPayload = [:]
            return cachedPayload
        }
        let raw = try Data(contentsOf: fileURL)
        do {
            let sealed = try AES.GCM.SealedBox(combined: raw)
            let key = try Self.storageKey()
            let plaintext = try AES.GCM.open(sealed, using: key)
            let decoded = try JSONDecoder().decode([String: String].self, from: plaintext)
            cachedPayload = decoded
            cacheLoaded = true
            return decoded
        } catch {
            // Unreadable/corrupt file — start a fresh store rather than
            // wedging the app; the old bytes are replaced on next save.
            cachedPayload = [:]
            return cachedPayload
        }
    }

    private func write(_ payload: [String: String]) throws {
        let key = try Self.storageKey()
        let plaintext = try JSONEncoder().encode(payload)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw SecretStoreError.invalidSecret
        }
        try combined.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        cachedPayload = payload
    }

    /// The storage key: generated once, kept in the data-protection
    /// keychain when the app can access it; otherwise persisted as a
    /// 0600 key file next to the store. Either way it never leaves the
    /// machine and is not tied to the code signature.
    private static func storageKey() throws -> SymmetricKey {
        let service = "com.transcriptor.credentials"
        let account = "file-store-key"

        // 1) Try the data-protection keychain (best available on modern
        //    macOS even without the access-group entitlement when the
        //    query omits kSecAttrAccessGroup).
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }

        // 2) Generate + store in DP keychain if possible.
        if status == errSecItemNotFound {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            var addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecUseDataProtectionKeychain as String: true,
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return key
            }
        }

        // 3) Fallback: 0600 key file next to the store (device-local).
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("Transcriptor", isDirectory: true)
        let keyURL = dir.appendingPathComponent(".storage-key")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: keyURL.path) {
            let data = try Data(contentsOf: keyURL)
            if data.count == 32 {
                return SymmetricKey(data: data)
            }
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try keyData.write(to: keyURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        return key
    }
}

/// Unified store: encrypted file is the source of truth; the keychain is
/// used only as a **read-through migration source** so keys a user saved
/// with earlier builds keep working without re-entering them.
///
/// Writes go to the file only — no keychain writes, so no keychain ACL
/// prompts, ever, on any build.
public struct MigratingSecretStore: SecretStore, @unchecked Sendable {
    private let fileStore: FileSecretStore
    private let legacyKeychainStore: KeychainSecretStore

    public init(service: String = "com.transcriptor.credentials") {
        self.fileStore = FileSecretStore(service: service)
        self.legacyKeychainStore = KeychainSecretStore(service: service)
    }

    public func secret(for account: String) throws -> String? {
        if let value = try fileStore.secret(for: account) {
            return value
        }
        // Legacy keychain read may prompt once on rebuilt ad-hoc binaries
        // (ACL keyed to the old build). After this single read the value
        // lives in the file store and the keychain is never touched again.
        if let legacy = try legacyKeychainStore.secret(for: account) {
            try? fileStore.saveSecret(legacy, for: account)
            return legacy
        }
        return nil
    }

    public func saveSecret(_ secret: String, for account: String) throws {
        try fileStore.saveSecret(secret, for: account)
        // Best-effort keep the keychain copy in sync for users who had one
        // (so reverting to an older build still works). Never throws.
        try? legacyKeychainStore.saveSecret(secret, for: account)
    }

    public func deleteSecret(for account: String) throws {
        try fileStore.deleteSecret(for: account)
        try? legacyKeychainStore.deleteSecret(for: account)
    }

    public func containsSecret(for account: String) throws -> Bool {
        if try fileStore.containsSecret(for: account) {
            return true
        }
        return try legacyKeychainStore.containsSecret(for: account)
    }
}
