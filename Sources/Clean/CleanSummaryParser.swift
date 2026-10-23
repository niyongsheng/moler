import Foundation

/// Extracts the authoritative totals from `mo clean` output.
///
/// Every run ends with a summary line:
/// - real run: `Tracked cleanup: 6.74GB | Items cleaned: 768`
/// - dry run:  `Potential space: 6.74GB | Items: 768 | Categories: 7`
///
/// The per-item lines above the summary also contain sizes, so summing every
/// size in the log over-counts by a large factor. Trust only the summary.
enum CleanSummaryParser {

    struct Summary: Equatable {
        let freedBytes: Int64
        let itemsCleaned: Int?
    }

    private static let labels = ["Tracked cleanup:", "Potential space:"]

    /// Parse the last summary line in the output, if one was printed.
    static func parse(_ text: String) -> Summary? {
        let lines = text.components(separatedBy: .newlines)
        for label in labels {
            for line in lines.reversed() where line.contains(label) {
                guard let bytes = firstSize(in: line) else { continue }
                return Summary(freedBytes: bytes, itemsCleaned: firstItemCount(in: line))
            }
        }
        return nil
    }

    // MARK: - Field extraction

    private static let sizePattern = try! NSRegularExpression(
        pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB|TB|PB)"#,
        options: .caseInsensitive
    )

    private static let itemsPattern = try! NSRegularExpression(
        pattern: #"Items(?: cleaned)?:\s*([0-9]+)"#,
        options: .caseInsensitive
    )

    private static func firstSize(in line: String) -> Int64? {
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
        return Int64(value * multiplier)
    }

    private static func firstItemCount(in line: String) -> Int? {
        let ns = line as NSString
        guard let match = itemsPattern.firstMatch(
            in: line, range: NSRange(location: 0, length: ns.length)
        ) else { return nil }
        return Int(ns.substring(with: match.range(at: 1)))
    }
}
