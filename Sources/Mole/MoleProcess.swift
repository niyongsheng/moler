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
        timeout: TimeInterval = 10
    ) throws -> CapturedProcess {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args

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

        // Drain stderr concurrently so it can't fill and block the child.
        var errData = Data()
        let errQueue = DispatchQueue(label: "dev.moler.process.err")
        errQueue.async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        }

        // Write stdin and close so child sees EOF.
        if let inPipe, let stdin, let data = stdin.data(using: .utf8) {
            let handle = inPipe.fileHandleForWriting
            try? handle.write(contentsOf: data)
            try? handle.close()
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

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        killer.cancel()
        errQueue.sync {}

        return CapturedProcess(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: task.terminationStatus,
            timedOut: timedOut
        )
    }
}
