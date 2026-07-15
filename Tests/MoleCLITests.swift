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

    // MARK: - MoCommand

    func testMoCommandDefaults() {
        let cmd = MoCommand(args: ["analyze", "--json", "/"])
        XCTAssertEqual(cmd.args, ["analyze", "--json", "/"])
        XCTAssertNil(cmd.stdin)
        XCTAssertEqual(cmd.timeout, 10)
        XCTAssertNil(cmd.env)
    }

    func testMoCommandCustom() {
        let cmd = MoCommand(args: ["clean"], stdin: "y\n", timeout: 300, env: ["NO_COLOR": "1"])
        XCTAssertEqual(cmd.args, ["clean"])
        XCTAssertEqual(cmd.stdin, "y\n")
        XCTAssertEqual(cmd.timeout, 300)
        XCTAssertEqual(cmd.env, ["NO_COLOR": "1"])
    }

    // MARK: - MoleAvailability

    func testMoleAvailabilityInstalled() {
        let a = MoleAvailability.installed(path: "/opt/homebrew/bin/mo")
        XCTAssertEqual(a, .installed(path: "/opt/homebrew/bin/mo"))
    }

    func testMoleAvailabilityMissing() {
        let a = MoleAvailability.missing
        XCTAssertEqual(a, .missing)
        XCTAssertNotEqual(a, .installed(path: "/test"))
    }

    // MARK: - Install consts

    func testInstallCommand() {
        XCTAssertEqual(MoleCLI.installCommand, "brew install mole")
    }

    func testRepoURL() {
        XCTAssertEqual(MoleCLI.repoURL, URL(string: "https://github.com/tw93/Mole")!)
    }
}
