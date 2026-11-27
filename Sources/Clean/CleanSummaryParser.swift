import Foundation

/// Extracts the authoritative totals from `mo clean` output.
///
/// Mole has used two summary formats:
///
/// - ≤ 1.66, real run: `Tracked cleanup: 6.74GB | Items cleaned: 768`
/// - ≤ 1.66, dry run:  `Potential space: 6.74GB | Items: 768 | Categories: 7`
/// - ≥ 1.67, real run: `Removed: 6.74GB · 768 items`
/// - ≥ 1.67, dry run:  `Potential space: 6.74GB · 768 items`
///
/// The per-item lines above the summary also contain sizes, so summing every
/// size in the log over-counts by a large factor. Trust only the summary.
enum CleanSummaryParser {

    struct Summary: Equatable {
        let freedBytes: Int64
        let itemsCleaned: Int?
        /// True when Mole could not size every item — either the summary says
        /// "Partially measured" or the total is a lower bound ("6.74GB+").
        var isPartial: Bool = false
    }

    /// Summary labels, newest first. `Removed:` replaced `Tracked cleanup:`
    /// in Mole 1.67; keep both so an older CLI still parses.
    private static let labels = ["Removed:", "Tracked cleanup:", "Potential space:"]

    /// Parse the last summary line in the output, if one was printed.
    static func parse(_ text: String) -> Summary? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard labels.contains(where: { line.contains($0) }) else { continue }

            if let size = firstSize(in: line) {
                return Summary(
                    freedBytes: size.bytes,
                    itemsCleaned: itemCount(in: line),
                    isPartial: size.isLowerBound
                )
            }

            // Mole 1.74 prints `Removed: Partially measured · N items` when
            // every size check timed out. Bytes are unknown, but the run did
            // remove items — report a partial result instead of nothing.
            if line.localizedCaseInsensitiveContains("partially measured") {
                return Summary(
                    freedBytes: 0,
                    itemsCleaned: itemCount(in: line),
                    isPartial: true
                )
            }
        }
        return nil
    }

    // MARK: - Shared Field Helpers

    /// First human-readable size in a line, in bytes.
    static func sizeBytes(in line: String) -> Int64? {
        firstSize(in: line)?.bytes
    }

    /// Item count from either `Items cleaned: 42` / `Items: 7` or
    /// `42 items` / `1 item`.
    static func itemCount(in line: String) -> Int? {
        firstItemCount(in: line)
    }

    // MARK: - Field extraction

    private static let sizePattern = try! NSRegularExpression(
        pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB|TB|PB)"#,
        options: .caseInsensitive
    )

    /// Matches both `Items cleaned: 42` / `Items: 7` and `42 items` / `1 item`.
    private static let itemsPattern = try! NSRegularExpression(
        pattern: #"(?:Items(?: cleaned)?:\s*([0-9]+)|([0-9]+)\s+items?\b)"#,
        options: .caseInsensitive
    )

    private static func firstSize(in line: String) -> (bytes: Int64, isLowerBound: Bool)? {
        let ns = line as NSString
        guard let match = sizePattern.firstMatch(
            in: line, range: NSRange(location: 0, length: ns.length)
        ), let value = Double(ns.substring(with: match.range(at: 1))) else {
            return nil
        }

        let multiplier: Double
        switch ns.substring(with: match.range(at: 2)).uppercased() {
        case "PB": multiplier = 1_125_899_906_842_624
        case "TB": multiplier = 1_099_511_627_776
        case "GB": multiplier = 1_073_741_824
        case "MB": multiplier = 1_048_576
        case "KB": multiplier = 1_024
        default:   multiplier = 1
        }

        // Mole appends "+" when some items could not be sized ("1.5GB+").
        let end = match.range.location + match.range.length
        let isLowerBound = end < ns.length && ns.substring(with: NSRange(location: end, length: 1)) == "+"

        return (Int64(value * multiplier), isLowerBound)
    }

    private static func firstItemCount(in line: String) -> Int? {
        let ns = line as NSString
        guard let match = itemsPattern.firstMatch(
            in: line, range: NSRange(location: 0, length: ns.length)
        ) else { return nil }

        for group in 1...2 {
            let range = match.range(at: group)
            if range.location != NSNotFound {
                return Int(ns.substring(with: range))
            }
        }
        return nil
    }
}
