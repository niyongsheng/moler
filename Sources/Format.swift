import Foundation

/// Pure formatting functions — numbers, bytes, dates.
/// No side effects, no state. Unit-testable.
enum Format {

    // MARK: - Bytes

    /// Format bytes as human-readable string (1024-based, matching mo's convention).
    /// e.g. 1_073_741_824 → "1.0 GB"
    static func bytes(_ value: Int64) -> String {
        let absValue = abs(value)
        guard absValue >= 1024 else { return "\(value) B" }

        let units = ["KB", "MB", "GB", "TB"]
        var v = Double(absValue)
        var unitIndex = -1

        while v >= 1024 && unitIndex < units.count - 1 {
            v /= 1024
            unitIndex += 1
        }

        let sign = value < 0 ? "-" : ""
        if unitIndex >= 0 {
            return String(format: "\(sign)%.1f %@", v, units[unitIndex])
        }
        return "\(value) B"
    }

    /// Format a UInt64 byte count.
    static func bytes(_ value: UInt64) -> String {
        bytes(Int64(value))
    }

    // MARK: - Count

    /// Format a count with locale-aware separators. e.g. 1234567 → "1,234,567"
    static func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Relative Date

    /// Format a date relative to now: "just now", "3m ago", "2h ago", "5d ago".
    static func relativeDate(_ date: Date?) -> String {
        guard let date else { return L10n.relativeNever }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return L10n.relativeJustNow }
        let m = Int(interval / 60)
        if m < 60 { return String(format: L10n.relativeMinutesAgo, m) }
        let h = m / 60
        if h < 24 { return String(format: L10n.relativeHoursAgo, h) }
        let d = h / 24
        return String(format: L10n.relativeDaysAgo, d)
    }

    // MARK: - Uptime

    /// Format seconds into compact duration: "2d 3h", "45m", "12s".
    static func uptime(_ seconds: Int) -> String {
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        if d > 0 { return "\(d)d \(h)h" }
        let m = seconds / 60
        return m > 0 ? "\(m)m" : "\(seconds)s"
    }

    // MARK: - Duration

    /// Format seconds as a compact minutes/seconds string: "1m 5s", "12s".
    static func duration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    // MARK: - Path

    /// Shorten a file path by replacing home with `~` and truncating the prefix.
    static func abbreviatePath(_ path: String, maxLen: Int) -> String {
        guard path.count > maxLen else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let abbrev = path.replacingOccurrences(of: home, with: "~")
        guard abbrev.count > maxLen else { return abbrev }
        return "..." + abbrev.suffix(maxLen - 3)
    }
}

// MARK: - Byte Unit Constants

/// Byte unit multiplier pairs (1024-based), shared between parsers.
struct ByteUnit {
    let suffix: String
    let multiplier: Int64

    static let table: [ByteUnit] = [
        ByteUnit(suffix: "TB", multiplier: 1_099_511_627_776),
        ByteUnit(suffix: "GB", multiplier: 1_073_741_824),
        ByteUnit(suffix: "MB", multiplier: 1_048_576),
        ByteUnit(suffix: "KB", multiplier: 1_024),
        ByteUnit(suffix: "B",  multiplier: 1),
    ]
}

/// Parse a human-readable size string like "1.2GB", "366.8MB", "500KB" → bytes.
/// Returns 0 if the text cannot be parsed.
func parseSizeBytes(_ text: String) -> Int64 {
    let t = text.trimmingCharacters(in: .whitespaces).uppercased()
    for unit in ByteUnit.table where t.hasSuffix(unit.suffix) {
        let number = t.dropLast(unit.suffix.count).trimmingCharacters(in: .whitespaces)
        guard let value = Double(number) else { return 0 }
        return Int64(value * Double(unit.multiplier))
    }
    return 0
}

// MARK: - Version

/// Trim whitespace and drop a leading "v" from a version string.
func normalizedVersion(_ version: String) -> String {
    var v = version.trimmingCharacters(in: .whitespaces)
    if v.hasPrefix("v") || v.hasPrefix("V") { v.removeFirst() }
    return v
}
