import Foundation

public enum AuralogsSendResult: Sendable, Equatable {
    case success
    case retryableFailure
    case permanentFailure
}

public protocol AuralogsTransport: Sendable {
    func sendBatch(_ entries: [AuralogsEntry]) async -> AuralogsSendResult
    func sendSingle(_ entry: AuralogsEntry) async -> AuralogsSendResult
}

struct AuralogsBatchRequest: Encodable {
    var projectApiKey: String
    var logs: [AuralogsEntry]
}

struct AuralogsSingleRequest: Encodable {
    var projectApiKey: String
    var log: AuralogsEntry
}

public final class AuralogsHTTPTransport: NSObject, AuralogsTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let redirectDelegate: AuralogsRedirectRejectingDelegate

    public init(config: AuralogsConfig) throws {
        try AuralogsHTTPTransport.validate(config)
        self.apiKey = config.apiKey
        self.endpoint = config.endpoint
        let redirectDelegate = AuralogsRedirectRejectingDelegate()
        self.redirectDelegate = redirectDelegate
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.httpTimeout
        configuration.timeoutIntervalForResource = config.httpTimeout
        configuration.httpAdditionalHeaders = [
            "User-Agent": "auralogs-swift/0.1.0-beta.1"
        ]
        self.session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        self.encoder = JSONEncoder()
        super.init()
    }

    init(config: AuralogsConfig, session: URLSession) throws {
        try AuralogsHTTPTransport.validate(config)
        self.apiKey = config.apiKey
        self.endpoint = config.endpoint
        self.session = session
        self.encoder = JSONEncoder()
        self.redirectDelegate = AuralogsRedirectRejectingDelegate()
        super.init()
    }

    public func sendBatch(_ entries: [AuralogsEntry]) async -> AuralogsSendResult {
        await post(path: "/v1/logs", body: AuralogsBatchRequest(projectApiKey: apiKey, logs: entries))
    }

    public func sendSingle(_ entry: AuralogsEntry) async -> AuralogsSendResult {
        await post(path: "/v1/logs/single", body: AuralogsSingleRequest(projectApiKey: apiKey, log: entry))
    }

    private func post<T: Encodable>(path: String, body: T) async -> AuralogsSendResult {
        let url = endpoint.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(body)
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .retryableFailure
            }
            if (200..<300).contains(http.statusCode) {
                return .success
            }
            if (300..<400).contains(http.statusCode) || (400..<500).contains(http.statusCode) {
                return .permanentFailure
            }
            return .retryableFailure
        } catch {
            return .retryableFailure
        }
    }

    static func validate(_ config: AuralogsConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw AuralogsError.invalidConfiguration("auralogs: apiKey is required")
        }
        guard !config.environment.isEmpty else {
            throw AuralogsError.invalidConfiguration("auralogs: environment is required")
        }
        guard config.endpoint.scheme?.lowercased() == "https" || (config.allowInsecureEndpoint && config.endpoint.scheme?.lowercased() == "http") else {
            throw AuralogsError.invalidConfiguration("auralogs: endpoint must use https:// unless allowInsecureEndpoint is true")
        }
        guard config.flushInterval > 0,
              config.retryInitialDelay > 0,
              config.retryMaxDelay >= config.retryInitialDelay,
              config.httpTimeout > 0,
              config.shutdownTimeout > 0 else {
            throw AuralogsError.invalidConfiguration("auralogs: durations must be greater than zero and retryMaxDelay must be >= retryInitialDelay")
        }
        guard config.maxBatchSize > 0,
              config.maxQueueSize > 0,
              config.maxRetryAttempts > 0 else {
            throw AuralogsError.invalidConfiguration("auralogs: queue and retry sizes must be greater than zero")
        }
    }
}

private final class AuralogsRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
