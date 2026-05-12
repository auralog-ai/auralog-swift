import XCTest
@testable import Auralog

actor RecordingTransport: AuralogTransport {
    var batches: [[AuralogEntry]] = []
    var singles: [AuralogEntry] = []
    var result: AuralogSendResult = .success

    func sendBatch(_ entries: [AuralogEntry]) async -> AuralogSendResult {
        batches.append(entries)
        return result
    }

    func sendSingle(_ entry: AuralogEntry) async -> AuralogSendResult {
        singles.append(entry)
        return result
    }
}

struct TestClock: AuralogClock {
    func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

final class AuralogTests: XCTestCase {
    func testRejectsInsecureEndpointByDefault() throws {
        let config = AuralogConfig(
            apiKey: "aura_test",
            endpoint: URL(string: "http://localhost:8080")!
        )
        XCTAssertThrowsError(try AuralogClient(config: config, transport: RecordingTransport(), clock: TestClock()))
    }

    func testAllowsInsecureEndpointWhenExplicit() async throws {
        let config = AuralogConfig(
            apiKey: "aura_test",
            endpoint: URL(string: "http://localhost:8080")!,
            allowInsecureEndpoint: true
        )
        let client = try AuralogClient(config: config, transport: RecordingTransport(), clock: TestClock())
        await client.shutdown()
    }

    func testFlushSendsBatchEntries() async throws {
        let transport = RecordingTransport()
        let client = try AuralogClient(
            config: AuralogConfig(apiKey: "aura_test", flushInterval: 60),
            transport: transport,
            clock: TestClock()
        )

        await client.info("hello", metadata: ["screen": "home"])
        await client.flush()

        let batches = await transport.batches
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].count, 1)
        XCTAssertEqual(batches[0][0].message, "hello")
        XCTAssertEqual(batches[0][0].metadata?["screen"], "home")
        await client.shutdown()
    }

    func testPriorityLogsUseSingleEndpoint() async throws {
        let transport = RecordingTransport()
        let client = try AuralogClient(
            config: AuralogConfig(apiKey: "aura_test", flushInterval: 60),
            transport: transport,
            clock: TestClock()
        )

        await client.error("failed")
        await client.flush()

        let singles = await transport.singles
        XCTAssertEqual(singles.count, 1)
        XCTAssertEqual(singles[0].level, .error)
        XCTAssertEqual(singles[0].message, "failed")
        await client.shutdown()
    }

    func testGlobalMetadataMergesWithPerCallMetadataWinning() async throws {
        let transport = RecordingTransport()
        let client = try AuralogClient(
            config: AuralogConfig(
                apiKey: "aura_test",
                flushInterval: 60,
                globalMetadata: ["service": "trashday", "user_id": "global"],
                globalMetadataProvider: { ["tenant": "tokyo"] }
            ),
            transport: transport,
            clock: TestClock()
        )

        await client.info("merge", metadata: ["user_id": "local"])
        await client.flush()

        let metadata = await transport.batches[0][0].metadata
        XCTAssertEqual(metadata?["service"], "trashday")
        XCTAssertEqual(metadata?["tenant"], "tokyo")
        XCTAssertEqual(metadata?["user_id"], "local")
        await client.shutdown()
    }

    func testQueueDropsOldestWhenFull() async throws {
        let transport = RecordingTransport()
        let client = try AuralogClient(
            config: AuralogConfig(apiKey: "aura_test", flushInterval: 60, maxBatchSize: 10, maxQueueSize: 2),
            transport: transport,
            clock: TestClock()
        )

        await client.info("one")
        await client.info("two")
        await client.info("three")
        await client.flush()

        let messages = await transport.batches.flatMap { $0 }.map(\.message)
        XCTAssertEqual(messages, ["two", "three"])
        await client.shutdown()
    }
}
