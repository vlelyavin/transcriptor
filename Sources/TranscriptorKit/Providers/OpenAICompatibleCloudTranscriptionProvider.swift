import Foundation

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

    public func validateCredentials(modelID: String) async throws {
        let apiKey = try requireAPIKey()
        var request = URLRequest(url: descriptor.baseURL.appending(path: "models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        let httpResponse = try requireHTTPResponse(response)

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw mapAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(CloudModelsListResponse.self, from: data)
        guard decoded.data.contains(where: { $0.id == modelID }) else {
            throw TranscriptionError.unsupportedModel("\(descriptor.name) does not currently expose the configured model '\(modelID)'.")
        }
    }

    public func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        let apiKey = try requireAPIKey()
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

        let requestBody = try multipartBody(for: job.audioFileURL, modelID: job.requestedModelID)
        var request = URLRequest(url: descriptor.baseURL.appending(path: "audio/transcriptions"))
        request.httpMethod = "POST"
        request.httpBody = requestBody.body
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(requestBody.contentType, forHTTPHeaderField: "Content-Type")

        progressHandler(
            TranscriptionProgress(
                stage: .transcribing,
                statusMessage: "Uploading audio to \(descriptor.name)…"
            )
        )

        let (data, response) = try await urlSession.data(for: request)
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

    private func requireAPIKey() throws -> String {
        guard let secret = try secretStore.secret(for: descriptor.keychainAccount), !secret.isEmpty else {
            throw TranscriptionError.missingCredentials("Add a \(descriptor.name) API key in Settings before using cloud transcription.")
        }

        return secret
    }

    private func requireHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.transcriptionFailed("Received an invalid response from \(descriptor.name).")
        }

        return httpResponse
    }

    private func multipartBody(for audioURL: URL, modelID: String) throws -> MultipartBody {
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

        switch statusCode {
        case 401, 403:
            return .missingCredentials(apiMessage ?? "\(descriptor.name) rejected the stored API key or account permissions.")
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
}
