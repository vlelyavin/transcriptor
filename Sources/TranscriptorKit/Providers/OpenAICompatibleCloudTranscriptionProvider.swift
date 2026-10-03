import Foundation
import os

public protocol HTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {}

public actor OpenAICompatibleCloudTranscriptionProvider: CloudTranscriptionProvider {
    public let id: String
    public let displayName: String
    public let kind: TranscriptionProviderKind = .cloud

    private let descriptor: ProviderDescriptor
    private let secretStore: any SecretStore
    private let urlSession: any HTTPDataLoading
    private let fileManager: FileManager
    /// Runtime base URL for providers whose endpoint is user-configured (the
    /// custom server). Lock-protected so the main actor can update it
    /// synchronously before a request is queued.
    private let baseURLOverride = OSAllocatedUnfairLock<URL?>(initialState: nil)

    public init(
        descriptor: ProviderDescriptor,
        secretStore: any SecretStore,
        urlSession: any HTTPDataLoading = URLSession.shared,
        fileManager: FileManager = .default
    ) {
        self.descriptor = descriptor
        self.secretStore = secretStore
        self.urlSession = urlSession
        self.fileManager = fileManager
        self.id = descriptor.id
        self.displayName = descriptor.name
    }

    public nonisolated func setBaseURL(_ url: URL?) {
        baseURLOverride.withLock { $0 = url }
    }

    private var baseURL: URL {
        baseURLOverride.withLock { $0 } ?? descriptor.baseURL
    }

    public func validateCredentials(modelID: String) async throws {
        let apiKey = try resolveAPIKey()
        var request = URLRequest(url: baseURL.appending(path: "models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        authorize(&request, apiKey: apiKey)

        let (data, response) = try await performData(for: request)
        let httpResponse = try requireHTTPResponse(response)

        // Self-hosted / proxy servers frequently implement only the
        // transcription endpoint. For the custom server, fall back to a real
        // (tiny, silent) transcription request — the exact path dictation uses.
        if !descriptor.requiresAPIKey, [404, 405, 501].contains(httpResponse.statusCode) {
            try await validateByTranscribingSilence(modelID: modelID, apiKey: apiKey)
            return
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        // Built-in vendors list their models, so a missing ID is almost
        // certainly a typo. Custom servers often list nothing or aliases, so
        // a reachable, authorized endpoint is enough there.
        guard descriptor.requiresAPIKey else {
            return
        }
        let decoded = try JSONDecoder().decode(CloudModelsListResponse.self, from: data)
        guard decoded.data.contains(where: { $0.id == modelID }) else {
            throw TranscriptionError.unsupportedModel("\(descriptor.name) does not currently expose the configured model '\(modelID)'.")
        }
    }

    private func validateByTranscribingSilence(modelID: String, apiKey: String?) async throws {
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let audioURL = directory.appendingPathComponent("validation.wav")
        try Self.silentWAV(seconds: 0.6).write(to: audioURL)

        let body = try multipartBody(for: audioURL, modelID: modelID, language: nil)
        var request = URLRequest(url: baseURL.appending(path: "audio/transcriptions"))
        request.httpMethod = "POST"
        request.httpBody = body.body
        request.timeoutInterval = 30
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        authorize(&request, apiKey: apiKey)

        let (data, response) = try await performData(for: request)
        let httpResponse = try requireHTTPResponse(response)
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapAPIError(data: data, statusCode: httpResponse.statusCode)
        }
    }

    /// 16 kHz mono 16-bit PCM silence.
    static func silentWAV(seconds: Double) -> Data {
        let sampleRate: UInt32 = 16_000
        let sampleCount = UInt32(Double(sampleRate) * seconds)
        let dataSize = sampleCount * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36) + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(sampleRate); append(sampleRate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }

    public func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        let apiKey = try resolveAPIKey()
        guard fileManager.fileExists(atPath: job.audioFileURL.path) else {
            throw TranscriptionError.missingAudioFile("The audio file for this history item could not be found.")
        }

        let fileAttributes = try fileManager.attributesOfItem(atPath: job.audioFileURL.path)
        let fileSize = (fileAttributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize <= descriptor.directUploadLimitBytes else {
            let limitMegabytes = Int(descriptor.directUploadLimitBytes / 1_048_576)
            let actualMegabytes = Int((Double(fileSize) / 1_048_576).rounded(.up))
            throw TranscriptionError.fileTooLarge(
                "\(descriptor.name) direct uploads are currently limited to \(limitMegabytes) MB in this build. This file is \(actualMegabytes) MB, and chunking is not implemented yet."
            )
        }

        progressHandler(
            TranscriptionProgress(
                stage: .preparingAudio,
                statusMessage: "Preparing secure upload for \(descriptor.name)…"
            )
        )

        let requestBody = try multipartBody(for: job.audioFileURL, modelID: job.requestedModelID, language: job.language)
        var request = URLRequest(url: baseURL.appending(path: "audio/transcriptions"))
        request.httpMethod = "POST"
        request.httpBody = requestBody.body
        // Long dictations upload several MB; the 60 s default is too tight on
        // a slow uplink.
        request.timeoutInterval = 120
        authorize(&request, apiKey: apiKey)
        request.setValue(requestBody.contentType, forHTTPHeaderField: "Content-Type")

        progressHandler(
            TranscriptionProgress(
                stage: .transcribing,
                statusMessage: "Uploading audio to \(descriptor.name)…"
            )
        )

        let (data, response) = try await performData(for: request)
        let httpResponse = try requireHTTPResponse(response)

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        progressHandler(
            TranscriptionProgress(
                stage: .finalizing,
                statusMessage: "Finalizing \(descriptor.name) transcript…"
            )
        )

        let decoded = try JSONDecoder().decode(CloudTranscriptionResponse.self, from: data)
        let normalizedText = decoded.text.normalizedTranscriptWhitespace()
        guard !normalizedText.isEmpty else {
            throw TranscriptionError.transcriptionFailed("\(descriptor.name) returned an empty transcript.")
        }

        return TranscriptionResult(
            text: normalizedText,
            preview: String(normalizedText.prefix(180)),
            characterCount: normalizedText.count,
            language: decoded.language,
            modelID: job.requestedModelID,
            modelName: job.requestedModelName,
            providerID: descriptor.id,
            providerName: descriptor.name
        )
    }

    /// The stored key, or `nil` for a keyless custom server.
    private func resolveAPIKey() throws -> String? {
        let secret = try secretStore.secret(for: descriptor.keychainAccount)
        if let secret, !secret.isEmpty {
            return secret
        }
        guard !descriptor.requiresAPIKey else {
            throw TranscriptionError.missingCredentials("Add a \(descriptor.name) API key in Settings before using cloud transcription.")
        }
        return nil
    }

    private func authorize(_ request: inout URLRequest, apiKey: String?) {
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    /// `URLSession.data(for:)` throws `URLError(.cancelled)` — not
    /// `CancellationError` — when the surrounding task is cancelled. Map it so
    /// a user-cancelled upload takes the quiet `.cancelled` path instead of
    /// being recorded (and notified) as a failure.
    private func performData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw TranscriptionError.cancelled
        }
    }

    private func requireHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.transcriptionFailed("Received an invalid response from \(descriptor.name).")
        }

        return httpResponse
    }

    private func multipartBody(for audioURL: URL, modelID: String, language: String?) throws -> MultipartBody {
        let boundary = "Boundary-\(UUID().uuidString)"
        let audioData = try Data(contentsOf: audioURL, options: .mappedIfSafe)
        var body = Data()

        body.appendMultipartLine("--\(boundary)")
        body.appendMultipartLine(#"Content-Disposition: form-data; name="model""#)
        body.appendMultipartLine("")
        body.appendMultipartLine(modelID)

        body.appendMultipartLine("--\(boundary)")
        body.appendMultipartLine(#"Content-Disposition: form-data; name="response_format""#)
        body.appendMultipartLine("")
        body.appendMultipartLine("json")

        body.appendMultipartLine("--\(boundary)")
        body.appendMultipartLine(#"Content-Disposition: form-data; name="temperature""#)
        body.appendMultipartLine("")
        body.appendMultipartLine("0")

        // Without a hint, auto-detection on short clips often picks the wrong
        // language (short Russian phrases came back transliterated to Latin).
        if let language, !language.isEmpty {
            body.appendMultipartLine("--\(boundary)")
            body.appendMultipartLine(#"Content-Disposition: form-data; name="language""#)
            body.appendMultipartLine("")
            body.appendMultipartLine(language)
        }

        body.appendMultipartLine("--\(boundary)")
        body.appendMultipartLine(#"Content-Disposition: form-data; name="file"; filename="\#(audioURL.lastPathComponent)""#)
        body.appendMultipartLine("Content-Type: application/octet-stream")
        body.appendMultipartLine("")
        body.append(audioData)
        body.appendMultipartLine("")
        body.appendMultipartLine("--\(boundary)--")

        return MultipartBody(
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    private func mapAPIError(data: Data, statusCode: Int) -> TranscriptionError {
        let apiMessage = (try? JSONDecoder().decode(CloudAPIErrorEnvelope.self, from: data).error.message)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .redactingAPIKeys()

        switch statusCode {
        case 401:
            // Unified across providers: the upstream wording differs between
            // OpenAI and Groq, so present one consistent, non-leaking message.
            return .missingCredentials("The API key was rejected. Check that the key is correct and active, then try again.")
        case 403:
            // A 403 can also mean a region or model-permission block — the key
            // itself may be fine, so "key rejected" would give the wrong advice.
            // Prefer the provider's own (already API-key-redacted) message.
            return .missingCredentials(apiMessage ?? "\(descriptor.name) refused the request (HTTP 403). Check the key's permissions and region access, then try again.")
        case 413:
            return .fileTooLarge(apiMessage ?? "\(descriptor.name) rejected the audio upload because it exceeded the provider's current file-size limit.")
        case 429:
            return .rateLimited(apiMessage ?? "\(descriptor.name) rate-limited the request. Please retry in a moment.")
        default:
            return .transcriptionFailed(apiMessage ?? "\(descriptor.name) returned HTTP \(statusCode).")
        }
    }
}

private struct MultipartBody: Sendable {
    let body: Data
    let contentType: String
}

private struct CloudTranscriptionResponse: Decodable, Sendable {
    let text: String
    let language: String?
}

private struct CloudAPIErrorEnvelope: Decodable, Sendable {
    struct APIError: Decodable, Sendable {
        let message: String
    }

    let error: APIError
}

private struct CloudModelsListResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let id: String
    }

    let data: [Item]
}

private extension Data {
    mutating func appendMultipartLine(_ line: String) {
        append(Data((line + "\r\n").utf8))
    }
}

private extension String {
    func normalizedTranscriptWhitespace() -> String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips any API-key-like token from a provider error message so the raw
    /// (or even partially masked) key is never surfaced in UI, logs, or history.
    /// Providers like OpenAI echo the offending key back in their error text
    /// (e.g. "Incorrect API key provided: sk-…****…gAA"); this replaces such
    /// tokens with a neutral phrase while keeping the rest of the message.
    func redactingAPIKeys() -> String {
        // Matches OpenAI/Groq-style secrets ("sk-…", "gsk_…"), including masked
        // variants that contain "*" or "…"/"." runs.
        let pattern = "(?i)\\b(?:sk|gsk|rk|pk)[-_][A-Za-z0-9\\-_*.…]+"
        let redacted = replacingOccurrences(
            of: pattern,
            with: "your API key",
            options: .regularExpression
        )
        return redacted.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
