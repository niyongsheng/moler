import XCTest
@testable import Moler

final class LineBufferTests: XCTestCase {

    func testSplitsChunksAndTrims() {
        let buffer = LineBuffer()

        XCTAssertEqual(buffer.append("alpha\n  beta  \n").newLines, ["alpha", "beta"])
        XCTAssertEqual(buffer.append("gam").newLines, [])
        XCTAssertEqual(buffer.append("ma\n").newLines, ["gamma"])
        XCTAssertEqual(buffer.append("delta\n").newLines, ["delta"])

        let snapshot = buffer.snapshot()
        XCTAssertEqual(snapshot.lines, ["alpha", "beta", "gamma", "delta"])
        XCTAssertEqual(snapshot.output, "alpha\n  beta  \ngamma\ndelta\n")
    }

    func testEmptyLinesAreDropped() {
        let buffer = LineBuffer()
        let batch = buffer.append("\n\n  \nvalue\n\n")
        XCTAssertEqual(batch.newLines, ["value"])
        XCTAssertEqual(buffer.snapshot().lines, ["value"])
    }

    func testFlushPartialEmitsTrailingLine() {
        let buffer = LineBuffer()
        XCTAssertEqual(buffer.append("head\ntail").newLines, ["head"])

        XCTAssertEqual(buffer.flushPartial(), "tail")
        XCTAssertEqual(buffer.snapshot().lines, ["head", "tail"])
        XCTAssertNil(buffer.flushPartial())
    }

    func testFlushPartialIgnoresWhitespace() {
        let buffer = LineBuffer()
        buffer.append("   ")
        XCTAssertNil(buffer.flushPartial())
        XCTAssertTrue(buffer.snapshot().lines.isEmpty)
    }

    func testTimeoutFlagAndReset() {
        let buffer = LineBuffer()
        buffer.append("line\n")
        buffer.markTimedOut()
        XCTAssertTrue(buffer.snapshot().timedOut)

        buffer.reset()
        XCTAssertFalse(buffer.snapshot().timedOut)
        XCTAssertTrue(buffer.snapshot().lines.isEmpty)
        XCTAssertEqual(buffer.snapshot().output, "")
    }
}
