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
        expect(appState.historyStore.entries.isEmpty, "History store starts empty.", failures: &failures)

        let catalog = ModelCatalog.defaultCatalog
        expect(catalog.sections.map(\.id) == ["whisper", "parakeet"], "Model catalog exposes Whisper and Parakeet sections.", failures: &failures)
        expect(catalog.sections.flatMap(\.models).contains { $0.id == "whisper-tiny" }, "Model catalog includes Whisper Tiny.", failures: &failures)
        expect(catalog.sections.flatMap(\.models).contains { $0.id == "parakeet-tdt" }, "Model catalog includes a Parakeet placeholder.", failures: &failures)

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
