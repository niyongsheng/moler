import XCTest
@testable import Moler

final class PurgePlanParserTests: XCTestCase {

    private let sample = """
    ○ DRY RUN MODE, No project artifacts will be removed

    Purge Project Artifacts

    ✓ [DRY RUN] ~/work_space/SourceTree/AudioScript/dist, 819KB
    ✓ [DRY RUN] ~/work_space/SourceTree/Business/fucoo/tests/__pycache__, 492KB
    ✓ [DRY RUN] ~/Library/CloudStorage/GoogleDrive-me/My Drive/App/build, 12.5MB
    ✓ [DRY RUN] ~/work_space/odd, name/app/.next, 1.2MB

    ======================================================================
    Dry run complete - no changes made
    Would free approximately: 14.5MB | Items: 4 | Free: 109.86GB
    ======================================================================
    """

    func testEntries() {
        let plan = PurgePlanParser.parse(sample)
        XCTAssertEqual(plan.entries.count, 4)
        XCTAssertEqual(plan.displayItemCount, 4)
        XCTAssertFalse(plan.isEmpty)

        // Sorted largest first.
        XCTAssertEqual(plan.entries[0].size, 13_107_200)   // 12.5MB
        XCTAssertEqual(plan.entries[1].size, 1_258_291)    // 1.2MB
        XCTAssertEqual(plan.entries[2].size, 838_656)      // 819KB
        XCTAssertEqual(plan.entries[3].size, 503_808)      // 492KB
    }

    func testPathExpansionAndCommaInPath() {
        let plan = PurgePlanParser.parse(sample)
        let names = Set(plan.entries.map(\.name))
        XCTAssertTrue(names.contains("dist"))
        XCTAssertTrue(names.contains("__pycache__"))
        XCTAssertTrue(names.contains(".next"))

        let commaPath = plan.entries.first { $0.name == ".next" }
        XCTAssertEqual(commaPath?.path, (("~/work_space/odd, name/app/.next" as NSString).expandingTildeInPath))
    }

    func testCloudDetection() {
        let plan = PurgePlanParser.parse(sample)
        XCTAssertEqual(plan.cloudCount, 1)
        XCTAssertTrue(plan.entries.contains { $0.name == "build" && $0.isCloud })
    }

    func testSummaryTotals() {
        let plan = PurgePlanParser.parse(sample)
        // Summary is authoritative, not the sum of rows.
        XCTAssertEqual(plan.totalBytes, 15_204_352) // 14.5MB
        XCTAssertEqual(plan.itemCount, 4)
        XCTAssertEqual(plan.freeSpaceBytes, 117_961_276_784) // 109.86GB
    }

    func testDuplicatePathsAreCollapsed() {
        let output = """
        ✓ [DRY RUN] ~/Projects/App/dist, 1MB
        ✓ [DRY RUN] ~/Projects/App/dist, 1MB
        """
        let plan = PurgePlanParser.parse(output)
        XCTAssertEqual(plan.entries.count, 1)
        XCTAssertEqual(plan.totalBytes, 1_048_576)
    }

    func testNoArtifacts() {
        let plan = PurgePlanParser.parse("Purge Project Artifacts\n\nNo artifacts found to purge\n")
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.itemCount, 0)
        XCTAssertEqual(plan.totalBytes, 0)
    }

    func testRunSummary() {
        let output = """
        Purge complete
        Estimated space freed: 1.5GB | Items: 42 | Free: 200.0GB
        """
        let summary = PurgePlanParser.parseRunSummary(output)
        XCTAssertEqual(summary?.freedBytes, 1_610_612_736)
        XCTAssertEqual(summary?.itemsRemoved, 42)
        XCTAssertEqual(summary?.incomplete, false)
    }

    func testRunSummaryIncomplete() {
        let output = """
        Purge incomplete
        Estimated space freed: 10MB | Items: 2 | Free: 200.0GB
        Some artifacts were skipped or could not be processed.
        """
        let summary = PurgePlanParser.parseRunSummary(output)
        XCTAssertEqual(summary?.freedBytes, 10_485_760)
        XCTAssertEqual(summary?.itemsRemoved, 2)
        XCTAssertEqual(summary?.incomplete, true)
    }

    func testRunSummaryNothingRemoved() {
        let summary = PurgePlanParser.parseRunSummary("No artifacts were removed.\nFree space: 200GB")
        XCTAssertEqual(summary?.freedBytes, 0)
        XCTAssertEqual(summary?.itemsRemoved, 0)
        XCTAssertEqual(summary?.incomplete, false)
    }

    // MARK: - Config parsing

    func testActivePathsIgnoresCommentsAndBlankLines() {
        let text = """
        # Mole Purge Paths
        ~/Projects

          ~/Developer
        # ~/ignored
        /absolute/path
        """
        XCTAssertEqual(PurgePathConfig.activePaths(in: text), [
            ("~/Projects" as NSString).expandingTildeInPath,
            ("~/Developer" as NSString).expandingTildeInPath,
            "/absolute/path",
        ])
    }

    func testActivePathsEmpty() {
        XCTAssertEqual(PurgePathConfig.activePaths(in: "# only comments\n\n"), [])
    }
}
