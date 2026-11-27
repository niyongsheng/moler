import XCTest
@testable import Moler

/// Exercises `MoleStreamingProcess` with `/bin/sh` stand-ins for `mo`:
/// exit codes, stderr separation, timeout kill, cancellation, stdin and
/// stderr floods (the pipe-deadlock case the old copies all had to guard).
final class MoleStreamingProcessTests: XCTestCase {

    private struct Run {
        let result: StreamedProcessResult?
        let stdout: String
        let stderrChunks: String
        let elapsed: TimeInterval
    }

    private func run(
        _ script: String,
        timeout: TimeInterval? = nil,
        stdin: String? = nil,
        cancelAfter: TimeInterval? = nil
    ) -> Run {
        let ended = expectation(description: "process exit")
        let lock = NSLock()
        var result: StreamedProcessResult?
        var stdout = ""
        var stderrChunks = ""

        let started = Date()
        let stream = MoleStreamingProcess(
            executable: "/bin/sh",
            args: ["-c", script],
            stdin: stdin,
            timeout: timeout,
            onStdout: { chunk in
                lock.lock(); stdout += chunk; lock.unlock()
            },
            onStderr: { chunk in
                lock.lock(); stderrChunks += chunk; lock.unlock()
            },
            onExit: { processResult, _ in
                lock.lock(); result = processResult; lock.unlock()
                ended.fulfill()
            }
        )

        XCTAssertNoThrow(try stream.start())

        if let cancelAfter {
            DispatchQueue.global().asyncAfter(deadline: .now() + cancelAfter) {
                stream.process.terminate()
            }
        }

        wait(for: [ended], timeout: 8)
        lock.lock(); defer { lock.unlock() }
        return Run(
            result: result,
            stdout: stdout,
            stderrChunks: stderrChunks,
            elapsed: Date().timeIntervalSince(started)
        )
    }

    func testCapturesStdoutAndExitCode() {
        let run = run(#"printf 'one\ntwo\n'"#)
        XCTAssertEqual(run.result?.exitCode, 0)
        XCTAssertEqual(run.result?.timedOut, false)
        XCTAssertEqual(run.stdout, "one\ntwo\n")
        XCTAssertEqual(run.result?.stderr, "")
    }

    func testSeparatesStdoutAndStderr() {
        let run = run(#"printf 'out'; printf 'err' >&2"#)
        XCTAssertEqual(run.stdout, "out")
        XCTAssertEqual(run.stderrChunks, "err")
        XCTAssertEqual(run.result?.stderr, "err")
    }

    func testTimeoutKillsChild() {
        let run = run("exec sleep 5", timeout: 0.3)
        XCTAssertEqual(run.result?.timedOut, true)
        XCTAssertLessThan(run.elapsed, 4)
        XCTAssertNotEqual(run.result?.exitCode, 0)
    }

    func testStderrFloodDoesNotDeadlock() {
        let run = run("yes x | head -c 131072 >&2; printf done")
        XCTAssertEqual(run.result?.exitCode, 0)
        XCTAssertEqual(run.stdout, "done")
        XCTAssertFalse(run.result?.timedOut ?? true)
        XCTAssertGreaterThanOrEqual(run.result?.stderr.count ?? 0, 131_072)
        XCTAssertLessThan(run.elapsed, 6)
    }

    func testCancellationEndsRunWithoutTimeout() {
        let run = run("exec sleep 5", cancelAfter: 0.2)
        XCTAssertEqual(run.result?.timedOut, false)
        XCTAssertNotEqual(run.result?.exitCode, 0)
        XCTAssertLessThan(run.elapsed, 4)
    }

    func testWritesStdinAndClosesIt() {
        let run = run("cat", stdin: "hello\n")
        XCTAssertEqual(run.stdout, "hello\n")
        XCTAssertEqual(run.result?.exitCode, 0)
    }

    func testExitFiresWhenCallerDropsTheStream() {
        let ended = expectation(description: "process exit")
        do {
            let stream = MoleStreamingProcess(
                executable: "/bin/sh",
                args: ["-c", "printf hi"],
                onStdout: { _ in },
                onExit: { _, _ in ended.fulfill() }
            )
            try? stream.start()
        } // The view models only retain `stream.process`, so onExit must survive this.
        wait(for: [ended], timeout: 5)
    }

    func testLineBufferFlushesTrailingPartialLineAtExit() {
        let ended = expectation(description: "process exit")
        let buffer = LineBuffer()
        let lock = NSLock()
        var flushed: String?

        let stream = MoleStreamingProcess(
            executable: "/bin/sh",
            args: ["-c", #"printf 'foo\nbar'"#],
            onStdout: { chunk in _ = buffer.append(chunk) },
            onExit: { _, _ in
                lock.lock(); flushed = buffer.flushPartial(); lock.unlock()
                ended.fulfill()
            }
        )

        XCTAssertNoThrow(try stream.start())
        wait(for: [ended], timeout: 8)

        lock.lock(); defer { lock.unlock() }
        XCTAssertEqual(flushed, "bar")
        XCTAssertEqual(buffer.snapshot().lines, ["foo", "bar"])
        XCTAssertEqual(buffer.snapshot().output, "foo\nbar")
    }
}
