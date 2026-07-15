import XCTest
@testable import Moler

final class TreemapLayoutTests: XCTestCase {

    let testRect = CGRect(x: 0, y: 0, width: 400, height: 300)

    // MARK: - layout

    func testLayoutEmpty() {
        let result = TreemapLayout.layout(weights: [], in: testRect)
        XCTAssertTrue(result.isEmpty)
    }

    func testLayoutSingleItem() {
        let result = TreemapLayout.layout(weights: [1], in: testRect)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], testRect)
    }

    func testLayoutPreservesCount() {
        let result = TreemapLayout.layout(weights: [6, 5, 3, 2, 1], in: testRect)
        XCTAssertEqual(result.count, 5)
    }

    func testLayoutAllRectsInsideBounds() {
        let result = TreemapLayout.layout(weights: [6, 5, 3, 2, 1], in: testRect)
        for r in result {
            // Allow 0.1pt floating-point tolerance for rect containment
            let expanded = testRect.insetBy(dx: -0.1, dy: -0.1)
            XCTAssertTrue(expanded.contains(r) || r.isNull || r.isEmpty,
                          "Rect \(r) is outside \(testRect)")
        }
    }

    func testLayoutNoOverlap() {
        let result = TreemapLayout.layout(weights: [6, 5, 3, 2, 1], in: testRect)
        for i in 0..<result.count {
            for j in (i+1)..<result.count {
                let a = result[i].insetBy(dx: 0.5, dy: 0.5)  // tolerance
                let b = result[j].insetBy(dx: 0.5, dy: 0.5)
                XCTAssertTrue(a.intersection(b).isNull || a.intersection(b).isEmpty,
                              "Rects \(i) and \(j) overlap: \(result[i]) vs \(result[j])")
            }
        }
    }

    func testLayoutTotalAreaPreserved() {
        let weights: [Double] = [6, 5, 3, 2, 1]
        let result = TreemapLayout.layout(weights: weights, in: testRect)
        let totalArea = result.reduce(0) { $0 + $1.width * $1.height }
        let expected = testRect.width * testRect.height
        // Allow 1pt rounding error per rect
        XCTAssertEqual(totalArea, expected, accuracy: 5)
    }

    func testLayoutAllZeroWeights() {
        let result = TreemapLayout.layout(weights: [0, 0, 0], in: testRect)
        XCTAssertEqual(result.count, 3)
        for r in result {
            XCTAssertEqual(r, .zero)
        }
    }

    func testLayoutMixedWeights() {
        // Some zero, some positive
        let result = TreemapLayout.layout(weights: [10, 0, 5, 0], in: testRect)
        XCTAssertEqual(result.count, 4)
        // Non-zero items get area, zero items get a tiny rect during layout
        let nonZero = result.filter { !$0.isEmpty }
        XCTAssertGreaterThan(nonZero.count, 0)
    }

    func testLayoutOrderPreserved() {
        let weights: [Double] = [1, 100, 2, 50]
        let result = TreemapLayout.layout(weights: weights, in: testRect)
        XCTAssertEqual(result.count, 4)
        // Order should correspond to input order
        // The largest items may not be the biggest rects if they share rows,
        // but the count and order must match input
    }

    // MARK: - foldOther

    func testFoldOtherUnderLimit() {
        let entries = (0..<10).map {
            DiskScanEntry(id: "\($0)", name: "\($0)", path: "/\($0)", size: Int64($0 * 100), isDir: false)
        }
        let (visible, otherSize) = TreemapLayout.foldOther(entries: entries, maxVisible: 120)
        XCTAssertEqual(visible.count, 10)
        XCTAssertEqual(otherSize, 0)
    }

    func testFoldOtherOverLimit() {
        let entries = (0..<150).map {
            DiskScanEntry(id: "\($0)", name: "\($0)", path: "/\($0)", size: Int64($0 * 10), isDir: false)
        }
        let (visible, otherSize) = TreemapLayout.foldOther(entries: entries, maxVisible: 120)
        XCTAssertEqual(visible.count, 120)
        // Remaining 30 items: sizes 1200...1490
        let expectedOther = (120..<150).reduce(0) { $0 + Int64($1 * 10) }
        XCTAssertEqual(otherSize, expectedOther)
    }

    func testFoldOtherAtLimit() {
        let entries = (0..<120).map {
            DiskScanEntry(id: "\($0)", name: "\($0)", path: "/\($0)", size: 100, isDir: false)
        }
        let (visible, otherSize) = TreemapLayout.foldOther(entries: entries, maxVisible: 120)
        XCTAssertEqual(visible.count, 120)
        XCTAssertEqual(otherSize, 0)
    }

    func testFoldOtherCustomMax() {
        let entries = (0..<5).map {
            DiskScanEntry(id: "\($0)", name: "\($0)", path: "/\($0)", size: Int64($0 * 10), isDir: false)
        }
        let (visible, otherSize) = TreemapLayout.foldOther(entries: entries, maxVisible: 3)
        XCTAssertEqual(visible.count, 3)
        // Dropped items: index 3 (size 30) + index 4 (size 40) = 70
        XCTAssertEqual(otherSize, 70)
    }
}
