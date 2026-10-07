import XCTest
@testable import TranscriptorKit

final class ModelCatalogTests: XCTestCase {
    func testWhisperCatalogModelsExposeVerifiedRuntimeVariants() {
        let catalog = ModelCatalog.defaultCatalog

        XCTAssertEqual(catalog.sections.map(\.id), ["whisper", "parakeet"])
        XCTAssertEqual(catalog.whisperModels.map(\.id), [
            "whisper-large-v3-turbo",
        ])
        XCTAssertEqual(
            catalog.model(id: "whisper-large-v3-turbo")?.remoteVariantName,
            "openai_whisper-large-v3-v20240930_turbo_632MB"
        )
        XCTAssertTrue(catalog.whisperModels.allSatisfy(\.supportsLocalTranscription))
    }

    func testParakeetModelsExposeRealLocalProviderMetadata() {
        let catalog = ModelCatalog.defaultCatalog
        let parakeetModels = catalog.sections.first(where: { $0.id == "parakeet" })?.models ?? []

        XCTAssertEqual(parakeetModels.map(\.id), ["parakeet-ultra-multilingual", "parakeet-v3-multilingual"])
        XCTAssertTrue(
            parakeetModels.allSatisfy {
                $0.supportsLocalTranscription && $0.localProviderID == "parakeet-local"
            }
        )
        XCTAssertTrue(
            parakeetModels.allSatisfy {
                $0.availability.message.contains("FluidAudio")
            }
        )
    }
}
