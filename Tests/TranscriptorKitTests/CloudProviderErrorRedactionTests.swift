import XCTest
@testable import TranscriptorKit

/// Verifies that a provider's API key is never surfaced in error messages, even
/// when the remote service echoes it back (as OpenAI does on a bad key).
final class CloudProviderErrorRedactionTests: XCTestCase {
    func testValidationErrorDoesNotLeakAPIKey() async throws {
        let key = "sk-anabcd1234567890XYZdefuvwxyzgAA"
        let descriptor = ProviderCatalog.defaultCatalog.provider(id: "openai")!
        let bodyEchoingKey = """
        {"error":{"message":"Incorrect API key provided: \(key). You can find your API key at https://platform.openai.com/account/api-keys."}}
        """
        let loader = StubHTTPLoader(
            statusCode: 401,
            body: Data(bodyEchoingKey.utf8),
            url: descriptor.baseURL.appending(path: "models")
        )
        let provider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: descriptor,
            secretStore: StubKeyStore(key: key),
            urlSession: loader
        )

        do {
            try await provider.validateCredentials(modelID: "gpt-4o-mini-transcribe")
            XCTFail("Expected validation to throw for a 401 response")
        } catch {
            let message = error.localizedDescription
            XCTAssertFalse(message.contains(key), "Raw API key leaked in error: \(message)")
            XCTAssertFalse(message.localizedCaseInsensitiveContains("sk-an"), "Masked key prefix leaked: \(message)")
            // Auth failures present one unified, provider-agnostic message.
            XCTAssertTrue(message.localizedCaseInsensitiveContains("the api key was rejected"))
        }
    }
}

private struct StubHTTPLoader: HTTPDataLoading {
    let statusCode: Int
    let body: Data
    let url: URL

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

private struct StubKeyStore: SecretStore {
    let key: String
    func secret(for account: String) throws -> String? { key }
    func saveSecret(_ secret: String, for account: String) throws {}
    func deleteSecret(for account: String) throws {}
    func containsSecret(for account: String) throws -> Bool { true }
}
