import XCTest
@testable import Moler

final class MoleCLITests: XCTestCase {

    // MARK: - MoleError descriptions

    func testErrorNotFoundDescription() {
        let err = MoleError.notFound
        let desc = err.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertFalse(desc!.isEmpty)
    }

    func testErrorFailedDescription() {
        let err = MoleError.failed(exitCode: 1, stderr: "Something went wrong")
        let desc = err.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc!.contains("1"))
        XCTAssertTrue(desc!.contains("Something went wrong"))
    }

    func testErrorTimedOutDescription() {
        let err = MoleError.timedOut(timeout: 60)
        let desc = err.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc!.contains("1")) // 60/60 = 1 minute
    }

    func testErrorParseFailedDescription() {
        let err = MoleError.parseFailed("Unexpected token")
        let desc = err.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc!.contains("Unexpected token"))
    }

    func testErrorFailedStderrTruncated() {
        let longError = String(repeating: "x", count: 500)
        let err = MoleError.failed(exitCode: 2, stderr: longError)
        let desc = err.errorDescription!
        // Should include the first 200 chars
        XCTAssertTrue(desc.contains(String(repeating: "x", count: 200)))
    }

    // MARK: - CapturedProcess

    func testCapturedProcessInit() {
        let cp = CapturedProcess(stdout: "out", stderr: "err", exitCode: 0)
        XCTAssertEqual(cp.stdout, "out")
        XCTAssertEqual(cp.stderr, "err")
        XCTAssertEqual(cp.exitCode, 0)
        XCTAssertFalse(cp.timedOut)
    }

    func testCapturedProcessTimedOut() {
        var cp = CapturedProcess(stdout: "", stderr: "", exitCode: 0)
        cp.timedOut = true
        XCTAssertTrue(cp.timedOut)
    }

    // MARK: - Install consts

    func testInstallCommand() {
        XCTAssertEqual(MoleCLI.installCommand, "brew install mole")
    }

    func testRepoURL() {
        XCTAssertEqual(MoleCLI.repoURL, URL(string: "https://github.com/tw93/Mole")!)
    }

    // MARK: - Version compatibility

    func testSupportedVersions() {
        XCTAssertTrue(MoleCLI.isSupported(version: "1.62.0"))
        XCTAssertTrue(MoleCLI.isSupported(version: "1.62"))
        XCTAssertTrue(MoleCLI.isSupported(version: "1.73.0"))
        XCTAssertTrue(MoleCLI.isSupported(version: "2.0.0"))
    }

    func testUnsupportedVersions() {
        XCTAssertFalse(MoleCLI.isSupported(version: "1.61.9"))
        XCTAssertFalse(MoleCLI.isSupported(version: "1.5"))
        XCTAssertFalse(MoleCLI.isSupported(version: "0.9.9"))
    }

    func testVersionComparisonIsNumeric() {
        XCTAssertEqual(MoleCLI.compareVersions("1.9.0", "1.10.0"), .orderedAscending)
        XCTAssertEqual(MoleCLI.compareVersions("1.10.0", "1.9.0"), .orderedDescending)
        XCTAssertEqual(MoleCLI.compareVersions("1.73", "1.73.0"), .orderedSame)
    }
}
