import Foundation

struct AuralogsQueuedEntry: Sendable {
    var entry: AuralogsEntry
    var attempts: Int
}

public actor AuralogsClient {
    private var config: AuralogsConfig
    private let transport: AuralogsTransport
    private var batchQueue: [AuralogsQueuedEntry] = []
    private var singleQueue: [AuralogsQueuedEntry] = []
    private var stopped = false
    private var backgroundTask: Task<Void, Never>?
    private let clock: any AuralogsClock

    public init(config: AuralogsConfig, transport: AuralogsTransport? = nil) throws {
        try AuralogsHTTPTransport.validate(config)
        self.config = config
        if let transport {
            self.transport = transport
        } else {
            self.transport = try AuralogsHTTPTransport(config: config)
        }
        self.clock = DefaultAuralogsClock()
        self.backgroundTask = nil
    }

    init(config: AuralogsConfig, transport: AuralogsTransport, clock: any AuralogsClock) throws {
        try AuralogsHTTPTransport.validate(config)
        self.config = config
        self.transport = transport
        self.clock = clock
        self.backgroundTask = nil
    }

    public func log(_ level: AuralogsLevel, _ message: String, metadata: AuralogsMetadata? = nil, stackTrace: String? = nil) async {
        guard !stopped else { return }
        startBackgroundFlushLoopIfNeeded()
        let entry = buildEntry(level, message, metadata: metadata, stackTrace: stackTrace)
        if level.isPriority {
            singleQueue.append(AuralogsQueuedEntry(entry: entry, attempts: 0))
            Task { await flushSingles() }
        } else {
            batchQueue.append(AuralogsQueuedEntry(entry: entry, attempts: 0))
            trimBatchQueue()
        }
    }

    public func debug(_ message: String, metadata: AuralogsMetadata? = nil) async {
        await log(.debug, message, metadata: metadata)
    }

    public func info(_ message: String, metadata: AuralogsMetadata? = nil) async {
        await log(.info, message, metadata: metadata)
    }

    public func warn(_ message: String, metadata: AuralogsMetadata? = nil) async {
        await log(.warn, message, metadata: metadata)
    }

    public func error(_ message: String, metadata: AuralogsMetadata? = nil, stackTrace: String? = nil) async {
        await log(.error, message, metadata: metadata, stackTrace: stackTrace)
    }

    public func fatal(_ message: String, metadata: AuralogsMetadata? = nil, stackTrace: String? = nil) async {
        await log(.fatal, message, metadata: metadata, stackTrace: stackTrace)
    }

    public func capture(_ error: Error, metadata: AuralogsMetadata? = nil) async {
        var merged = metadata ?? [:]
        merged["errorDescription"] = .string(String(describing: error))
        await self.error("Swift error captured", metadata: merged, stackTrace: Thread.callStackSymbols.joined(separator: "\n"))
    }

    public func setGlobalMetadata(_ metadata: AuralogsMetadata) {
        config.globalMetadata = metadata
    }

    public func setGlobalMetadataProvider(_ provider: (@Sendable () -> AuralogsMetadata?)?) {
        config.globalMetadataProvider = provider
    }

    public func flush() async {
        await flushSingles()
        while !batchQueue.isEmpty {
            await flushBatch()
        }
    }

    public func shutdown() async {
        stopped = true
        backgroundTask?.cancel()
        backgroundTask = nil
        await flush()
    }

    func pendingCounts() -> (batch: Int, single: Int) {
        (batchQueue.count, singleQueue.count)
    }

    private func buildEntry(_ level: AuralogsLevel, _ message: String, metadata: AuralogsMetadata?, stackTrace: String?) -> AuralogsEntry {
        var merged = config.globalMetadata
        if let supplied = config.globalMetadataProvider?() {
            for (key, value) in supplied {
                merged[key] = value
            }
        }
        if let metadata {
            for (key, value) in metadata {
                merged[key] = value
            }
        }

        return AuralogsEntry(
            level: level,
            message: message,
            environment: config.environment,
            timestamp: AuralogsTimestamp.now(),
            metadata: merged.isEmpty ? nil : merged,
            stackTrace: stackTrace,
            traceId: config.traceId
        )
    }

    private func trimBatchQueue() {
        guard batchQueue.count > config.maxQueueSize else { return }
        batchQueue.removeFirst(batchQueue.count - config.maxQueueSize)
    }

    private func flushBatch() async {
        guard !batchQueue.isEmpty else { return }
        let batchSize = min(config.maxBatchSize, batchQueue.count)
        let entries = Array(batchQueue.prefix(batchSize))
        batchQueue.removeFirst(batchSize)
        let result = await transport.sendBatch(entries.map(\.entry))
        await handle(result: result, entries: entries, priority: false)
    }

    private func flushSingles() async {
        while !singleQueue.isEmpty {
            let queued = singleQueue.removeFirst()
            let result = await transport.sendSingle(queued.entry)
            await handle(result: result, entries: [queued], priority: true)
        }
    }

    private func handle(result: AuralogsSendResult, entries: [AuralogsQueuedEntry], priority: Bool) async {
        switch result {
        case .success, .permanentFailure:
            return
        case .retryableFailure:
            let retryable = entries.compactMap { queued -> AuralogsQueuedEntry? in
                let attempts = queued.attempts + 1
                guard attempts < config.maxRetryAttempts else { return nil }
                return AuralogsQueuedEntry(entry: queued.entry, attempts: attempts)
            }
            if priority {
                singleQueue.insert(contentsOf: retryable, at: 0)
            } else {
                batchQueue.insert(contentsOf: retryable, at: 0)
                trimBatchQueue()
            }
            if !retryable.isEmpty {
                let delay = min(config.retryMaxDelay, config.retryInitialDelay * pow(2, Double(retryable[0].attempts - 1)))
                await clock.sleep(seconds: delay)
            }
        }
    }

    private func runBackgroundFlushLoop() async {
        while !Task.isCancelled {
            await clock.sleep(seconds: config.flushInterval)
            if Task.isCancelled { return }
            await flushBatch()
        }
    }

    private func startBackgroundFlushLoopIfNeeded() {
        guard backgroundTask == nil else { return }
        backgroundTask = Task { [weak self] in
            await self?.runBackgroundFlushLoop()
        }
    }
}

protocol AuralogsClock: Sendable {
    func sleep(seconds: TimeInterval) async
}

struct DefaultAuralogsClock: AuralogsClock {
    func sleep(seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

enum AuralogsTimestamp {
    static func now() -> String {
        formatter.string(from: Date())
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
