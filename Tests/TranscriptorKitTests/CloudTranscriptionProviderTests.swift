import Foundation
import XCTest
@testable import TranscriptorKit

final class CloudTranscriptionProviderTests: XCTestCase {
    func testOpenAITranscriptionBuildsMultipartRequestAndParsesResponse() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"text":"hello from openai"}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "openai")),
            secretStore: InMemorySecretStore(secrets: ["openai-api-key": "sk-test"]),
            urlSession: loader
        )
        let audioURL = try makeTempAudioFile(named: "openai-sample.wav")

        let result = try await provider.transcribe(
            job: TranscriptionJob(
                historyEntryID: UUID(),
                audioFileURL: audioURL,
                requestedProviderID: "openai",
                requestedProviderName: "OpenAI",
                requestedModelID: "gpt-4o-mini-transcribe",
                requestedModelName: "gpt-4o-mini-transcribe",
                sourceType: .dictation
            )
        ) { _ in }

        XCTAssertEqual(result.text, "hello from openai")
        let request = try XCTUnwrap(loader.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/audio/transcriptions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains(#"name="model""#))
        XCTAssertTrue(body.contains("gpt-4o-mini-transcribe"))
        XCTAssertTrue(body.contains(#"name="file"; filename="openai-sample.wav""#))
    }

    func testGroqValidationUsesModelsEndpoint() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"data":[{"id":"whisper-large-v3-turbo"}]}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "https://api.groq.com/openai/v1/models")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "groq")),
            secretStore: InMemorySecretStore(secrets: ["groq-api-key": "gsk_test"]),
            urlSession: loader
        )

        try await provider.validateCredentials(modelID: "whisper-large-v3-turbo")

        let request = try XCTUnwrap(loader.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.groq.com/openai/v1/models")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer gsk_test")
    }

    func testCloudProviderFailsCleanlyWhenKeyIsMissing() async {
        let loader = MockHTTPDataLoader()
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try! XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "openai")),
            secretStore: InMemorySecretStore(),
            urlSession: loader
        )
        let audioURL = try! makeTempAudioFile(named: "missing-key.wav")

        do {
            _ = try await provider.transcribe(
                job: TranscriptionJob(
                    historyEntryID: UUID(),
                    audioFileURL: audioURL,
                    requestedProviderID: "openai",
                    requestedProviderName: "OpenAI",
                    requestedModelID: "gpt-4o-mini-transcribe",
                    requestedModelName: "gpt-4o-mini-transcribe",
                    sourceType: .dictation
                )
            ) { _ in }
            XCTFail("Expected missing credentials error")
        } catch let error as TranscriptionError {
            guard case let .missingCredentials(message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message.contains("OpenAI API key"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(loader.requests.isEmpty)
    }

    func testLanguageHintIsSentInMultipartBody() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"text":"привет"}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "groq")),
            secretStore: InMemorySecretStore(secrets: ["groq-api-key": "gsk_test"]),
            urlSession: loader
        )
        let audioURL = try makeTempAudioFile(named: "ru.wav")

        _ = try await provider.transcribe(
            job: TranscriptionJob(
                historyEntryID: UUID(),
                audioFileURL: audioURL,
                requestedProviderID: "groq",
                requestedProviderName: "Groq",
                requestedModelID: "whisper-large-v3-turbo",
                requestedModelName: "whisper-large-v3-turbo",
                sourceType: .dictation,
                language: "ru"
            )
        ) { _ in }

        let body = try XCTUnwrap(loader.requests.first?.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains(#"name="language""#))
        XCTAssertTrue(body.contains("\r\nru\r\n"))
    }

    func testNoLanguageFieldWhenAutoDetecting() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"text":"hi"}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "groq")),
            secretStore: InMemorySecretStore(secrets: ["groq-api-key": "gsk_test"]),
            urlSession: loader
        )
        let audioURL = try makeTempAudioFile(named: "auto.wav")

        _ = try await provider.transcribe(
            job: TranscriptionJob(
                historyEntryID: UUID(),
                audioFileURL: audioURL,
                requestedProviderID: "groq",
                requestedProviderName: "Groq",
                requestedModelID: "whisper-large-v3-turbo",
                requestedModelName: "whisper-large-v3-turbo",
                sourceType: .dictation
            )
        ) { _ in }

        let body = try XCTUnwrap(loader.requests.first?.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertFalse(body.contains(#"name="language""#))
    }

    func testCustomServerUsesConfiguredURLAndWorksWithoutKey() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"text":"from custom"}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "http://10.0.0.5:8000/v1/audio/transcriptions")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "custom")),
            secretStore: InMemorySecretStore(),
            urlSession: loader
        )
        provider.setBaseURL(URL(string: "http://10.0.0.5:8000/v1"))
        let audioURL = try makeTempAudioFile(named: "custom.wav")

        let result = try await provider.transcribe(
            job: TranscriptionJob(
                historyEntryID: UUID(),
                audioFileURL: audioURL,
                requestedProviderID: "custom",
                requestedProviderName: "Custom Server",
                requestedModelID: "whisper-1",
                requestedModelName: "whisper-1",
                sourceType: .dictation
            )
        ) { _ in }

        XCTAssertEqual(result.text, "from custom")
        let request = try XCTUnwrap(loader.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://10.0.0.5:8000/v1/audio/transcriptions")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testCustomServerValidationFallsBackToTranscriptionWhenModelsEndpointIsMissing() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data("Not Found".utf8),
                response: HTTPURLResponse(
                    url: URL(string: "http://10.0.0.5:8000/v1/models")!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            .init(
                data: Data(#"{"text":""}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "http://10.0.0.5:8000/v1/audio/transcriptions")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "custom")),
            secretStore: InMemorySecretStore(secrets: ["custom-api-key": "token"]),
            urlSession: loader
        )
        provider.setBaseURL(URL(string: "http://10.0.0.5:8000/v1"))

        try await provider.validateCredentials(modelID: "whisper-1")

        XCTAssertEqual(loader.requests.count, 2)
        XCTAssertEqual(loader.requests.last?.url?.path, "/v1/audio/transcriptions")
        XCTAssertEqual(loader.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testElevenLabsDialectUsesScribeEndpointAndHeaderNames() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"text":"privet ot elevenlabs","language_code":"rus"}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "elevenlabs")),
            secretStore: InMemorySecretStore(secrets: ["elevenlabs-api-key": "el_test"]),
            urlSession: loader
        )
        let audioURL = try makeTempAudioFile(named: "elevenlabs-sample.wav")

        let result = try await provider.transcribe(
            job: TranscriptionJob(
                historyEntryID: UUID(),
                audioFileURL: audioURL,
                requestedProviderID: "elevenlabs",
                requestedProviderName: "ElevenLabs",
                requestedModelID: "scribe_v3",
                requestedModelName: "scribe_v3",
                sourceType: .dictation,
                language: "ru"
            )
        ) { _ in }

        XCTAssertEqual(result.text, "privet ot elevenlabs")
        // ElevenLabs returns `language_code`, not OpenAI's `language`.
        XCTAssertEqual(result.language, "rus")

        let request = try XCTUnwrap(loader.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.elevenlabs.io/v1/speech-to-text")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "el_test")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try XCTUnwrap(request.httpBody.map { String(decoding: $0, as: UTF8.self) })
        XCTAssertTrue(body.contains(#"name="model_id""#))
        XCTAssertTrue(body.contains("scribe_v3"))
        XCTAssertTrue(body.contains(#"name="language_code""#))
        XCTAssertTrue(body.contains("\r\nru\r\n"))
        XCTAssertFalse(body.contains(#"name="response_format""#))
        XCTAssertFalse(body.contains(#"name="temperature""#))
    }

    func testElevenLabsValidationTranscribesSilenceInsteadOfListingModels() async throws {
        let loader = MockHTTPDataLoader()
        loader.responses = [
            .init(
                data: Data(#"{"text":""}"#.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        ]
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: try XCTUnwrap(ProviderCatalog.defaultCatalog.provider(id: "elevenlabs")),
            secretStore: InMemorySecretStore(secrets: ["elevenlabs-api-key": "el_test"]),
            urlSession: loader
        )

        try await provider.validateCredentials(modelID: "scribe_v3")

        // Scribe is absent from /models, so validation must never call it.
        XCTAssertEqual(loader.requests.count, 1)
        let request = try XCTUnwrap(loader.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/speech-to-text")
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "el_test")
        let body = try XCTUnwrap(request.httpBody.map { String(decoding: $0, as: UTF8.self) })
        XCTAssertTrue(body.contains(#"name="model_id""#))
        XCTAssertTrue(body.contains("scribe_v3"))
    }

    private func makeTempAudioFile(named fileName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audioURL = directory.appendingPathComponent(fileName)
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: audioURL)
        return audioURL
    }
}

private final class MockHTTPDataLoader: HTTPDataLoading, @unchecked Sendable {
    struct StubbedResponse: Sendable {
        let data: Data
        let response: HTTPURLResponse
    }

    private(set) var requests: [URLRequest] = []
    var responses: [StubbedResponse] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let next = responses.removeFirst()
        return (next.data, next.response)
    }
}

private struct InMemorySecretStore: SecretStore {
    var secrets: [String: String] = [:]

    func secret(for account: String) throws -> String? {
        secrets[account]
    }

    func saveSecret(_ secret: String, for account: String) throws {
        _ = (secret, account)
        throw SecretStoreError.unexpectedStatus(errSecParam)
    }

    func deleteSecret(for account: String) throws {
        _ = account
        throw SecretStoreError.unexpectedStatus(errSecParam)
    }

    func containsSecret(for account: String) throws -> Bool {
        secrets[account] != nil
    }
}
