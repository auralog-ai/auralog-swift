import Foundation

enum AuralogExceptionCapture {
    private static let lock = NSLock()
    private static var client: AuralogClient?
    private static var previousHandler: NSUncaughtExceptionHandler?

    static func install(client: AuralogClient) {
        lock.lock()
        self.client = client
        previousHandler = NSGetUncaughtExceptionHandler()
        lock.unlock()

        NSSetUncaughtExceptionHandler { exception in
            AuralogExceptionCapture.handle(exception)
        }
    }

    static func uninstall() {
        lock.lock()
        client = nil
        previousHandler = nil
        lock.unlock()
        NSSetUncaughtExceptionHandler(nil)
    }

    private static func handle(_ exception: NSException) {
        lock.lock()
        let active = client
        let previous = previousHandler
        lock.unlock()

        let metadata: AuralogMetadata = [
            "exceptionName": .string(exception.name.rawValue),
            "exceptionReason": exception.reason.map(AuralogValue.string) ?? .null,
            "callStackSymbols": .array(exception.callStackSymbols.map(AuralogValue.string))
        ]
        Task {
            await active?.fatal("Uncaught Objective-C exception", metadata: metadata, stackTrace: exception.callStackSymbols.joined(separator: "\n"))
            await active?.flush()
        }
        previous?(exception)
    }
}
