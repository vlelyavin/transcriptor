import Foundation

extension AppState {
    public static var preview: AppState {
        let defaults = UserDefaults(suiteName: "SottoPreviewDefaults") ?? .standard
        defaults.removePersistentDomain(forName: "SottoPreviewDefaults")
        let storageLayout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { FileManager.default.temporaryDirectory.appendingPathComponent("SottoPreview", isDirectory: true) }
        )
        let repository = try? HistoryRepository(layout: storageLayout, inMemory: true)
        HistoryEntry.previewEntries.forEach { entry in
            try? repository?.upsert(entry)
        }
        return AppState(
            historyStore: .preview,
            preferencesStore: AppPreferencesStore(defaults: defaults),
            storageLayout: storageLayout,
            historyRepository: repository
        )
    }
}
