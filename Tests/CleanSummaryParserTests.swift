import XCTest
@testable import Moler

final class CleanSummaryParserTests: XCTestCase {

    func testTrackedCleanupSummary() {
        let output = """
        → Xcode cache · 4 items, 706KB
        → Zed npm cache · 3 items, 96.2MB
        ======================================================================
        Cleanup complete
        Tracked cleanup: 1.5GB | Items cleaned: 42
        Free space: 200.0GB (1.5GB)
        ======================================================================
        """
        let summary = CleanSummaryParser.parse(output)
        XCTAssertEqual(summary?.freedBytes, 1_610_612_736)
        XCTAssertEqual(summary?.itemsCleaned, 42)
    }

    func testPartialSizeSuffix() {
        let summary = CleanSummaryParser.parse("Tracked cleanup: 1.5GB+ | Items cleaned: 3")
        XCTAssertEqual(summary?.freedBytes, 1_610_612_736)
        XCTAssertEqual(summary?.itemsCleaned, 3)
        XCTAssertEqual(summary?.isPartial, true)
    }

    func testDryRunPotentialSpace() {
        let summary = CleanSummaryParser.parse("Potential space: 2MB | Items: 7 | Categories: 2")
        XCTAssertEqual(summary?.freedBytes, 2_097_152)
        XCTAssertEqual(summary?.itemsCleaned, 7)
    }

    // MARK: - Mole ≥ 1.67 summary formats

    /// Mole 1.67 replaced `Tracked cleanup: … | Items cleaned: …` with
    /// `Removed: … · … items`.
    func testRemovedSummary() {
        let output = """
        → Xcode cache · 4 items, 706KB
        ======================================================================
        Cleanup complete
        Removed: 1.5GB · 42 items
        Free space: 200.0GB (1.5GB)
        ======================================================================
        """
        let summary = CleanSummaryParser.parse(output)
        XCTAssertEqual(summary?.freedBytes, 1_610_612_736)
        XCTAssertEqual(summary?.itemsCleaned, 42)
    }

    func testRemovedSingularItem() {
        let summary = CleanSummaryParser.parse("Removed: 512MB · 1 item")
        XCTAssertEqual(summary?.freedBytes, 536_870_912)
        XCTAssertEqual(summary?.itemsCleaned, 1)
    }

    /// A lower-bound total ("1.5GB+") still parses its numeric part and is
    /// flagged as partial.
    func testRemovedPartialSize() {
        let summary = CleanSummaryParser.parse("Removed: 1.5GB+ · 3 items")
        XCTAssertEqual(summary?.freedBytes, 1_610_612_736)
        XCTAssertEqual(summary?.itemsCleaned, 3)
        XCTAssertEqual(summary?.isPartial, true)
    }

    func testDryRunPotentialSpaceNewFormat() {
        let summary = CleanSummaryParser.parse("Potential space: 2MB · 7 items")
        XCTAssertEqual(summary?.freedBytes, 2_097_152)
        XCTAssertEqual(summary?.itemsCleaned, 7)
    }

    /// Mole 1.74 can print no size at all when every check timed out. The run
    /// still happened, so return a partial summary instead of nil.
    func testUnmeasuredNewSummaryIsPartial() {
        let summary = CleanSummaryParser.parse("Removed: Partially measured · 0 items")
        XCTAssertEqual(summary?.freedBytes, 0)
        XCTAssertEqual(summary?.itemsCleaned, 0)
        XCTAssertEqual(summary?.isPartial, true)
    }

    func testIgnoresPerItemSizes() {
        let output = """
        → A · 100MB
        → B · 200MB
        Tracked cleanup: 300MB | Items cleaned: 2
        """
        // 300MB, not 600MB — a naive sum of every size would over-count.
        XCTAssertEqual(CleanSummaryParser.parse(output)?.freedBytes, 314_572_800)
    }

    func testNoSummary() {
        XCTAssertNil(CleanSummaryParser.parse(
            "System was already clean; no additional space freed."
        ))
    }

    func testUnmeasuredCleanup() {
        let summary = CleanSummaryParser.parse(
            "Tracked cleanup: Partially measured | Items cleaned: 0"
        )
        XCTAssertEqual(summary?.freedBytes, 0)
        XCTAssertEqual(summary?.isPartial, true)
    }
}
