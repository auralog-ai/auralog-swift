import Auralogs
import Logging

public enum AuralogsSwiftLog {
    public static func install() {
        LoggingSystem.bootstrap { label in
            AuralogsLogHandler(label: label)
        }
    }
}

public struct AuralogsLogHandler: LogHandler {
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?
    public var logLevel: Logger.Level = .info
    private let label: String

    public init(label: String) {
        self.label = label
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }

    public func log(event: LogEvent) {
        let level = event.level
        guard level >= logLevel else { return }
        var merged = metadata
        if let providerMetadata = metadataProvider?.get() {
            for (key, value) in providerMetadata {
                merged[key] = value
            }
        }
        if let callMetadata = event.metadata {
            for (key, value) in callMetadata {
                merged[key] = value
            }
        }

        var auralogsMetadata = Self.convert(merged)
        auralogsMetadata["logger"] = .string(label)
        auralogsMetadata["source"] = .string(event.source)
        auralogsMetadata["file"] = .string(event.file)
        auralogsMetadata["function"] = .string(event.function)
        auralogsMetadata["line"] = .int(Int(event.line))
        if let error = event.error {
            auralogsMetadata["errorDescription"] = .string(String(describing: error))
        }

        switch level {
        case .trace, .debug:
            Auralogs.debug(event.message.description, metadata: auralogsMetadata)
        case .info, .notice:
            Auralogs.info(event.message.description, metadata: auralogsMetadata)
        case .warning:
            Auralogs.warn(event.message.description, metadata: auralogsMetadata)
        case .error:
            Auralogs.error(event.message.description, metadata: auralogsMetadata)
        case .critical:
            Auralogs.fatal(event.message.description, metadata: auralogsMetadata)
        }
    }

    private static func convert(_ metadata: Logger.Metadata) -> AuralogsMetadata {
        var converted: AuralogsMetadata = [:]
        for (key, value) in metadata {
            converted[key] = convert(value)
        }
        return converted
    }

    private static func convert(_ value: Logger.Metadata.Value) -> AuralogsValue {
        switch value {
        case .string(let value):
            return .string(value)
        case .stringConvertible(let value):
            return .string(value.description)
        case .array(let values):
            return .array(values.map(convert))
        case .dictionary(let values):
            var converted: [String: AuralogsValue] = [:]
            for (key, value) in values {
                converted[key] = convert(value)
            }
            return .object(converted)
        }
    }
}
