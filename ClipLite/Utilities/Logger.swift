import Foundation

enum Logger {
    static func debug(_ message: String) {
        log(level: "DEBUG", message)
    }

    static func info(_ message: String) {
        log(level: "INFO", message)
    }

    static func warning(_ message: String) {
        log(level: "WARN", message)
    }

    static func error(_ message: String) {
        log(level: "ERROR", message)
    }

    private static func log(level: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level)] \(message)")
    }
}
