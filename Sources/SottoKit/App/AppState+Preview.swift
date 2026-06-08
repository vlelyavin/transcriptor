import Foundation

extension AppState {
    public static var preview: AppState {
        let defaults = UserDefaults(suiteName: "SottoPreviewDefaults") ?? .standard
        defaults.removePersistentDomain(forName: "SottoPreviewDefaults")
        return AppState(preferencesStore: AppPreferencesStore(defaults: defaults))
    }
}
