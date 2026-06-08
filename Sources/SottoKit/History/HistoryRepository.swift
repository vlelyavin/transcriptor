import Foundation
import SwiftData

@MainActor
public final class HistoryRepository {
    private let container: ModelContainer
    private let layout: AppStorageLayout

    public init(
        layout: AppStorageLayout = AppStorageLayout(),
        inMemory: Bool = false
    ) throws {
        self.layout = layout

        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = try ModelConfiguration(url: layout.historyStoreURL())
        }

        container = try ModelContainer(
            for: PersistedHistoryRecord.self,
            configurations: configuration
        )
    }

    public func fetchAll() throws -> [HistoryEntry] {
        let descriptor = FetchDescriptor<PersistedHistoryRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try container.mainContext.fetch(descriptor).map(\.entry)
    }

    public func fetch(id: UUID) throws -> HistoryEntry? {
        try record(id: id)?.entry
    }

    public func upsert(_ entry: HistoryEntry) throws {
        if let existingRecord = try record(id: entry.id) {
            existingRecord.update(from: entry)
        } else {
            container.mainContext.insert(PersistedHistoryRecord(entry: entry))
        }

        try container.mainContext.save()
    }

    @discardableResult
    public func delete(id: UUID) throws -> HistoryEntry? {
        guard let existingRecord = try record(id: id) else {
            return nil
        }

        let entry = existingRecord.entry
        container.mainContext.delete(existingRecord)
        try container.mainContext.save()
        return entry
    }

    @discardableResult
    public func deleteAll() throws -> [HistoryEntry] {
        let records = try container.mainContext.fetch(FetchDescriptor<PersistedHistoryRecord>())
        let entries = records.map(\.entry)
        for record in records {
            container.mainContext.delete(record)
        }
        try container.mainContext.save()
        return entries
    }

    @discardableResult
    public func deleteOldest(first count: Int) throws -> [HistoryEntry] {
        guard count > 0 else {
            return []
        }

        let descriptor = FetchDescriptor<PersistedHistoryRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let records = try Array(container.mainContext.fetch(descriptor).prefix(count))
        let entries = records.map(\.entry)
        for record in records {
            container.mainContext.delete(record)
        }
        try container.mainContext.save()
        return entries
    }

    private func record(id: UUID) throws -> PersistedHistoryRecord? {
        let predicate = #Predicate<PersistedHistoryRecord> { record in
            record.id == id
        }
        var descriptor = FetchDescriptor<PersistedHistoryRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try container.mainContext.fetch(descriptor).first
    }
}
