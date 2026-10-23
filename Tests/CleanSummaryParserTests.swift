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
    }

    func testDryRunPotentialSpace() {
        let summary = CleanSummaryParser.parse("Potential space: 2MB | Items: 7 | Categories: 2")
        XCTAssertEqual(summary?.freedBytes, 2_097_152)
        XCTAssertEqual(summary?.itemsCleaned, 7)
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
        XCTAssertNil(CleanSummaryParser.parse(
            "Tracked cleanup: Partially measured | Items cleaned: 0"
        ))
    }
}
