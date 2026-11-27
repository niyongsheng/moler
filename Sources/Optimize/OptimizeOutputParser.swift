import Foundation

// MARK: - Output Parser

/// Streaming line parser for `mo optimize` / `mo optimize --dry-run` output.
///
/// The CLI output (with `NO_COLOR=1`) has this structure:
///
/// ```
/// Optimize
/// → DRY RUN MODE, No files will be modified
/// ⚙ System info line
///
/// PERFORMANCE DIAGNOSIS
///   ◎ Likely bottleneck: ...
///   ☞ Desktop composition is busy
///
/// ➤ DNS & Spotlight Check
///   → DNS cache flushed
///   → Spotlight index verified
///
/// ➤ Finder Cache Refresh
///   ○ QuickLook thumbnails refreshed
///   ✓ Icon services cache rebuilt
///   ...
///
/// ======================================================================
/// Dry Run Complete, No Changes Made
/// Would apply 22 optimizations
/// ======================================================================
/// ```
///
/// Task status symbols:
/// - `○` pending / would-apply (dry run in Mole ≥ 1.67)
/// - `→` in progress (older Mole releases)
/// - `✓` completed
final class OptimizeOutputParser {
    enum Phase {
        case header      // first few lines before PERFORMANCE DIAGNOSIS
        case diagnosis   // inside PERFORMANCE DIAGNOSIS
        case categories  // main body of ➤ category sections
        case footer      // after the === separator
    }

    private var phase: Phase = .header
    private(set) var currentCategory: String?
    private(set) var categories: [OptimizeCategory] = []
    private(set) var diagnosisItems: [OptimizeTask] = []
    private(set) var totalOptimizations: Int = 0
    private(set) var outcomeCounts = OptimizeOutcomeCounts()

    /// Ingest a single line from the output stream.
    /// Returns a `ParsedEvent` describing what was found.
    func ingest(line: String) -> ParsedEvent {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines
        guard !trimmed.isEmpty else { return .unknown("") }

        // === separator → footer
        if trimmed.hasPrefix("==="), trimmed.count > 10 {
            phase = .footer
            return .unknown(trimmed)
        }

        // PERFORMANCE DIAGNOSIS header (Mole prints "Performance diagnosis")
        if trimmed.caseInsensitiveCompare("PERFORMANCE DIAGNOSIS") == .orderedSame {
            phase = .diagnosis
            return .unknown(trimmed)
        }

        // ➤ category header
        if trimmed.first == "➤" {
            let name = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return .unknown(trimmed) }
            phase = .categories
            currentCategory = name
            categories.append(OptimizeCategory(name: name))
            return .categoryStarted(name: name)
        }

        // Diagnosis items within PERFORMANCE DIAGNOSIS. Mole has used every
        // marker here (`◎` warning, `☞` hint, `⊙` review note) and newer
        // releases also print plain `✓` lines such as
        // "No sustained high-CPU bottleneck detected". Treat every non-empty
        // line in this section as diagnosis output so nothing is dropped.
        if phase == .diagnosis {
            let desc = Self.strippingMarker(from: trimmed)
            guard !desc.isEmpty else { return .unknown(trimmed) }
            let task = OptimizeTask(
                description: desc,
                categoryName: "PERFORMANCE DIAGNOSIS",
                isCompleted: false
            )
            diagnosisItems.append(task)
            return .diagnosisItem(description: desc)
        }

        // Task items within categories. Mole 1.67+ prints `○` for every task
        // during a dry run and only `✓` once a real run applies it. `◎` is an
        // advisory row (skipped task, app must be closed, admin access
        // missing) and must stay visible: Mole 1.73+ keeps running after a
        // failed task, so these rows explain what was left undone.
        if phase == .categories, let cat = currentCategory {
            if trimmed.hasPrefix("◎") {
                let desc = Self.strippingMarker(from: trimmed)
                let task = OptimizeTask(
                    description: desc,
                    categoryName: cat,
                    isCompleted: false,
                    isWarning: true
                )
                if !categories.isEmpty {
                    categories[categories.count - 1].tasks.append(task)
                }
                return .warningItem(description: desc)
            }
            if trimmed.hasPrefix("→") || trimmed.hasPrefix("✓") || trimmed.hasPrefix("○") {
                let completed = trimmed.hasPrefix("✓")
                let desc = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let task = OptimizeTask(
                    description: desc,
                    categoryName: cat,
                    isCompleted: completed
                )
                // Add to the last category
                if !categories.isEmpty {
                    categories[categories.count - 1].tasks.append(task)
                }
                return .taskItem(description: desc, completed: completed)
            }
        }

        // Footer parsing
        if phase == .footer {
            // "Would apply 22 optimizations"
            if trimmed.contains("Would apply") || trimmed.contains("optimizations") {
                let numbers = trimmed.components(separatedBy: .decimalDigits.inverted)
                    .compactMap(Int.init)
                if let count = numbers.first {
                    totalOptimizations = count
                    return .totalOptimizations(count)
                }
            }
            // Outcome breakdown, e.g. "14 unchanged | 2 skipped | 1 unavailable"
            if let counts = Self.parseOutcomeCounts(trimmed) {
                outcomeCounts = counts
                return .outcomes(counts)
            }
            // "Dry Run Complete"
            if trimmed.contains("Dry Run Complete") || trimmed.contains("No Changes Made") {
                return .runComplete
            }
            // Real run completion — anything with "Applied" or "Complete" or reached end
            if trimmed.contains("Applied") || trimmed.contains("Complete") {
                return .runComplete
            }
        }

        return .unknown(trimmed)
    }

    /// Reset the parser for a new run.
    func reset() {
        phase = .header
        currentCategory = nil
        categories.removeAll()
        diagnosisItems.removeAll()
        totalOptimizations = 0
        outcomeCounts = OptimizeOutcomeCounts()
    }

    // MARK: - Line Helpers

    /// `◎ Warning text` → `Warning text`; leaves unmarked lines untouched.
    private static func strippingMarker(from line: String) -> String {
        guard let first = line.first, "◎☞⊙✓●".contains(first) else { return line }
        return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static let outcomePattern = try! NSRegularExpression(
        pattern: #"([0-9]+)\s+(unchanged|skipped|unavailable|attention|failed|applied)\b"#,
        options: .caseInsensitive
    )

    /// Parse a footer line such as `14 unchanged | 2 skipped | 1 unavailable`.
    private static func parseOutcomeCounts(_ line: String) -> OptimizeOutcomeCounts? {
        let ns = line as NSString
        let matches = outcomePattern.matches(
            in: line,
            range: NSRange(location: 0, length: ns.length)
        )
        guard !matches.isEmpty else { return nil }

        var counts = OptimizeOutcomeCounts()
        for match in matches {
            guard let value = Int(ns.substring(with: match.range(at: 1))) else { continue }
            switch ns.substring(with: match.range(at: 2)).lowercased() {
            case "applied":     counts.applied = value
            case "unchanged":   counts.unchanged = value
            case "skipped":     counts.skipped = value
            case "unavailable": counts.unavailable = value
            case "attention":   counts.attention = value
            case "failed":      counts.failed = value
            default: break
            }
        }
        return counts
    }
}
