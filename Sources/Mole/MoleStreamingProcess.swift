import Foundation

/// Result of a streaming process run. Stdout is delivered through `onStdout`.
struct StreamedProcessResult {
    let exitCode: Int32
    let terminationReason: Process.TerminationReason
    let timedOut: Bool
    let stderr: String
}

/// A `Process` whose stdout/stderr are delivered as chunks while it runs.
///
/// Callers assign `process` to their state *before* calling `start()`, so the
/// exit callback can verify it still owns the current run. Callbacks fire on
/// background threads; hop to the main actor before touching UI state.
final class MoleStreamingProcess {

    let process = Process()

    private let outPipe = Pipe()
    private let errPipe = Pipe()
    private let inPipe: Pipe?
    private let stdinData: Data?
    private let onStdout: (String) -> Void
    private let onStderr: ((String) -> Void)?
    private let onExit: (StreamedProcessResult, Process) -> Void
    private let timeout: TimeInterval?

    private let stateLock = NSLock()
    private var stderrData = Data()
    private var timedOut = false
    private var killer: DispatchWorkItem?

    init(
        executable: String,
        args: [String],
        stdin: String? = nil,
        timeout: TimeInterval? = nil,
        env: [String: String]? = nil,
        onStdout: @escaping (String) -> Void,
        onStderr: ((String) -> Void)? = nil,
        onExit: @escaping (StreamedProcessResult, Process) -> Void
    ) {
        self.onStdout = onStdout
        self.onStderr = onStderr
        self.onExit = onExit
        self.timeout = timeout
        self.stdinData = stdin.flatMap { $0.data(using: .utf8) }
        self.inPipe = stdin == nil ? nil : Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        if let env {
            var merged = ProcessInfo.processInfo.environment
            for (key, value) in env { merged[key] = value }
            process.environment = merged
        }

        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = inPipe ?? FileHandle.nullDevice

        outPipe.fileHandleForReading.readabilityHandler = { [onStdout] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                // EOF: unregister, or Foundation re-fires forever.
                handle.readabilityHandler = nil
                return
            }
            onStdout(String(data: data, encoding: .utf8) ?? "")
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else {
                handle.readabilityHandler = nil
                return
            }
            self.appendStderr(data)
            self.onStderr?(String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Start the child, feed optional stdin, and begin draining both pipes.
    func start() throws {
        if let timeout {
            let killer = DispatchWorkItem { [weak self] in
                guard let self, self.process.isRunning else { return }
                self.markTimedOut()
                self.process.terminate()
            }
            self.killer = killer
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + timeout, execute: killer
            )
        }

        do {
            try process.run()
        } catch {
            stopReading()
            killer?.cancel()
            throw error
        }

        // The child holds its own descriptors now. Closing the parent's write
        // ends lets the readability handlers (and readToEnd) see EOF promptly.
        try? outPipe.fileHandleForWriting.close()
        try? errPipe.fileHandleForWriting.close()

        // Write stdin and close so the child sees EOF.
        if let inPipe, let stdinData {
            try? inPipe.fileHandleForWriting.write(contentsOf: stdinData)
            try? inPipe.fileHandleForWriting.close()
        }

        // Strong capture: the stream owns the process lifetime, so `onExit`
        // always fires even when the caller only keeps the `Process` handle.
        Task.detached(priority: .userInitiated) {
            self.process.waitUntilExit()
            self.killer?.cancel()
            self.stopReading()

            // Drain whatever arrived between the last callback and exit.
            if let remaining = try? self.outPipe.fileHandleForReading.readToEnd(),
               let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                self.onStdout(text)
            }
            if let remaining = try? self.errPipe.fileHandleForReading.readToEnd(),
               !remaining.isEmpty {
                self.appendStderr(remaining)
                if let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                    self.onStderr?(text)
                }
            }

            let result = StreamedProcessResult(
                exitCode: self.process.terminationStatus,
                terminationReason: self.process.terminationReason,
                timedOut: self.isTimedOut,
                stderr: self.stderrText
            )
            self.onExit(result, self.process)
        }
    }

    // MARK: - Pipe lifecycle

    private func stopReading() {
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
    }

    // MARK: - Shared state

    private func markTimedOut() {
        stateLock.lock(); defer { stateLock.unlock() }
        timedOut = true
    }

    private var isTimedOut: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return timedOut
    }

    private func appendStderr(_ data: Data) {
        stateLock.lock(); defer { stateLock.unlock() }
        stderrData.append(data)
    }

    private var stderrText: String {
        stateLock.lock(); defer { stateLock.unlock() }
        return String(data: stderrData, encoding: .utf8) ?? ""
    }
}
