import XCTest
@testable import Moler

final class OptimizeOutputParserTests: XCTestCase {

    var parser: OptimizeOutputParser!

    override func setUp() {
        super.setUp()
        parser = OptimizeOutputParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Header Phase

    func testHeaderLinesReturnUnknown() {
        let event = parser.ingest(line: "Optimize")
        assertUnknown(event)
    }

    // MARK: - Diagnosis Phase

    func testDiagnosisHeader() {
        let event = parser.ingest(line: "PERFORMANCE DIAGNOSIS")
        assertUnknown(event)
    }

    /// Mole prints the heading in title case ("Performance diagnosis").
    func testDiagnosisHeaderTitleCase() {
        let event = parser.ingest(line: "Performance diagnosis")
        assertUnknown(event)

        let item = parser.ingest(line: "  ◎ Memory pressure: swap 15.23GB of 16.11GB used")
        guard case .diagnosisItem(let desc) = item else {
            XCTFail("Expected diagnosisItem, got \(item)"); return
        }
        XCTAssertEqual(desc, "Memory pressure: swap 15.23GB of 16.11GB used")
    }

    func testDiagnosisBottleneck() {
        parser.ingest(line: "PERFORMANCE DIAGNOSIS")
        let event = parser.ingest(line: "  ◎ Likely bottleneck: disk I/O")
        guard case .diagnosisItem(let desc) = event else {
            XCTFail("Expected diagnosisItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "Likely bottleneck: disk I/O")
    }

    func testDiagnosisHint() {
        parser.ingest(line: "PERFORMANCE DIAGNOSIS")
        let event = parser.ingest(line: "  ☞ Desktop composition is busy")
        guard case .diagnosisItem(let desc) = event else {
            XCTFail("Expected diagnosisItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "Desktop composition is busy")
    }

    /// Mole's review marker (`⊙`) appears on diagnosis notes in newer releases.
    func testDiagnosisReviewNote() {
        parser.ingest(line: "Performance diagnosis")
        let event = parser.ingest(line: "  ⊙ Desktop composition is busy")
        guard case .diagnosisItem(let desc) = event else {
            XCTFail("Expected diagnosisItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "Desktop composition is busy")
    }

    func testDiagnosisItemsEmitted() {
        parser.ingest(line: "PERFORMANCE DIAGNOSIS")
        guard case .diagnosisItem(let a) = parser.ingest(line: "  ◎ Bottleneck A") else {
            XCTFail("Expected diagnosisItem for Bottleneck A"); return
        }
        guard case .diagnosisItem(let b) = parser.ingest(line: "  ☞ Hint B") else {
            XCTFail("Expected diagnosisItem for Hint B"); return
        }
        XCTAssertEqual(a, "Bottleneck A")
        XCTAssertEqual(b, "Hint B")
    }

    /// Mole 1.74 prints a plain `✓` line for a clean diagnosis
    /// ("No sustained high-CPU bottleneck detected").
    func testDiagnosisPlainCheckmark() {
        parser.ingest(line: "Performance diagnosis")
        let event = parser.ingest(line: "  ✓ No sustained high-CPU bottleneck detected")
        guard case .diagnosisItem(let desc) = event else {
            XCTFail("Expected diagnosisItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "No sustained high-CPU bottleneck detected")
    }

    // MARK: - Categories Phase

    func testCategoryStarted() {
        let event = parser.ingest(line: "➤ DNS & Spotlight Check")
        guard case .categoryStarted(let name) = event else {
            XCTFail("Expected categoryStarted, got \(event)"); return
        }
        XCTAssertEqual(name, "DNS & Spotlight Check")
    }

    func testCategoryTaskArrow() {
        parser.ingest(line: "➤ DNS & Spotlight Check")
        let event = parser.ingest(line: "  → DNS cache flushed")
        guard case .taskItem(let desc, let completed) = event else {
            XCTFail("Expected taskItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "DNS cache flushed")
        XCTAssertFalse(completed)
    }

    func testCategoryTaskCheckmark() {
        parser.ingest(line: "➤ DNS & Spotlight Check")
        let event = parser.ingest(line: "  ✓ Icon services cache rebuilt")
        guard case .taskItem(let desc, let completed) = event else {
            XCTFail("Expected taskItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "Icon services cache rebuilt")
        XCTAssertTrue(completed)
    }

    /// Mole ≥ 1.67 prints `○` for every task during a dry run.
    func testCategoryTaskDryRunCircle() {
        parser.ingest(line: "➤ Finder Cache Refresh")
        let event = parser.ingest(line: "  ○ QuickLook thumbnails refreshed")
        guard case .taskItem(let desc, let completed) = event else {
            XCTFail("Expected taskItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "QuickLook thumbnails refreshed")
        XCTAssertFalse(completed)
        XCTAssertEqual(parser.categories[0].tasks.count, 1)
    }

    /// Mole marks skipped/failed work inside a category with `◎`, e.g.
    /// "Close these apps before database optimization: Safari".
    func testCategoryWarningRow() {
        parser.ingest(line: "➤ Database Optimization")
        let event = parser.ingest(line: "  ◎ Close these apps before database optimization: Safari")
        guard case .warningItem(let desc) = event else {
            XCTFail("Expected warningItem, got \(event)"); return
        }
        XCTAssertEqual(desc, "Close these apps before database optimization: Safari")
        XCTAssertEqual(parser.categories[0].tasks.count, 1)
        XCTAssertTrue(parser.categories[0].tasks[0].isWarning)
        XCTAssertFalse(parser.categories[0].tasks[0].isCompleted)
    }

    func testMultipleCategories() {
        parser.ingest(line: "➤ DNS & Spotlight Check")
        parser.ingest(line: "  → Task A")

        let event2 = parser.ingest(line: "➤ Finder Cache Refresh")
        guard case .categoryStarted(let name) = event2 else {
            XCTFail("Expected categoryStarted, got \(event2)"); return
        }
        XCTAssertEqual(name, "Finder Cache Refresh")
        XCTAssertEqual(parser.categories.count, 2)
    }

    func testTasksAssignedToCategory() {
        parser.ingest(line: "➤ Category A")
        parser.ingest(line: "  → Task 1")
        parser.ingest(line: "  ✓ Task 2")

        XCTAssertEqual(parser.categories.count, 1)
        XCTAssertEqual(parser.categories[0].tasks.count, 2)
        XCTAssertEqual(parser.categories[0].tasks[0].description, "Task 1")
        XCTAssertFalse(parser.categories[0].tasks[0].isCompleted)
        XCTAssertEqual(parser.categories[0].tasks[1].description, "Task 2")
        XCTAssertTrue(parser.categories[0].tasks[1].isCompleted)
    }

    // MARK: - Footer Phase

    func testFooterTotalOptimizations() {
        parser.ingest(line: "========================================")
        let event = parser.ingest(line: "Would apply 22 optimizations")
        guard case .totalOptimizations(let count) = event else {
            XCTFail("Expected totalOptimizations, got \(event)"); return
        }
        XCTAssertEqual(count, 22)
    }

    func testFooterDryRunComplete() {
        parser.ingest(line: "========================================")
        let event = parser.ingest(line: "Dry Run Complete, No Changes Made")
        guard case .runComplete = event else {
            XCTFail("Expected runComplete, got \(event)"); return
        }
    }

    func testFooterRealRunOptimizationCount() {
        parser.ingest(line: "========================================")
        let event = parser.ingest(line: "Applied 12 optimizations successfully")
        // "optimizations" keyword triggers totalOptimizations before runComplete
        guard case .totalOptimizations(let count) = event else {
            XCTFail("Expected totalOptimizations, got \(event)"); return
        }
        XCTAssertEqual(count, 12)
    }

    func testFooterCompleteKeyword() {
        parser.ingest(line: "========================================")
        let event = parser.ingest(line: "Complete - all optimizations applied")
        guard case .runComplete = event else {
            XCTFail("Expected runComplete, got \(event)"); return
        }
    }

    /// Mole 1.67+ prints an outcome breakdown under the total line.
    func testFooterOutcomeCounts() {
        parser.ingest(line: "========================================")
        let event = parser.ingest(line: "14 unchanged | 2 skipped | 1 unavailable")
        guard case .outcomes(let counts) = event else {
            XCTFail("Expected outcomes, got \(event)"); return
        }
        XCTAssertEqual(counts.unchanged, 14)
        XCTAssertEqual(counts.skipped, 2)
        XCTAssertEqual(counts.unavailable, 1)
        XCTAssertEqual(counts.applied, 0)

        XCTAssertEqual(parser.outcomeCounts.unchanged, 14)
        XCTAssertEqual(parser.outcomeCounts.skipped, 2)
        XCTAssertEqual(parser.outcomeCounts.unavailable, 1)
    }

    func testFooterOutcomeCountsWithFailed() {
        parser.ingest(line: "========================================")
        let event = parser.ingest(line: "1 failed | 2 attention")
        guard case .outcomes(let counts) = event else {
            XCTFail("Expected outcomes, got \(event)"); return
        }
        XCTAssertEqual(counts.failed, 1)
        XCTAssertEqual(counts.attention, 2)
    }

    // MARK: - Unknown Lines

    func testEmptyLine() {
        let event = parser.ingest(line: "")
        assertUnknown(event)
    }

    func testWhitespaceLine() {
        let event = parser.ingest(line: "   ")
        assertUnknown(event)
    }

    func testGibberishLine() {
        let event = parser.ingest(line: "Some random text")
        assertUnknown(event)
    }

    // MARK: - Reset

    func testReset() {
        parser.ingest(line: "➤ DNS Check")
        parser.ingest(line: "  → Task")
        parser.ingest(line: "========================================")
        parser.ingest(line: "Would apply 5 optimizations")
        parser.ingest(line: "3 skipped")

        XCTAssertEqual(parser.categories.count, 1)
        XCTAssertEqual(parser.totalOptimizations, 5)
        XCTAssertEqual(parser.outcomeCounts.skipped, 3)

        parser.reset()
        XCTAssertEqual(parser.categories.count, 0)
        XCTAssertEqual(parser.totalOptimizations, 0)
        XCTAssertNil(parser.currentCategory)
        XCTAssertEqual(parser.outcomeCounts, OptimizeOutcomeCounts())
    }

    // MARK: - Full Dry Run Output

    func testFullDryRunOutput() {
        let lines = [
            "Optimize",
            "→ DRY RUN MODE, No files will be modified",
            "",
            "PERFORMANCE DIAGNOSIS",
            "  ◎ Likely bottleneck: Desktop composition",
            "  ☞ System uptime: 3d",
            "",
            "➤ DNS & Spotlight Check",
            "  → DNS cache flushed",
            "  ✓ Spotlight index verified",
            "",
            "➤ Finder Cache Refresh",
            "  → QuickLook thumbnails refreshed",
            "  ✓ Icon services cache rebuilt",
            "",
            "========================================",
            "Dry Run Complete, No Changes Made",
            "Would apply 22 optimizations",
            "========================================",
        ]

        let events = lines.map { parser.ingest(line: $0) }

        // Verify diagnosis
        let diagnosisEvents = events.filter {
            if case .diagnosisItem = $0 { return true }
            return false
        }
        XCTAssertEqual(diagnosisEvents.count, 2)

        // Verify categories
        let categoryEvents = events.filter {
            if case .categoryStarted = $0 { return true }
            return false
        }
        XCTAssertEqual(categoryEvents.count, 2)

        // Verify total optimizations
        let totalOpts = events.filter {
            if case .totalOptimizations = $0 { return true }
            return false
        }
        XCTAssertEqual(totalOpts.count, 1)

        // Verify run complete
        let completes = events.filter {
            if case .runComplete = $0 { return true }
            return false
        }
        XCTAssertEqual(completes.count, 1)

        // Verify parser final state
        XCTAssertEqual(parser.categories.count, 2)
        XCTAssertEqual(parser.totalOptimizations, 22)
    }

    // MARK: - Helpers

    private func assertUnknown(_ event: ParsedEvent, line: UInt = #line) {
        guard case .unknown = event else {
            XCTFail("Expected .unknown, got \(event)", line: line); return
        }
    }
}
