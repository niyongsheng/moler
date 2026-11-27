import Foundation

// MARK: - Plan Models

/// One purge candidate reported by `mo purge --dry-run`.
struct PurgeEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let category: String
    /// Under a cloud-synced root; `mo purge --yes` skips these unattended.
    var isCloud: Bool = false
}

/// What `mo purge --dry-run` found. Mole ≥ 1.70 prints one line per artifact:
///
/// ```
/// Purge Project Artifacts
/// ✓ [DRY RUN] ~/work_space/AudioScript/dist, 819KB
/// ✓ [DRY RUN] ~/work_space/Business/fucoo/tests/__pycache__, 492KB
/// ======================================================================
/// Dry run complete - no changes made
/// Would free approximately: 1.7MB | Items: 13 | Free: 109.86GB
/// ======================================================================
/// ```
struct PurgePlan: Equatable {
    var entries: [PurgeEntry] = []
    /// Total from Mole's summary line, or the sum of entry sizes when absent.
    var totalBytes: Int64 = 0
    /// Item count from Mole's summary line.
    var itemCount: Int = 0
    /// Warnings printed before the summary (`◎ Skipped …`).
    var warnings: [String] = []
    var freeSpaceBytes: Int64?

    var displayItemCount: Int { itemCount > 0 ? itemCount : entries.count }
    var isEmpty: Bool { entries.isEmpty }

    /// Artifacts under a cloud-synced root. `mo purge --yes` skips these in
    /// unattended mode because removing them can propagate to other devices.
    var cloudCount: Int { entries.filter(\.isCloud).count }
}

/// Final counters parsed from a real `mo purge --yes` run.
struct PurgeRunSummary: Equatable {
    let freedBytes: Int64
    let itemsRemoved: Int
    let incomplete: Bool
}

// MARK: - Parser

enum PurgePlanParser {

    static func parse(_ text: String) -> PurgePlan {
        var plan = PurgePlan()
        var seenPaths: Set<String> = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let entry = parseEntry(line) {
                // The same artifact can be listed once; avoid duplicate IDs.
                guard !seenPaths.contains(entry.path) else { continue }
                seenPaths.insert(entry.path)
                plan.entries.append(entry)
                continue
            }

            if line.hasPrefix("◎") {
                let warning = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !warning.isEmpty { plan.warnings.append(warning) }
                continue
            }

            if let summary = parseSummaryLine(line) {
                plan.totalBytes = summary.freedBytes
                plan.itemCount = summary.items
                plan.freeSpaceBytes = summary.freeSpaceBytes
            }
        }

        plan.entries.sort { $0.size > $1.size }
        if plan.totalBytes == 0 {
            plan.totalBytes = plan.entries.reduce(0) { $0 + $1.size }
        }
        if plan.itemCount == 0 {
            plan.itemCount = plan.entries.count
        }
        return plan
    }

    /// Parse a real `mo purge --yes` run's summary.
    static func parseRunSummary(_ text: String) -> PurgeRunSummary? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let incomplete = text.contains("Purge incomplete")
            || text.contains("Some artifacts were skipped")

        for line in lines.reversed() {
            if line.hasPrefix("Estimated space freed:") || line.hasPrefix("Would free approximately:") {
                let freed = CleanSummaryParser.sizeBytes(in: line) ?? 0
                let items = itemCount(in: line) ?? 0
                return PurgeRunSummary(freedBytes: freed, itemsRemoved: items, incomplete: incomplete)
            }
        }

        if text.contains("No artifacts were removed") {
            return PurgeRunSummary(freedBytes: 0, itemsRemoved: 0, incomplete: incomplete)
        }
        return nil
    }

    // MARK: - Line Parsing

    /// `✓ [DRY RUN] ~/project/dist, 819KB` → entry.
    private static func parseEntry(_ line: String) -> PurgeEntry? {
        guard line.hasPrefix("✓") || line.hasPrefix("✔") else { return nil }

        var rest = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("[DRY RUN]") {
            rest = String(rest.dropFirst("[DRY RUN]".count))
                .trimmingCharacters(in: .whitespaces)
        }

        // The size is appended after the final ", "; artifact paths can
        // themselves contain commas, so split from the right.
        guard let separator = rest.range(of: ", ", options: .backwards) else { return nil }
        var path = String(rest[..<separator.lowerBound]).trimmingCharacters(in: .whitespaces)
        let sizeText = String(rest[separator.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }

        if path.hasSuffix("/") { path.removeLast() }
        guard path.hasPrefix("/") || path.hasPrefix("~") else { return nil }

        let expanded = (path as NSString).expandingTildeInPath
        let name = URL(fileURLWithPath: expanded).lastPathComponent

        return PurgeEntry(
            id: expanded,
            name: name,
            path: expanded,
            size: CleanSummaryParser.sizeBytes(in: sizeText) ?? 0,
            category: "",
            isCloud: isCloudPath(expanded)
        )
    }

    /// `Would free approximately: 1.7MB | Items: 13 | Free: 109.86GB`
    private static func parseSummaryLine(
        _ line: String
    ) -> (freedBytes: Int64, items: Int, freeSpaceBytes: Int64?)? {
        guard line.hasPrefix("Would free approximately:")
            || line.hasPrefix("Estimated space freed:") else { return nil }

        let freed = CleanSummaryParser.sizeBytes(in: line) ?? 0
        let items = itemCount(in: line) ?? 0

        // "Free: 109.86GB" is the disk's free space, not the purge total.
        var freeSpace: Int64?
        if let freeRange = line.range(of: "Free:") {
            freeSpace = CleanSummaryParser.sizeBytes(in: String(line[freeRange.upperBound...]))
        }
        return (freed, items, freeSpace)
    }

    private static let itemsPattern = try! NSRegularExpression(
        pattern: #"Items:\s*([0-9]+)"#,
        options: .caseInsensitive
    )

    private static func itemCount(in line: String) -> Int? {
        let ns = line as NSString
        guard let match = itemsPattern.firstMatch(
            in: line, range: NSRange(location: 0, length: ns.length)
        ) else { return nil }
        return Int(ns.substring(with: match.range(at: 1)))
    }

    private static func isCloudPath(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = [
            "\(home)/Library/CloudStorage",
            "\(home)/Library/Mobile Documents",
        ]
        return roots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}
