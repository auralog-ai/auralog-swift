# auralogs-swift (Beta)

Swift SDK for [Auralogs](https://auralog.ai) — agentic logging and application awareness.

Auralogs uses Claude as an on-call engineer: it monitors your logs and errors, alerts you when something's wrong, and opens fix PRs automatically.

[![CI](https://github.com/auralogs-ai/auralogs-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/auralogs-ai/auralogs-swift/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/auralogs-ai/auralogs-swift?include_prereleases&label=release)](https://github.com/auralogs-ai/auralogs-swift/releases)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

## Install

Add this package in Xcode:

```text
https://github.com/auralogs-ai/auralogs-swift
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/auralogs-ai/auralogs-swift.git", from: "0.1.0-beta.1")
```

The beta targets Swift 5.9+ and Apple platforms supported by Swift Package Manager: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, and visionOS 1+.

## Quick Start

```swift
import Auralogs

try Auralogs.initialize(
    apiKey: "aura_your_key",
    environment: "production",
    captureMetricKit: true,
    captureUnhandledExceptions: true
)

Auralogs.info("user signed in", metadata: ["user_id": "123"])
Auralogs.error("payment failed", metadata: ["order_id": "abc"])
```

## SwiftUI Setup

```swift
import Auralogs
import SwiftUI

@main
struct MyApp: App {
    init() {
        try? Auralogs.initialize(
            apiKey: "aura_your_key",
            environment: "production",
            globalMetadata: [
                "app": "ios-app",
                "app_version": .string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
            ],
            captureMetricKit: true,
            captureUnhandledExceptions: true
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

## Seamless Error Capture

Swift does not expose a global hook for every thrown `Error`. Use `Auralogs.run` or `Auralogs.task` at async boundaries where you would otherwise write a `do/catch`.

```swift
.task {
    await Auralogs.run(metadata: ["screen": "home"]) {
        try await viewModel.refresh()
    }
}

Button("Sync") {
    Auralogs.task(metadata: ["action": "manual_sync"]) {
        try await syncNow()
    }
}
```

## SwiftLog Integration

Add the `AuralogsSwiftLog` product and route existing `swift-log` logs to Auralogs:

```swift
import AuralogsSwiftLog

AuralogsSwiftLog.install()
```

SwiftLog only allows one global logging backend. If your app already bootstraps `LoggingSystem`, install Auralogs from the same logging setup or use a multiplexing handler.

## Configuration

| Option | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String` | _required_ | Auralogs project API key |
| `environment` | `String` | `"production"` | e.g. `"production"`, `"staging"`, `"dev"` |
| `endpoint` | `URL` | `https://ingest.auralog.ai` | Ingest endpoint override. Must be HTTPS unless `allowInsecureEndpoint` is set |
| `allowInsecureEndpoint` | `Bool` | `false` | Permit non-HTTPS (`http://`) endpoints. Only enable for local development or trusted internal HTTP-only ingest |
| `flushInterval` | `TimeInterval` | `5` | Time between batched flushes |
| `maxBatchSize` | `Int` | `50` | Maximum logs per batch request |
| `maxQueueSize` | `Int` | `1000` | Maximum in-memory non-error logs retained before dropping oldest entries |
| `maxRetryAttempts` | `Int` | `5` | Drop a failed log after this many attempts |
| `retryInitialDelay` | `TimeInterval` | `1` | First retry delay |
| `retryMaxDelay` | `TimeInterval` | `30` | Maximum retry delay |
| `httpTimeout` | `TimeInterval` | `30` | URLSession request/resource timeout |
| `shutdownTimeout` | `TimeInterval` | `2` | Reserved default shutdown budget |
| `traceId` | `String` | _auto-generated_ | Custom trace ID for distributed tracing |
| `globalMetadata` | `AuralogsMetadata` | _none_ | Static metadata merged into every entry |
| `globalMetadataProvider` | `() -> AuralogsMetadata?` | _none_ | Synchronous metadata supplier invoked per entry |
| `captureMetricKit` | `Bool` | `false` | Forward MetricKit metrics and diagnostics where available. In this beta, forwarding is implemented for iOS and no-ops on other platforms |
| `captureUnhandledExceptions` | `Bool` | `false` | Capture uncaught Objective-C exceptions |

## Global Metadata

Use `globalMetadata` or `globalMetadataProvider` to attach session-scoped fields to every log:

```swift
try Auralogs.initialize(
    apiKey: "aura_your_key",
    globalMetadata: ["service": "ios-app"],
    globalMetadataProvider: {
        ["user_id": currentUserId.map(AuralogsValue.string) ?? .null]
    }
)
```

The supplier runs on every emit, so keep it cheap and side-effect-free. Per-call metadata wins on key collisions.

## Transport Semantics

- Non-error logs are queued and flushed every `flushInterval`.
- Calling `Auralogs.flush()` drains all pending single and batch queues.
- Errors and fatals are prioritized onto `/v1/logs/single`.
- 4xx ingest responses and redirects are treated as permanent failures and are not retried.
- 5xx ingest responses and network failures are retried up to `maxRetryAttempts`.
- The default transport uses `URLSession` and sends the project API key in the JSON body as `projectApiKey`, matching the other Auralogs SDKs.

## Crash Reporting Notes

This SDK intentionally does not claim to be a full Crashlytics or Sentry replacement in v1.

- MetricKit is the recommended Apple-native path for crash, hang, CPU, disk-write, and performance diagnostics.
- `NSSetUncaughtExceptionHandler` captures some Objective-C exceptions, not all Swift failures.
- Swift thrown errors are values and cannot be globally intercepted.
- Signal-level crash reporting, dSYM upload, symbolication, and grouping are out of scope for v1.

## App Store Privacy

The package includes `PrivacyInfo.xcprivacy`. Auralogs declares diagnostic data collection for App Functionality and does not declare tracking.

Apps must still disclose the data they choose to attach through logs or metadata. If you include user IDs, device IDs, product interaction events, location, contact info, or other personal data, update your App Store privacy answers accordingly.

## Development

```bash
swift test
swift build --package-path Examples/SwiftUIExample
```

The release workflow should tag beta releases as `0.1.0-beta.N`.

## Documentation

Full docs at [docs.auralog.ai](https://docs.auralog.ai).

## Security

Found a vulnerability? See [SECURITY.md](./SECURITY.md).

## License

[MIT](./LICENSE) © James Thomas
