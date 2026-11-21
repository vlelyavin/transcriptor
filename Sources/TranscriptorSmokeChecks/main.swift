import Foundation
import TranscriptorKit

@main
struct TranscriptorSmokeChecks {
    static func main() {
        var failures: [String] = []

        // Isolated storage + defaults: the retention pass AppState runs at launch
        // must never touch the developer's real recordings or preferences.
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptorSmokeChecks-\(UUID().uuidString)", isDirectory: true)
        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )
        let suiteName = "TranscriptorSmokeChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard

        let appState = AppState(
            preferencesStore: AppPreferencesStore(defaults: defaults),
            storageLayout: layout,
            historyRepository: try? HistoryRepository(layout: layout, inMemory: true)
        )

        // `exit()` skips `defer`, so clean up explicitly at both exits.
        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: rootDirectory)
        }
        expect(appState.selectedScreen == .overview, "App state starts on the Overview screen.", failures: &failures)
        expect(appState.recordingState.mode == .holdToTalk, "Recording mode defaults to Hold to Talk.", failures: &failures)
        expect(appState.audioRetentionSettings.keepsRecordings, "Recording defaults to keeping recordings.", failures: &failures)
        expect(appState.audioRetentionSettings.window == .forever, "Recording retention defaults to forever, so an upgrade never deletes audio.", failures: &failures)
        expect(SpeechAudioFormat.sampleRate == 16_000, "Stored and uploaded speech audio is 16 kHz.", failures: &failures)
        expect(SpeechAudioFormat.channelCount == 1, "Stored and uploaded speech audio is mono.", failures: &failures)
        expect(!DockIconPolicy.shouldShowDockIcon(for: .init()), "A menu-bar app shows no Dock icon by default.", failures: &failures)
        expect(DockIconPolicy.shouldShowDockIcon(for: .init(pinnedDockIcon: true)), "A pinned Dock icon shows in the Dock.", failures: &failures)
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
        expect(
            providers.visibleProviders.map(\.id) == ["custom", "groq", "elevenlabs"],
            "The visible remote providers are the OpenAI-compatible endpoint, Groq, and ElevenLabs.",
            failures: &failures
        )
        expect(
            providers.provider(id: "elevenlabs")?.apiDialect == .elevenLabs
                && providers.provider(id: "elevenlabs")?.modelLabel == "scribe_v3",
            "ElevenLabs speaks its own dialect and defaults to Scribe v3.",
            failures: &failures
        )

        if failures.isEmpty {
            print("Transcriptor smoke checks passed.")
            cleanUp()
            exit(EXIT_SUCCESS)
        }

        for failure in failures {
            fputs("FAIL: \(failure)\n", stderr)
        }

        cleanUp()
        exit(EXIT_FAILURE)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String, failures: inout [String]) {
        if !condition() {
            failures.append(message)
        }
    }
}
