import Auralog
import AuralogSwiftLog
import Logging
import SwiftUI

@main
struct AuralogSwiftUIExampleApp: App {
    private let logger = Logger(label: "example.app")

    init() {
        if let apiKey = ProcessInfo.processInfo.environment["AURALOG_API_KEY"], !apiKey.isEmpty {
            try? Auralog.initialize(
                apiKey: apiKey,
                environment: ProcessInfo.processInfo.environment["AURALOG_ENVIRONMENT"] ?? "development",
                globalMetadata: [
                    "example": true,
                    "app": "AuralogSwiftUIExample"
                ],
                captureMetricKit: true,
                captureUnhandledExceptions: true
            )
            AuralogSwiftLog.install()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(logger: logger)
        }
    }
}

struct ContentView: View {
    let logger: Logger
    @State private var status = "Ready"

    var body: some View {
        VStack(spacing: 16) {
            Text("Auralog SwiftUI Example")
                .font(.title)
            Text(status)
                .foregroundStyle(.secondary)
            Button("Send log") {
                Auralog.info("example button tapped", metadata: ["screen": "home"])
                logger.info("swift-log routed through Auralog", metadata: ["button": "send_log"])
                status = "Sent log"
            }
            Button("Run failing task") {
                _ = Auralog.task(metadata: ["screen": "home", "action": "failing_task"]) {
                    struct ExampleError: Error {}
                    throw ExampleError()
                }
                status = "Captured task error"
            }
        }
        .padding()
    }
}
