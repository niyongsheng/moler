import XCTest
@testable import Moler

final class CleanDryRunParserTests: XCTestCase {

    /// Representative Mole 1.74 preview with `NO_COLOR=1`.
    private let sample = """
    Clean Your Mac

    Dry Run Mode, Preview only, no deletions

    ◎ System caches need sudo, run sudo -v && mo clean --dry-run for full preview

    ⚙ Apple Silicon | Free space: 109.89GB
    ⚙ Whitelist: 17 core + 2 custom patterns active

    ➤ User essentials
      ○ User app cache · 56 items, 2.54GB dry
      ○ User app logs · 53 items, 46.6MB dry

    ➤ Developer tools
      ○ npm cache · would clean
      ○ pnpm cache · would skip (pnpm busy)
      ⊙ Rust toolchains · 2 · 1.99.0 besides stable · ~/.rustup/toolchains
      ◎ Xcode XCTestDevices · skipped (process state unknown)

    ➤ Virtualization
      ✓ Nothing to clean

    ➤ Large files
      ⊙ Docker storage · Images 2.787GB, 983.1MB reclaimable

    ======================================================================
    Dry run complete - no changes made
    Potential space: 5.97GB · 601 items
    Detailed file list: /Users/me/.config/mole/clean-list.txt
    Skipped in this preview · Chrome, GitHub CLI, Chrome DevTools MCP, WeChat
    ======================================================================
    """

    func testCategories() {
        let plan = CleanDryRunParser.parse(sample)
        XCTAssertEqual(plan.categories.map(\.name), [
            "User essentials", "Developer tools", "Virtualization", "Large files",
        ])
        XCTAssertEqual(plan.categories[0].items.count, 2)
        XCTAssertEqual(plan.categories[1].items.count, 4)
        XCTAssertTrue(plan.categories[2].items.isEmpty) // ✓ Nothing to clean
        XCTAssertEqual(plan.categories[3].items.count, 1)
    }

    func testItemKinds() {
        let plan = CleanDryRunParser.parse(sample)
        let developer = plan.categories[1]

        XCTAssertEqual(developer.items[0].kind, .cleanable) // npm cache
        XCTAssertEqual(developer.items[1].kind, .skipped)   // would skip (pnpm busy)
        XCTAssertEqual(developer.items[2].kind, .note)      // ⊙ Rust toolchains
        XCTAssertEqual(developer.items[3].kind, .skipped)   // ◎ XCTestDevices
    }

    func testSummaryTotals() {
        let plan = CleanDryRunParser.parse(sample)
        XCTAssertEqual(plan.potentialBytes, 6_410_238_689)
        XCTAssertEqual(plan.itemCount, 601)
        XCTAssertEqual(plan.displayItemCount, 601)
    }

    func testDetailedListPath() {
        let plan = CleanDryRunParser.parse(sample)
        XCTAssertEqual(plan.detailedListPath, "/Users/me/.config/mole/clean-list.txt")
    }

    func testSkippedFamilies() {
        let plan = CleanDryRunParser.parse(sample)
        XCTAssertEqual(plan.skippedFamilies, ["Chrome", "GitHub CLI", "Chrome DevTools MCP", "WeChat"])
    }

    func testSudoWarning() {
        let plan = CleanDryRunParser.parse(sample)
        XCTAssertTrue(plan.requiresAdminForSystemCaches)
        XCTAssertEqual(plan.warnings.count, 1)
        XCTAssertTrue(plan.warnings[0].contains("System caches need sudo"))
    }

    /// "· 2.1MB dry" is preview wording; the review should read cleanly.
    func testDisplayNameStripsDryWording() {
        let plan = CleanDryRunParser.parse(sample)
        XCTAssertEqual(plan.categories[0].items[0].name, "User app cache · 56 items, 2.54GB")
        XCTAssertEqual(plan.categories[1].items[0].name, "npm cache · cleanable")
        XCTAssertEqual(plan.categories[1].items[1].name, "pnpm cache · skipped (pnpm busy)")
    }

    func testCleanableCount() {
        let plan = CleanDryRunParser.parse(sample)
        // Two user-essential rows + npm cache = 3 cleanable items.
        XCTAssertEqual(plan.cleanableCount, 3)
        XCTAssertTrue(plan.hasCleanableItems)
    }

    func testEmptyOutput() {
        let plan = CleanDryRunParser.parse("")
        XCTAssertTrue(plan.categories.isEmpty)
        XCTAssertEqual(plan.potentialBytes, 0)
        XCTAssertEqual(plan.displayItemCount, 0)
        XCTAssertFalse(plan.hasCleanableItems)
    }

    func testNothingToCleanSummary() {
        let output = """
        ➤ User essentials
          ✓ Nothing to clean

        Potential space: 0.00GB
        """
        let plan = CleanDryRunParser.parse(output)
        XCTAssertEqual(plan.potentialBytes, 0)
        XCTAssertEqual(plan.itemCount, 0)
        XCTAssertEqual(plan.totalItems, 0)
    }
}
