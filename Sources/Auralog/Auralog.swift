import Foundation

public enum Auralog {
    private static let lock = NSLock()
    private static var client: AuralogClient?
    private static var metricKitCapture: AuralogMetricKitCapture?

    @discardableResult
    public static func initialize(_ config: AuralogConfig, transport: AuralogTransport? = nil) throws -> AuralogClient {
        let newClient = try AuralogClient(config: config, transport: transport)
        lock.lock()
        defer { lock.unlock() }
        guard client == nil else {
            Task { await newClient.shutdown() }
            throw AuralogError.invalidConfiguration("auralog: global client is already initialized")
        }
        client = newClient
        if config.captureUnhandledExceptions {
            AuralogExceptionCapture.install(client: newClient)
        }
        if config.captureMetricKit {
            metricKitCapture = AuralogMetricKitCapture.install(client: newClient)
        }
        return newClient
    }

    public static func initialize(
        apiKey: String,
        environment: String = "production",
        endpoint: URL = URL(string: "https://ingest.auralog.ai")!,
        allowInsecureEndpoint: Bool = false,
        globalMetadata: AuralogMetadata = [:],
        globalMetadataProvider: (@Sendable () -> AuralogMetadata?)? = nil,
        captureMetricKit: Bool = false,
        captureUnhandledExceptions: Bool = false
    ) throws {
        _ = try initialize(AuralogConfig(
            apiKey: apiKey,
            environment: environment,
            endpoint: endpoint,
            allowInsecureEndpoint: allowInsecureEndpoint,
            globalMetadata: globalMetadata,
            globalMetadataProvider: globalMetadataProvider,
            captureMetricKit: captureMetricKit,
            captureUnhandledExceptions: captureUnhandledExceptions
        ))
    }

    public static func globalClient() -> AuralogClient? {
        lock.lock()
        defer { lock.unlock() }
        return client
    }

    public static func debug(_ message: String, metadata: AuralogMetadata? = nil) {
        emit { await $0.debug(message, metadata: metadata) }
    }

    public static func info(_ message: String, metadata: AuralogMetadata? = nil) {
        emit { await $0.info(message, metadata: metadata) }
    }

    public static func warn(_ message: String, metadata: AuralogMetadata? = nil) {
        emit { await $0.warn(message, metadata: metadata) }
    }

    public static func error(_ message: String, metadata: AuralogMetadata? = nil, stackTrace: String? = nil) {
        emit { await $0.error(message, metadata: metadata, stackTrace: stackTrace) }
    }

    public static func fatal(_ message: String, metadata: AuralogMetadata? = nil, stackTrace: String? = nil) {
        emit { await $0.fatal(message, metadata: metadata, stackTrace: stackTrace) }
    }

    public static func capture(_ error: Error, metadata: AuralogMetadata? = nil) {
        emit { await $0.capture(error, metadata: metadata) }
    }

    @discardableResult
    public static func run<T>(
        metadata: AuralogMetadata? = nil,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        do {
            return try await operation()
        } catch {
            await globalClient()?.capture(error, metadata: metadata)
            throw error
        }
    }

    public static func task(
        priority: TaskPriority? = nil,
        metadata: AuralogMetadata? = nil,
        operation: @escaping @Sendable () async throws -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) {
            do {
                try await operation()
            } catch {
                await globalClient()?.capture(error, metadata: metadata)
            }
        }
    }

    public static func flush() async {
        await globalClient()?.flush()
    }

    public static func shutdown() async {
        let active = takeClient()
        AuralogExceptionCapture.uninstall()
        await active?.shutdown()
    }

    private static func takeClient() -> AuralogClient? {
        lock.lock()
        defer { lock.unlock() }
        let active = client
        client = nil
        metricKitCapture = nil
        return active
    }

    private static func emit(_ action: @escaping @Sendable (AuralogClient) async -> Void) {
        guard let active = globalClient() else { return }
        Task {
            await action(active)
        }
    }
}
