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
///   → QuickLook thumbnails refreshed
///   ✓ Icon services cache rebuilt
///   ...
///
/// ======================================================================
/// Dry Run Complete, No Changes Made
/// Would apply 22 optimizations
/// ======================================================================
/// ```
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

        // PERFORMANCE DIAGNOSIS header
        if trimmed == "PERFORMANCE DIAGNOSIS" {
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

        // Diagnosis items within PERFORMANCE DIAGNOSIS
        if phase == .diagnosis {
            if trimmed.hasPrefix("◎") || trimmed.hasPrefix("☞") {
                let desc = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let task = OptimizeTask(
                    description: desc,
                    categoryName: "PERFORMANCE DIAGNOSIS",
                    isCompleted: false
                )
                diagnosisItems.append(task)
                return .diagnosisItem(description: desc)
            }
        }

        // Task items within categories
        if phase == .categories, let cat = currentCategory {
            if trimmed.hasPrefix("→") || trimmed.hasPrefix("✓") {
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
    }
}
