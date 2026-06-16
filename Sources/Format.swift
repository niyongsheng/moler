import Foundation

/// Pure formatting functions — numbers, bytes, dates.
/// No side effects, no state. Unit-testable.
enum Format {

    // MARK: - Bytes

    /// Format bytes as human-readable string (1024-based, matching mo's convention).
    /// e.g. 1_073_741_824 → "1.0 GB"
    static func bytes(_ value: Int64) -> String {
        formatBytes(value)
    }

    /// Format a UInt64 byte count.
    static func bytes(_ value: UInt64) -> String {
        formatBytes(Int64(value))
    }

    // MARK: - Count

    /// Format a count with locale-aware separators. e.g. 1234567 → "1,234,567"
    static func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Free Functions

/// Format a byte count as human-readable (1024-based).
/// Pure function, usable from any component.
func formatBytes(_ value: Int64) -> String {
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
