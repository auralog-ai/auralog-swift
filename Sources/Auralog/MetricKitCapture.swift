import Foundation

#if canImport(MetricKit) && os(iOS)
import MetricKit

final class AuralogMetricKitCapture: NSObject, MXMetricManagerSubscriber {
    private let client: AuralogClient

    private init(client: AuralogClient) {
        self.client = client
        super.init()
    }

    static func install(client: AuralogClient) -> AuralogMetricKitCapture? {
        let capture = AuralogMetricKitCapture(client: client)
        MXMetricManager.shared.add(capture)
        return capture
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            Task {
                await client.info(
                    "MetricKit metric payload",
                    metadata: [
                        "source": "metrickit",
                        "payloadType": "metric",
                        "payload": .string(Self.payloadString(payload))
                    ]
                )
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            Task {
                await client.error(
                    "MetricKit diagnostic payload",
                    metadata: [
                        "source": "metrickit",
                        "payloadType": "diagnostic",
                        "payload": .string(Self.payloadString(payload))
                    ]
                )
            }
        }
    }

    private static func payloadString(_ payload: AnyObject) -> String {
        if let metric = payload as? MXMetricPayload {
            return String(data: metric.jsonRepresentation(), encoding: .utf8) ?? "{}"
        }
        if #available(iOS 14.0, *),
           let diagnostic = payload as? MXDiagnosticPayload {
            return String(data: diagnostic.jsonRepresentation(), encoding: .utf8) ?? "{}"
        }
        return String(describing: payload)
    }
}
#else
final class AuralogMetricKitCapture {
    static func install(client: AuralogClient) -> AuralogMetricKitCapture? {
        nil
    }
}
#endif
