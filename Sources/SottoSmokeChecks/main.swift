import Foundation
import SottoKit

@main
struct SottoSmokeChecks {
    static func main() {
        var failures: [String] = []

        let appState = AppState()
        expect(appState.selectedScreen == .overview, "App state starts on the Overview screen.", failures: &failures)
        expect(appState.recordingState.mode == .holdToTalk, "Recording mode defaults to Hold to Talk.", failures: &failures)
        expect(appState.recordingState.savesAudioLocally, "Recording defaults to local save enabled.", failures: &failures)
        expect(appState.overlayState.isNonActivating, "Overlay defaults to non-activating.", failures: &failures)
        expect(!appState.historyStore.entries.isEmpty, "History store starts with mock content.", failures: &failures)
        expect(appState.storageSettings.autoDeleteOldestHistory, "Storage defaults to auto-deleting oldest history.", failures: &failures)

        let catalog = ModelCatalog.defaultCatalog
        expect(catalog.sections.map(\.id) == ["whisper", "parakeet"], "Model catalog exposes Whisper and Parakeet sections.", failures: &failures)
        expect(catalog.sections.flatMap(\.models).contains { $0.id == "whisper-large-v3-turbo" }, "Model catalog includes Large V3 Turbo.", failures: &failures)
        expect(catalog.sections.flatMap(\.models).contains { $0.id == "parakeet-v3-multilingual" }, "Model catalog includes a Parakeet multilingual placeholder.", failures: &failures)
        expect(appState.selectedModel?.id == "whisper-large-v3-turbo", "Preferred model defaults to Large V3 Turbo.", failures: &failures)

        let providers = ProviderCatalog.defaultCatalog
        expect(providers.providers.map(\.id) == ["openai", "groq"], "Provider catalog includes OpenAI and Groq placeholders.", failures: &failures)

        if failures.isEmpty {
            print("Sotto smoke checks passed.")
            exit(EXIT_SUCCESS)
        }

        for failure in failures {
            fputs("FAIL: \(failure)\n", stderr)
        }

        exit(EXIT_FAILURE)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String, failures: inout [String]) {
        if !condition() {
            failures.append(message)
        }
    }
}
