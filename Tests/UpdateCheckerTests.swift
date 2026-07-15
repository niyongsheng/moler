import XCTest
@testable import Moler

final class UpdateCheckerTests: XCTestCase {

    // MARK: - isNewer

    func testIsNewerSameVersion() {
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
    }

    func testIsNewerRemoteNewer() {
        XCTAssertTrue(UpdateChecker.isNewer("1.1.0", than: "1.0.0"))
    }

    func testIsNewerRemoteOlder() {
        XCTAssertFalse(UpdateChecker.isNewer("0.9.0", than: "1.0.0"))
    }

    func testIsNewerVPrefix() {
        XCTAssertTrue(UpdateChecker.isNewer("v2.0.0", than: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("V2.0.0", than: "1.0.0"))
    }

    func testIsNewerRaggedLengths() {
        // "1" should compare as 1.0.0
        XCTAssertTrue(UpdateChecker.isNewer("2", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1", than: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0.1", than: "1.0"))
    }

    func testIsNewerWithWhitespace() {
        XCTAssertTrue(UpdateChecker.isNewer(" 2.0.0 ", than: "1.0.0"))
    }

    func testIsNewerDifferentComponentCount() {
        // 3-component vs 2-component
        XCTAssertTrue(UpdateChecker.isNewer("1.0.1", than: "1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.1", than: "1.0.9"))
    }

    func testIsNewerMultipleDigits() {
        XCTAssertTrue(UpdateChecker.isNewer("10.0", than: "9.0"))
        XCTAssertFalse(UpdateChecker.isNewer("9.0", than: "10.0"))
    }

    // MARK: - parseLatestRelease

    func testParseLatestReleaseValid() throws {
        let json = """
        {
            "tag_name": "v0.1.0",
            "html_url": "https://github.com/niyongsheng/moler/releases/tag/v0.1.0"
        }
        """.data(using: .utf8)!

        let release = UpdateChecker.parseLatestRelease(json)
        XCTAssertNotNil(release)
        XCTAssertEqual(release?.version, "0.1.0")
        XCTAssertEqual(
            release?.url,
            URL(string: "https://github.com/niyongsheng/moler/releases/tag/v0.1.0")
        )
    }

    func testParseLatestReleaseNoVPrefix() throws {
        let json = """
        {
            "tag_name": "1.2.3",
            "html_url": "https://github.com/niyongsheng/moler/releases/tag/1.2.3"
        }
        """.data(using: .utf8)!

        let release = UpdateChecker.parseLatestRelease(json)
        XCTAssertNotNil(release)
        XCTAssertEqual(release?.version, "1.2.3")
    }

    func testParseLatestReleaseInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        XCTAssertNil(UpdateChecker.parseLatestRelease(data))
    }

    func testParseLatestReleaseMissingFields() {
        let json = """
        {
            "tag_name": "v0.1.0"
        }
        """.data(using: .utf8)!
        XCTAssertNil(UpdateChecker.parseLatestRelease(json))
    }

    func testParseLatestReleaseEmptyTag() {
        let json = """
        {
            "tag_name": "",
            "html_url": "https://github.com/niyongsheng/moler/releases/tag/v0.1.0"
        }
        """.data(using: .utf8)!
        XCTAssertNil(UpdateChecker.parseLatestRelease(json))
    }

    func testParseLatestReleaseVOnly() {
        let json = """
        {
            "tag_name": "v",
            "html_url": "https://github.com/niyongsheng/moler/releases/tag/v"
        }
        """.data(using: .utf8)!
        XCTAssertNil(UpdateChecker.parseLatestRelease(json))
    }

    // MARK: - Release model

    func testReleaseInit() {
        let url = URL(string: "https://github.com/test/release")!
        let release = UpdateChecker.Release(version: "1.0.0", url: url)
        XCTAssertEqual(release.version, "1.0.0")
        XCTAssertEqual(release.url, url)
    }
}
