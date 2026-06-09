import Foundation
import TranscriptorKit

@main
struct TranscriptorSmokeChecks {
    static func main() {
        var failures: [String] = []

        let appState = AppState()
        expect(appState.selectedScreen == .overview, "App state starts on the Overview screen.", failures: &failures)
        expect(appState.recordingState.mode == .holdToTalk, "Recording mode defaults to Hold to Talk.", failures: &failures)
        expect(appState.recordingState.savesAudioLocally, "Recording defaults to local save enabled.", failures: &failures)
        expect(appState.overlayState.isNonActivating, "Overlay defaults to non-activating.", failures: &failures)
        expect(appState.storageSettings.autoDeleteOldestHistory, "Storage defaults to auto-deleting oldest history.", failures: &failures)
        expect(appState.transcriptionPreferences.preferredLocalProviderID == "whisperkit-local", "Preferred local provider defaults to WhisperKit.", failures: &failures)
        expect(appState.selectedModel?.id == "whisper-large-v3-turbo", "Preferred model defaults to Large V3 Turbo.", failures: &failures)

        let catalog = ModelCatalog.defaultCatalog
        expect(catalog.sections.map(\.id) == ["whisper", "parakeet"], "Model catalog exposes Whisper and Parakeet sections.", failures: &failures)
        expect(catalog.whisperModels.contains { $0.id == "whisper-tiny" && $0.supportsLocalTranscription }, "Model catalog includes Tiny as a real local model.", failures: &failures)
        expect(catalog.whisperModels.contains { $0.remoteVariantName == "openai_whisper-large-v3-v20240930_turbo_632MB" }, "Model catalog pins a verified Large V3 Turbo runtime variant.", failures: &failures)
        expect(catalog.sections.flatMap(\.models).contains { $0.id == "parakeet-v3-multilingual" }, "Model catalog keeps the Parakeet roadmap section visible.", failures: &failures)

        let providers = ProviderCatalog.defaultCatalog
        expect(providers.providers.map(\.id) == ["openai", "groq"], "Provider catalog includes the implemented OpenAI and Groq providers.", failures: &failures)

        if failures.isEmpty {
            print("Transcriptor smoke checks passed.")
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
