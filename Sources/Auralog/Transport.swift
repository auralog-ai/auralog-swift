import Foundation

public enum AuralogSendResult: Sendable, Equatable {
    case success
    case retryableFailure
    case permanentFailure
}

public protocol AuralogTransport: Sendable {
    func sendBatch(_ entries: [AuralogEntry]) async -> AuralogSendResult
    func sendSingle(_ entry: AuralogEntry) async -> AuralogSendResult
}

struct AuralogBatchRequest: Encodable {
    var projectApiKey: String
    var logs: [AuralogEntry]
}

struct AuralogSingleRequest: Encodable {
    var projectApiKey: String
    var log: AuralogEntry
}

public final class AuralogHTTPTransport: NSObject, AuralogTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private let apiKey: String
    private let endpoint: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let redirectDelegate: AuralogRedirectRejectingDelegate

    public init(config: AuralogConfig) throws {
        try AuralogHTTPTransport.validate(config)
        self.apiKey = config.apiKey
        self.endpoint = config.endpoint
        let redirectDelegate = AuralogRedirectRejectingDelegate()
        self.redirectDelegate = redirectDelegate
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.httpTimeout
        configuration.timeoutIntervalForResource = config.httpTimeout
        configuration.httpAdditionalHeaders = [
            "User-Agent": "auralog-swift/0.1.0-beta.1"
        ]
        self.session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        self.encoder = JSONEncoder()
        super.init()
    }

    init(config: AuralogConfig, session: URLSession) throws {
        try AuralogHTTPTransport.validate(config)
        self.apiKey = config.apiKey
        self.endpoint = config.endpoint
        self.session = session
        self.encoder = JSONEncoder()
        self.redirectDelegate = AuralogRedirectRejectingDelegate()
        super.init()
    }

    public func sendBatch(_ entries: [AuralogEntry]) async -> AuralogSendResult {
        await post(path: "/v1/logs", body: AuralogBatchRequest(projectApiKey: apiKey, logs: entries))
    }

    public func sendSingle(_ entry: AuralogEntry) async -> AuralogSendResult {
        await post(path: "/v1/logs/single", body: AuralogSingleRequest(projectApiKey: apiKey, log: entry))
    }

    private func post<T: Encodable>(path: String, body: T) async -> AuralogSendResult {
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

    static func validate(_ config: AuralogConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw AuralogError.invalidConfiguration("auralog: apiKey is required")
        }
        guard !config.environment.isEmpty else {
            throw AuralogError.invalidConfiguration("auralog: environment is required")
        }
        guard config.endpoint.scheme?.lowercased() == "https" || (config.allowInsecureEndpoint && config.endpoint.scheme?.lowercased() == "http") else {
            throw AuralogError.invalidConfiguration("auralog: endpoint must use https:// unless allowInsecureEndpoint is true")
        }
        guard config.flushInterval > 0,
              config.retryInitialDelay > 0,
              config.retryMaxDelay >= config.retryInitialDelay,
              config.httpTimeout > 0,
              config.shutdownTimeout > 0 else {
            throw AuralogError.invalidConfiguration("auralog: durations must be greater than zero and retryMaxDelay must be >= retryInitialDelay")
        }
        guard config.maxBatchSize > 0,
              config.maxQueueSize > 0,
              config.maxRetryAttempts > 0 else {
            throw AuralogError.invalidConfiguration("auralog: queue and retry sizes must be greater than zero")
        }
    }
}

private final class AuralogRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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
