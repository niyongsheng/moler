import XCTest
@testable import Moler

final class FormatTests: XCTestCase {

    // MARK: - formatBytes

    func testFormatBytesZero() {
        XCTAssertEqual(Format.bytes(0 as Int64), "0 B")
        XCTAssertEqual(Format.bytes(0 as UInt64), "0 B")
    }

    func testFormatBytesBytes() {
        XCTAssertEqual(Format.bytes(500 as Int64), "500 B")
    }

    func testFormatBytesKB() {
        XCTAssertEqual(Format.bytes(1024 as Int64), "1.0 KB")
    }

    func testFormatBytesMB() {
        XCTAssertEqual(Format.bytes(1_048_576 as Int64), "1.0 MB")
    }

    func testFormatBytesGB() {
        XCTAssertEqual(Format.bytes(1_073_741_824 as Int64), "1.0 GB")
    }

    func testFormatBytesTB() {
        XCTAssertEqual(Format.bytes(1_099_511_627_776 as Int64), "1.0 TB")
    }

    func testFormatBytesFractional() {
        XCTAssertEqual(Format.bytes(1_500_000 as Int64), "1.4 MB")
    }

    func testFormatBytesNegative() {
        XCTAssertEqual(Format.bytes(-1024 as Int64), "-1.0 KB")
    }

    func testFormatBytesLarge() {
        let val: Int64 = 2_199_023_255_552  // 2 TB
        XCTAssertEqual(Format.bytes(val), "2.0 TB")
    }

    // MARK: - free function formatBytes

    func testFreeFormatBytes() {
        XCTAssertEqual(formatBytes(0), "0 B")
        XCTAssertEqual(formatBytes(1024), "1.0 KB")
        XCTAssertEqual(formatBytes(1_048_576), "1.0 MB")
        XCTAssertEqual(formatBytes(-2048), "-2.0 KB")
    }

    // MARK: - count

    func testCountZero() {
        XCTAssertEqual(Format.count(0), "0")
    }

    func testCountSmall() {
        XCTAssertEqual(Format.count(42), "42")
    }

    func testCountWithThousands() {
        // Locale-aware: en defaults to "," separator
        let result = Format.count(1234567)
        XCTAssertTrue(result.contains("1"))
        XCTAssertTrue(result.contains("234") || result.contains("567"))
    }

    func testCountMax() {
        let result = Format.count(Int.max)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - relativeDate

    func testRelativeDateNil() {
        XCTAssertEqual(Format.relativeDate(nil), "Never")
    }

    func testRelativeDateJustNow() {
        let date = Date()
        XCTAssertEqual(Format.relativeDate(date), "just now")
    }

    func testRelativeDateMinutes() {
        let date = Date(timeIntervalSinceNow: -180)  // 3 min ago
        XCTAssertEqual(Format.relativeDate(date), "3m ago")
    }

    func testRelativeDateHours() {
        let date = Date(timeIntervalSinceNow: -7200)  // 2 hours ago
        XCTAssertEqual(Format.relativeDate(date), "2h ago")
    }

    func testRelativeDateDays() {
        let date = Date(timeIntervalSinceNow: -432000)  // 5 days ago
        XCTAssertEqual(Format.relativeDate(date), "5d ago")
    }

    func testRelativeDateEdgeMinute() {
        let date = Date(timeIntervalSinceNow: -59)
        XCTAssertEqual(Format.relativeDate(date), "just now")
    }

    // MARK: - uptime

    func testUptimeSeconds() {
        XCTAssertEqual(Format.uptime(12), "12s")
    }

    func testUptimeMinutes() {
        XCTAssertEqual(Format.uptime(45 * 60), "45m")
    }

    func testUptimeDaysHours() {
        XCTAssertEqual(Format.uptime(2 * 86400 + 3 * 3600), "2d 3h")
    }

    func testUptimeHoursMin() {
        XCTAssertEqual(Format.uptime(25 * 3600), "1d 1h")
    }

    // MARK: - abbreviatePath

    func testAbbreviatePathShort() {
        let path = "/Users/test/File.swift"
        XCTAssertEqual(Format.abbreviatePath(path, maxLen: 200), path)
    }

    func testAbbreviatePathHomeReplacement() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // maxLen between abbrev length (11) and original length (24) forces
        // replacement without truncation: "/Users/nigang/Documents" → "~/Documents"
        let result = Format.abbreviatePath("\(home)/Documents", maxLen: 15)
        XCTAssertEqual(result, "~/Documents")
    }

    func testAbbreviatePathTruncated() {
        let long = "/Users/test/very/long/path/that/should/be/truncated/file.txt"
        let result = Format.abbreviatePath(long, maxLen: 30)
        XCTAssertEqual(result.count, 30)
        XCTAssertTrue(result.hasPrefix("..."))
    }

    func testAbbreviatePathHomeThenTruncated() {
        let long = "/Users/test/very/long/path/that/should/be/truncated/file.txt"
        let result = Format.abbreviatePath(long, maxLen: 40)
        XCTAssertEqual(result.count, 40)
        XCTAssertTrue(result.hasPrefix("..."))
    }

    // MARK: - parseSizeBytes

    func testParseSizeBytesKB() {
        XCTAssertEqual(parseSizeBytes("500KB"), 512_000)
    }

    func testParseSizeBytesMB() {
        XCTAssertEqual(parseSizeBytes("1.5MB"), 1_572_864)
    }

    func testParseSizeBytesGB() {
        XCTAssertEqual(parseSizeBytes("2GB"), 2_147_483_648)
    }

    func testParseSizeBytesTB() {
        XCTAssertEqual(parseSizeBytes("1TB"), 1_099_511_627_776)
    }

    func testParseSizeBytesBytes() {
        XCTAssertEqual(parseSizeBytes("42B"), 42)
    }

    func testParseSizeBytesEmpty() {
        XCTAssertEqual(parseSizeBytes(""), 0)
    }

    func testParseSizeBytesGarbage() {
        XCTAssertEqual(parseSizeBytes("not_a_size"), 0)
    }

    func testParseSizeBytesLowercase() {
        XCTAssertEqual(parseSizeBytes("100mb"), 104_857_600)
    }

    func testParseSizeBytesWithSpaces() {
        XCTAssertEqual(parseSizeBytes("  1.2 GB  "), 1_288_490_188)
    }
}
