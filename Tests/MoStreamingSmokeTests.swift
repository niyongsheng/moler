import XCTest
@testable import Moler

/// Smoke test for the real CLI. Skipped on machines without `mo` installed.
final class MoStreamingSmokeTests: XCTestCase {

    func testStreamsVersionFromInstalledMo() throws {
        try XCTSkipIf(MoleCLI.findExecutable() == nil, "mo is not installed")

        let ended = expectation(description: "mo --version exit")
        let lock = NSLock()
        var output = ""
        var result: StreamedProcessResult?

        let stream = try MoleCLI.stream(
            args: ["--version"],
            timeout: 10,
            onStdout: { chunk in
                lock.lock(); output += chunk; lock.unlock()
            },
            onExit: { exitResult, _ in
                lock.lock(); result = exitResult; lock.unlock()
                ended.fulfill()
            }
        )
        try stream.start()
        wait(for: [ended], timeout: 15)

        lock.lock(); defer { lock.unlock() }
        XCTAssertEqual(result?.exitCode, 0)
        XCTAssertFalse(result?.timedOut ?? true)
        XCTAssertTrue(output.contains("Mole version"), "unexpected output: \(output)")
    }
}
