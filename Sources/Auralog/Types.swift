import Foundation

public enum AuralogLevel: String, Codable, Sendable {
    case debug
    case info
    case warn
    case error
    case fatal

    var isPriority: Bool {
        self == .error || self == .fatal
    }
}

public typealias AuralogMetadata = [String: AuralogValue]

public enum AuralogValue: Codable, Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AuralogValue])
    case object([String: AuralogValue])
    case null

    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(nilLiteral: ()) { self = .null }
    public init(arrayLiteral elements: AuralogValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, AuralogValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AuralogValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: AuralogValue].self))
        }
    }
}

public struct AuralogConfig: Sendable {
    public var apiKey: String
    public var environment: String
    public var endpoint: URL
    public var allowInsecureEndpoint: Bool
    public var flushInterval: TimeInterval
    public var maxBatchSize: Int
    public var maxQueueSize: Int
    public var maxRetryAttempts: Int
    public var retryInitialDelay: TimeInterval
    public var retryMaxDelay: TimeInterval
    public var httpTimeout: TimeInterval
    public var shutdownTimeout: TimeInterval
    public var traceId: String
    public var globalMetadata: AuralogMetadata
    public var globalMetadataProvider: (@Sendable () -> AuralogMetadata?)?
    public var captureMetricKit: Bool
    public var captureUnhandledExceptions: Bool

    public init(
        apiKey: String,
        environment: String = "production",
        endpoint: URL = URL(string: "https://ingest.auralog.ai")!,
        allowInsecureEndpoint: Bool = false,
        flushInterval: TimeInterval = 5,
        maxBatchSize: Int = 50,
        maxQueueSize: Int = 1000,
        maxRetryAttempts: Int = 5,
        retryInitialDelay: TimeInterval = 1,
        retryMaxDelay: TimeInterval = 30,
        httpTimeout: TimeInterval = 30,
        shutdownTimeout: TimeInterval = 2,
        traceId: String = AuralogTrace.generate(),
        globalMetadata: AuralogMetadata = [:],
        globalMetadataProvider: (@Sendable () -> AuralogMetadata?)? = nil,
        captureMetricKit: Bool = false,
        captureUnhandledExceptions: Bool = false
    ) {
        self.apiKey = apiKey
        self.environment = environment
        self.endpoint = endpoint
        self.allowInsecureEndpoint = allowInsecureEndpoint
        self.flushInterval = flushInterval
        self.maxBatchSize = maxBatchSize
        self.maxQueueSize = maxQueueSize
        self.maxRetryAttempts = maxRetryAttempts
        self.retryInitialDelay = retryInitialDelay
        self.retryMaxDelay = retryMaxDelay
        self.httpTimeout = httpTimeout
        self.shutdownTimeout = shutdownTimeout
        self.traceId = traceId
        self.globalMetadata = globalMetadata
        self.globalMetadataProvider = globalMetadataProvider
        self.captureMetricKit = captureMetricKit
        self.captureUnhandledExceptions = captureUnhandledExceptions
    }
}

public struct AuralogEntry: Codable, Equatable, Sendable {
    public var level: AuralogLevel
    public var message: String
    public var environment: String
    public var timestamp: String
    public var metadata: AuralogMetadata?
    public var stackTrace: String?
    public var traceId: String
}

public enum AuralogError: Error, Equatable, LocalizedError {
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return message
        }
    }
}

public enum AuralogTrace {
    public static func generate() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}
