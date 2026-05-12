import Auralog
import Logging

public enum AuralogSwiftLog {
    public static func install() {
        LoggingSystem.bootstrap { label in
            AuralogLogHandler(label: label)
        }
    }
}

public struct AuralogLogHandler: LogHandler {
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

        var auralogMetadata = Self.convert(merged)
        auralogMetadata["logger"] = .string(label)
        auralogMetadata["source"] = .string(event.source)
        auralogMetadata["file"] = .string(event.file)
        auralogMetadata["function"] = .string(event.function)
        auralogMetadata["line"] = .int(Int(event.line))
        if let error = event.error {
            auralogMetadata["errorDescription"] = .string(String(describing: error))
        }

        switch level {
        case .trace, .debug:
            Auralog.debug(event.message.description, metadata: auralogMetadata)
        case .info, .notice:
            Auralog.info(event.message.description, metadata: auralogMetadata)
        case .warning:
            Auralog.warn(event.message.description, metadata: auralogMetadata)
        case .error:
            Auralog.error(event.message.description, metadata: auralogMetadata)
        case .critical:
            Auralog.fatal(event.message.description, metadata: auralogMetadata)
        }
    }

    private static func convert(_ metadata: Logger.Metadata) -> AuralogMetadata {
        var converted: AuralogMetadata = [:]
        for (key, value) in metadata {
            converted[key] = convert(value)
        }
        return converted
    }

    private static func convert(_ value: Logger.Metadata.Value) -> AuralogValue {
        switch value {
        case .string(let value):
            return .string(value)
        case .stringConvertible(let value):
            return .string(value.description)
        case .array(let values):
            return .array(values.map(convert))
        case .dictionary(let values):
            var converted: [String: AuralogValue] = [:]
            for (key, value) in values {
                converted[key] = convert(value)
            }
            return .object(converted)
        }
    }
}
