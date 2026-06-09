import XCTest
@testable import TranscriptorKit

final class TranscriptionTargetResolverTests: XCTestCase {
    func testPreferredLocalProviderResolvesReadyWhisperModel() throws {
        let resolver = TranscriptionTargetResolver(
            modelCatalog: .defaultCatalog,
            providerCatalog: .defaultCatalog
        )
        let plan = try resolver.resolve(
            preferences: TranscriptionPreferences(
                selectedModelID: "whisper-tiny",
                autoTranscribeAfterCapture: false,
                preferredLocalProviderID: "whisperkit-local",
                preferredProviderID: "whisperkit-local"
            ),
            providerSettings: ProviderSettings(),
            readyLocalModelIDs: ["whisper-tiny"],
            providerStatesByID: [:]
        )

        XCTAssertEqual(plan.providerID, "whisperkit-local")
        XCTAssertEqual(plan.modelID, "whisper-tiny")
    }

    func testPreferredLocalProviderResolvesReadyParakeetModel() throws {
        let resolver = TranscriptionTargetResolver(
            modelCatalog: .defaultCatalog,
            providerCatalog: .defaultCatalog
        )
        let plan = try resolver.resolve(
            preferences: TranscriptionPreferences(
                selectedModelID: "parakeet-v3-multilingual",
                autoTranscribeAfterCapture: false,
                preferredLocalProviderID: "parakeet-local",
                preferredProviderID: "parakeet-local"
            ),
            providerSettings: ProviderSettings(),
            readyLocalModelIDs: ["parakeet-v3-multilingual"],
            providerStatesByID: [:]
        )

        XCTAssertEqual(plan.providerID, "parakeet-local")
        XCTAssertEqual(plan.modelID, "parakeet-v3-multilingual")
    }

    func testPreferredCloudProviderResolvesConfiguredModel() throws {
        let resolver = TranscriptionTargetResolver(
            modelCatalog: .defaultCatalog,
            providerCatalog: .defaultCatalog
        )
        let plan = try resolver.resolve(
            preferences: TranscriptionPreferences(
                selectedModelID: "whisper-large-v3-turbo",
                autoTranscribeAfterCapture: false,
                preferredLocalProviderID: "whisperkit-local",
                preferredProviderID: "openai"
            ),
            providerSettings: ProviderSettings(
                openAIEnabled: true,
                groqEnabled: false,
                openAIModelID: "gpt-4o-mini-transcribe",
                groqModelID: "whisper-large-v3-turbo",
                openAIPrivacyAcknowledged: true,
                groqPrivacyAcknowledged: false
            ),
            readyLocalModelIDs: [],
            providerStatesByID: [
                "openai": .ready(message: "Ready"),
            ]
        )

        XCTAssertEqual(plan.providerID, "openai")
        XCTAssertEqual(plan.modelID, "gpt-4o-mini-transcribe")
        XCTAssertEqual(plan.kind, .cloud)
    }

    func testCloudPrivacyConsentIsRequiredBeforeResolution() {
        let resolver = TranscriptionTargetResolver(
            modelCatalog: .defaultCatalog,
            providerCatalog: .defaultCatalog
        )

        XCTAssertThrowsError(
            try resolver.resolve(
                preferences: TranscriptionPreferences(
                    selectedModelID: "whisper-large-v3-turbo",
                    autoTranscribeAfterCapture: false,
                    preferredLocalProviderID: "whisperkit-local",
                    preferredProviderID: "groq"
                ),
                providerSettings: ProviderSettings(
                    openAIEnabled: false,
                    groqEnabled: true,
                    openAIModelID: "gpt-4o-mini-transcribe",
                    groqModelID: "whisper-large-v3-turbo",
                    openAIPrivacyAcknowledged: false,
                    groqPrivacyAcknowledged: false
                ),
                readyLocalModelIDs: [],
                providerStatesByID: [
                    "groq": .privacyConsentRequired(message: "Consent required"),
                ]
            )
        ) { error in
            guard case let TranscriptionError.privacyConsentRequired(message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(message, "Consent required")
        }
    }
}
