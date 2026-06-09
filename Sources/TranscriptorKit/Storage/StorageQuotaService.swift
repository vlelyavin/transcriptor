import Foundation

public enum StorageQuotaError: Error, LocalizedError {
    case saveBlocked(projectedUsageMegabytes: Int, limitMegabytes: Int)

    public var errorDescription: String? {
        switch self {
        case let .saveBlocked(projectedUsageMegabytes, limitMegabytes):
            "Import blocked because Transcriptor would exceed the \(limitMegabytes) MB history cap (projected use: \(projectedUsageMegabytes) MB)."
        }
    }
}

public struct StorageEnforcementResult: Equatable, Sendable {
    public var prunedEntryIDs: [UUID]
    public var usage: ManagedStorageUsage
    public var warningMessage: String?

    public init(
        prunedEntryIDs: [UUID] = [],
        usage: ManagedStorageUsage,
        warningMessage: String? = nil
    ) {
        self.prunedEntryIDs = prunedEntryIDs
        self.usage = usage
        self.warningMessage = warningMessage
    }
}

public struct StorageQuotaService {
    private let layout: AppStorageLayout

    public init(layout: AppStorageLayout = AppStorageLayout()) {
        self.layout = layout
    }

    public func currentUsage() throws -> ManagedStorageUsage {
        try layout.managedStorageUsage()
    }

    public func validateImportCanProceed(
        additionalBytes: Int64,
        settings: StorageSettings
    ) throws {
        let usage = try currentUsage()
        guard !settings.autoDeleteOldestHistory else {
            return
        }

        let projectedBytes = usage.totalManagedBytes + additionalBytes
        let limitBytes = Int64(settings.capMegabytes) * 1_048_576
        guard projectedBytes > limitBytes else {
            return
        }

        let projectedMegabytes = Int((Double(projectedBytes) / 1_048_576).rounded(.up))
        throw StorageQuotaError.saveBlocked(
            projectedUsageMegabytes: projectedMegabytes,
            limitMegabytes: settings.capMegabytes
        )
    }

    public func pruneEntriesIfNeeded(
        entries: [HistoryEntry],
        settings: StorageSettings
    ) throws -> StorageEnforcementResult {
        let usage = try currentUsage()
        let limitBytes = Int64(settings.capMegabytes) * 1_048_576

        guard usage.totalManagedBytes > limitBytes else {
            return StorageEnforcementResult(usage: usage)
        }

        guard settings.autoDeleteOldestHistory else {
            return StorageEnforcementResult(
                usage: usage,
                warningMessage: "History storage is over the \(settings.capMegabytes) MB limit. Auto-delete is off, so new imports may be blocked until you clear space."
            )
        }

        var prunedIDs: [UUID] = []
        var projectedUsage = usage.totalManagedBytes

        for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) where projectedUsage > limitBytes {
            projectedUsage -= max(entry.storageBytes, 0)
            prunedIDs.append(entry.id)
        }

        return StorageEnforcementResult(
            prunedEntryIDs: prunedIDs,
            usage: usage
        )
    }
}
