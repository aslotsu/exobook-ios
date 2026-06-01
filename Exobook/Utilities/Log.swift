import Foundation
import os

/// Category-scoped loggers. Use these instead of `print(...)` so that:
/// - production builds redact private payloads automatically,
/// - logs are filterable in Console.app by subsystem/category,
/// - error paths are surfaced to crash reporting if/when wired up.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "ca.linkio.Linkio"

    static let auth      = Logger(subsystem: subsystem, category: "auth")
    static let api       = Logger(subsystem: subsystem, category: "api")
    static let realtime  = Logger(subsystem: subsystem, category: "realtime")
    static let chat      = Logger(subsystem: subsystem, category: "chat")
    static let feed      = Logger(subsystem: subsystem, category: "feed")
    static let cache     = Logger(subsystem: subsystem, category: "cache")
    static let push      = Logger(subsystem: subsystem, category: "push")
    static let nav       = Logger(subsystem: subsystem, category: "nav")
}
