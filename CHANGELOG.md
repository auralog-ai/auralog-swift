# Changelog

## v1.0.0 - 2026-05-15

### Changed

- **BREAKING: Renamed Swift package** `auralog-swift` → `auralogs-swift`. Update Package.swift dependency:
  ```diff
  - .package(url: "https://github.com/auralogs-ai/auralog-swift.git", from: "0.2.0"),
  + .package(url: "https://github.com/auralogs-ai/auralogs-swift.git", from: "1.0.0"),
  ```
- **BREAKING: Renamed library targets** `Auralog` → `Auralogs`, `AuralogSwiftLog` → `AuralogsSwiftLog`.
- **BREAKING: Renamed `Auralog` class** → `Auralogs`. Update call sites:
  ```diff
  - import Auralog
  - Auralog.initialize(config: ...)
  + import Auralogs
  + Auralogs.initialize(config: ...)
  ```
- Default ingest endpoint updated `https://ingest.auralog.ai` → `https://ingest.auralogs.ai`.
- Repository moved to https://github.com/auralogs-ai/auralogs-swift.

## 0.1.0-beta.1

- Initial Swift Package for Auralogs.
- Adds structured logging, async flush/shutdown, MetricKit forwarding, Objective-C exception capture, SwiftLog integration, and an Apple privacy manifest.
- Adds CI, release automation, and a SwiftUI example app.
