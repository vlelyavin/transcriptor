import XCTest
@testable import TranscriptorKit

final class ModelCatalogTests: XCTestCase {
    func testWhisperCatalogModelsExposeVerifiedRuntimeVariants() {
        let catalog = ModelCatalog.defaultCatalog

        XCTAssertEqual(catalog.sections.map(\.id), ["whisper", "parakeet"])
        XCTAssertEqual(catalog.whisperModels.map(\.id), [
            "whisper-tiny",
            "whisper-base-en",
            "whisper-small-en",
            "whisper-large-v3-turbo",
            "whisper-distil-large-v3",
        ])
        XCTAssertEqual(
            catalog.model(id: "whisper-large-v3-turbo")?.remoteVariantName,
            "openai_whisper-large-v3-v20240930_turbo_632MB"
        )
        XCTAssertEqual(
            catalog.model(id: "whisper-distil-large-v3")?.remoteVariantName,
            "distil-whisper_distil-large-v3_594MB"
        )
        XCTAssertTrue(catalog.whisperModels.allSatisfy(\.supportsLocalTranscription))
    }

    func testParakeetModelsRemainVisiblyUnavailableUntilNativeRuntimeExists() {
        let catalog = ModelCatalog.defaultCatalog
        let parakeetModels = catalog.sections.first(where: { $0.id == "parakeet" })?.models ?? []

        XCTAssertEqual(parakeetModels.map(\.id), ["parakeet-v2-en", "parakeet-v3-multilingual"])
        XCTAssertTrue(
            parakeetModels.allSatisfy {
                if case .unavailable = $0.availability {
                    return true
                }
                return false
            }
        )
        XCTAssertTrue(
            parakeetModels.allSatisfy {
                $0.availability.message.contains("macOS runtime")
            }
        )
    }
}
