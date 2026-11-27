import Foundation

// MARK: - Plan Models

/// What `mo clean --dry-run` says it would remove.
///
/// Parsed from the human-readable preview (Mole ≥ 1.74 with `NO_COLOR=1`):
///
/// ```
/// Dry Run Mode, Preview only, no deletions
/// ◎ System caches need sudo, run sudo -v && mo clean --dry-run for full preview
///
/// ⚙ Apple Silicon | Free space: 109.89GB
///
/// ➤ User essentials
///   ○ User app cache · 56 items, 2.54GB dry
///   ◎ Xcode XCTestDevices · skipped (process state unknown)
///   ⊙ Docker storage · Images 2.787GB, 983.1MB reclaimable
///
/// ======================================================================
/// Dry run complete - no changes made
/// Potential space: 5.97GB · 601 items
/// Detailed file list: /Users/me/.config/mole/clean-list.txt
/// Skipped in this preview · Chrome, GitHub CLI, WeChat
/// ======================================================================
/// ```
struct CleanPlan: Equatable {
    var categories: [CleanPlanCategory] = []
    /// Total Mole says it could reclaim, from the summary line.
    var potentialBytes: Int64 = 0
    /// Item count from the summary line.
    var itemCount: Int = 0
    /// Families left out of the preview because their app was running.
    var skippedFamilies: [String] = []
    /// Path to Mole's full per-file preview, when it wrote one.
    var detailedListPath: String?
    /// Header warnings, such as "system caches need sudo".
    var warnings: [String] = []
    /// Whether a full preview needs admin access (system caches were skipped).
    var requiresAdminForSystemCaches: Bool = false

    var totalItems: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }

    var cleanableCount: Int {
        categories.reduce(0) { partial, category in
            partial + category.items.filter { $0.kind == .cleanable }.count
        }
    }

    var hasCleanableItems: Bool { cleanableCount > 0 }

    /// Item count to show in the UI: Mole's summary count when present,
    /// otherwise the number of rows we parsed.
    var displayItemCount: Int { itemCount > 0 ? itemCount : totalItems }
}

struct CleanPlanCategory: Identifiable, Equatable {
    let id: String
    let name: String
    var items: [CleanPlanItem] = []
}

struct CleanPlanItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case cleanable  // ○ — Mole would remove it
        case skipped    // ◎ — protected, busy, or needs admin
        case note       // ⊙ — review only, never removed automatically
    }

    let id: String
    let name: String
    let kind: Kind
}

// MARK: - Parser

enum CleanDryRunParser {

    static func parse(_ text: String) -> CleanPlan {
        var plan = CleanPlan()
        var currentCategory: Int?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // ➤ Category
            if line.hasPrefix("➤") {
                let name = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                plan.categories.append(CleanPlanCategory(id: name, name: name))
                currentCategory = plan.categories.count - 1
                continue
            }

            // Summary fields
            if line.hasPrefix("Potential space:") {
                plan.potentialBytes = CleanSummaryParser.sizeBytes(in: line) ?? 0
                plan.itemCount = CleanSummaryParser.itemCount(in: line) ?? 0
                continue
            }
            if line.hasPrefix("Detailed file list:") {
                let path = String(line.dropFirst("Detailed file list:".count))
                    .trimmingCharacters(in: .whitespaces)
                plan.detailedListPath = path.isEmpty ? nil : path
                continue
            }
            if line.hasPrefix("Skipped in this preview") {
                plan.skippedFamilies = skippedFamilies(from: line)
                continue
            }

            // Item rows
            guard let marker = line.first, "○◎⊙✓".contains(marker) else { continue }
            let body = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }

            switch marker {
            case "○":
                // Mole uses `○` for every preview row and appends
                // "would skip (reason)" when the item is protected or busy.
                let kind: CleanPlanItem.Kind =
                    body.localizedCaseInsensitiveContains("would skip") ? .skipped : .cleanable
                append(kind, body, to: currentCategory, in: &plan)

            case "◎":
                if let index = currentCategory {
                    plan.categories[index].items.append(makeItem(
                        .skipped, body,
                        categoryID: plan.categories[index].id,
                        index: plan.categories[index].items.count
                    ))
                } else {
                    // Header warning before the first category, e.g.
                    // "System caches need sudo, run sudo -v && mo clean …".
                    plan.warnings.append(body)
                    if body.localizedCaseInsensitiveContains("sudo") {
                        plan.requiresAdminForSystemCaches = true
                    }
                }

            case "⊙":
                append(.note, body, to: currentCategory, in: &plan)

            default:
                // ✓ Nothing to clean — nothing to add.
                break
            }
        }

        return plan
    }

    // MARK: - Helpers

    private static func append(
        _ kind: CleanPlanItem.Kind,
        _ body: String,
        to categoryIndex: Int?,
        in plan: inout CleanPlan
    ) {
        guard let index = categoryIndex else { return }
        plan.categories[index].items.append(makeItem(
            kind, body,
            categoryID: plan.categories[index].id,
            index: plan.categories[index].items.count
        ))
    }

    private static func makeItem(
        _ kind: CleanPlanItem.Kind,
        _ body: String,
        categoryID: String,
        index: Int
    ) -> CleanPlanItem {
        CleanPlanItem(
            id: "\(categoryID)|\(index)|\(kind)|\(body)",
            name: displayName(body),
            kind: kind
        )
    }

    /// Strip dry-run wording so the review reads like a plan.
    private static func displayName(_ body: String) -> String {
        var text = body
        if text.hasSuffix(" dry") {
            text.removeLast(4)
        }
        let replacements: [(String, String)] = [
            ("would clean", "cleanable"),
            ("would skip", "skipped"),
            ("would prune", "prune"),
            ("would free", "free"),
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        return text
    }

    /// "Skipped in this preview · Chrome, GitHub CLI, WeChat" → names.
    private static func skippedFamilies(from line: String) -> [String] {
        guard let separator = line.range(of: "·") else { return [] }
        return line[separator.upperBound...]
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
