import XCTest
@testable import Moler

final class DiskScannerTests: XCTestCase {

    // MARK: - parse valid JSON

    func testParseFullResult() throws {
        let json = """
        {
            "path": "/Users/test",
            "total_size": 1048576,
            "total_files": 3,
            "entries": [
                {"name": "file1.txt", "path": "/Users/test/file1.txt", "size": 1024, "is_dir": false},
                {"name": "folderA", "path": "/Users/test/folderA", "size": 1048576, "is_dir": true},
                {"name": "file2.jpg", "path": "/Users/test/file2.jpg", "size": 512000, "is_dir": false}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertEqual(result.path, "/Users/test")
        XCTAssertEqual(result.totalSize, 1048576)
        XCTAssertEqual(result.totalFiles, 3)
        XCTAssertEqual(result.entries.count, 3)
    }

    func testParseEntriesSortedBySizeDescending() throws {
        let json = """
        {
            "path": "/test",
            "entries": [
                {"name": "small", "path": "/test/small", "size": 100, "is_dir": false},
                {"name": "large", "path": "/test/large", "size": 99999, "is_dir": false},
                {"name": "medium", "path": "/test/medium", "size": 5000, "is_dir": false}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        let sizes = result.entries.map(\.size)
        XCTAssertEqual(sizes, [99999, 5000, 100])
    }

    func testParseEntryKind() throws {
        let json = """
        {
            "path": "/test",
            "entries": [
                {"name": "archive.zip", "path": "/test/archive.zip", "size": 100, "is_dir": false},
                {"name": "folder", "path": "/test/folder", "size": 0, "is_dir": true}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertEqual(result.entries[0].kind, "zip")
        XCTAssertEqual(result.entries[1].kind, "<dir>")
    }

    func testParseEntryKindNoExtension() throws {
        let json = """
        {
            "path": "/test",
            "entries": [
                {"name": "Makefile", "path": "/test/Makefile", "size": 100, "is_dir": false}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertEqual(result.entries[0].kind, "<none>")
    }

    // MARK: - parse edge cases

    func testParseEmptyEntries() throws {
        let json = """
        {
            "path": "/test",
            "total_size": 0,
            "total_files": 0,
            "entries": []
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.totalSize, 0)
    }

    func testParseMissingOptionalFields() throws {
        // total_size, total_files, is_dir are optional with defaults
        let json = """
        {
            "path": "/test",
            "entries": [
                {"name": "file.txt", "path": "/test/file.txt", "size": 500}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertEqual(result.totalFiles, 0)
        XCTAssertEqual(result.totalSize, 0) // missing total_size → 0
        XCTAssertFalse(result.entries[0].isDir)
    }

    func testParseEntryMissingName() throws {
        // Missing name → entry skipped
        let json = """
        {
            "path": "/test",
            "entries": [
                {"path": "/test/unnamed", "size": 100},
                {"name": "valid", "path": "/test/valid", "size": 200}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].name, "valid")
    }

    func testParseEntryMissingPath() throws {
        let json = """
        {
            "path": "/test",
            "entries": [
                {"name": "nopath", "size": 100},
                {"name": "valid", "path": "/test/valid", "size": 200}
            ]
        }
        """.data(using: .utf8)!

        let result = try DiskScanner.parse(json)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].name, "valid")
    }

    func testParseNotJSON() {
        let data = "not json at all".data(using: .utf8)!
        XCTAssertThrowsError(try DiskScanner.parse(data)) { error in
            guard case .parseFailed = error as? MoleError else {
                XCTFail("Expected parseFailed error, got \(error)")
                return
            }
        }
    }

    func testParseNotDictionary() {
        let data = "[\"not\", \"a\", \"dict\"]".data(using: .utf8)!
        XCTAssertThrowsError(try DiskScanner.parse(data)) { error in
            guard case .parseFailed = error as? MoleError else {
                XCTFail("Expected parseFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - staleness

    func testFreshResultIsNotStale() {
        let result = DiskScanResult(
            path: "/test",
            totalSize: 0,
            totalFiles: 0,
            entries: [],
            scannedAt: Date()
        )
        XCTAssertFalse(result.isStale)
    }

    func testStaleResult() {
        let old = Date(timeIntervalSinceNow: -400) // 400s > 300s threshold
        let result = DiskScanResult(
            path: "/test",
            totalSize: 0,
            totalFiles: 0,
            entries: [],
            scannedAt: old
        )
        XCTAssertTrue(result.isStale)
    }

    // MARK: - DiskScanEntry identity

    func testEntryIdentity() {
        let a = DiskScanEntry(id: "/a", name: "a", path: "/a", size: 100, isDir: false)
        let b = DiskScanEntry(id: "/a", name: "a", path: "/a", size: 100, isDir: false)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testEntryIdentityDifferentSize() {
        // Hashable conformance should use id primarily — same id → same hash
        let a = DiskScanEntry(id: "/same", name: "a", path: "/same", size: 100, isDir: false)
        let b = DiskScanEntry(id: "/same", name: "b", path: "/same", size: 200, isDir: true)
        // They are NOT equal because Equatable derives from properties
        // but should both have the same id-based stability
        XCTAssertNotEqual(a, b)
    }
}
