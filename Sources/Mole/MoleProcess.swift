import Foundation

/// Wraps Foundation `Process` for captured subprocess execution (small, short-lived
/// commands like `mo analyze --json`). For long-running streaming ops, use the
/// streaming port in MoEngine.
enum MoleProcess {

    /// Spawn the given executable with `args`, feed optional `stdin` and capture
    /// stdout + stderr. Blocks until exit or the timeout fires (on timeout the
    /// child is killed and `timedOut` is set; does NOT throw).
    static func run(
        executable: String,
        args: [String],
        stdin: String? = nil,
        timeout: TimeInterval = 10,
        env: [String: String]? = nil
    ) throws -> CapturedProcess {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args

        // Optional environment overrides
        if let env {
            var merged = ProcessInfo.processInfo.environment
            for (k, v) in env { merged[k] = v }
            task.environment = merged
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        // Optional stdin (e.g. "y\n" for confirmation prompts)
        let inPipe: Pipe? = stdin != nil ? Pipe() : nil
        if let inPipe {
            task.standardInput = inPipe
        }

        try task.run()

        // Write stdin and close so child sees EOF.
        if let inPipe, let stdin, let data = stdin.data(using: .utf8) {
            let handle = inPipe.fileHandleForWriting
            try? handle.write(contentsOf: data)
            try? handle.close()
        }

        // Drain stdout and stderr concurrently via readabilityHandler so
        // neither pipe buffer can fill and deadlock the child process.
        var outData = Data()
        var errData = Data()
        let drainGroup = DispatchGroup()
        drainGroup.enter()
        drainGroup.enter()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                // EOF — stop monitoring and signal completion
                outPipe.fileHandleForReading.readabilityHandler = nil
                drainGroup.leave()
            } else {
                outData.append(chunk)
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                errPipe.fileHandleForReading.readabilityHandler = nil
                drainGroup.leave()
            } else {
                errData.append(chunk)
            }
        }

        // Timeout: terminate the child if it runs too long.
        var timedOut = false
        let killer = DispatchWorkItem { [weak task] in
            if let task, task.isRunning {
                timedOut = true
                task.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: killer)

        task.waitUntilExit()
        killer.cancel()

        // Wait for both pipes to finish draining
        _ = drainGroup.wait(timeout: .now() + 2)

        return CapturedProcess(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: task.terminationStatus,
            timedOut: timedOut
        )
    }
}
