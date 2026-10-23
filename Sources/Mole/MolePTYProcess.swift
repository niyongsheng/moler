import Foundation
import Darwin

/// Runs a `mo` command with a pseudo-terminal on stdin.
///
/// Mole V1.62.0 started refusing real uninstalls when stdin is not a TTY
/// (`mo uninstall` prints its preview, then returns 3 without removing
/// anything). A plain pipe can no longer satisfy that check, so we hand the
/// child a PTY and answer its single-key confirmation ourselves.
///
/// The PTY is only attached to stdin and never becomes the child's
/// controlling terminal, so `/dev/tty` stays unavailable — which keeps
/// Mole's sudo path on its existing behaviour (it cannot prompt for a
/// password on a terminal we are not showing).
enum MolePTYProcess {

    /// Spawn `executable` with a PTY on stdin.
    ///
    /// - Parameters:
    ///   - confirmationMarker: text in stdout that marks the confirmation
    ///     prompt. A newline is written to the PTY shortly after it appears.
    ///   - timeout: kill the child if it has not exited by then.
    static func run(
        executable: String,
        args: [String],
        confirmationMarker: String,
        timeout: TimeInterval,
        env: [String: String]? = nil
    ) throws -> CapturedProcess {
        // O_NOCTTY on both ends: opening the slave must not give this app a
        // controlling terminal (a GUI app normally has none).
        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0 else { throw ptyError() }
        guard grantpt(master) == 0, unlockpt(master) == 0,
              let slaveName = ptsname(master) else {
            close(master)
            throw ptyError()
        }
        let slave = open(slaveName, O_RDWR | O_NOCTTY)
        guard slave >= 0 else {
            close(master)
            throw ptyError()
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args

        if let env {
            var merged = ProcessInfo.processInfo.environment
            for (k, v) in env { merged[k] = v }
            task.environment = merged
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        let masterHandle = FileHandle(fileDescriptor: master, closeOnDealloc: false)
        task.standardInput = slaveHandle
        task.standardOutput = outPipe
        task.standardError = errPipe

        // All master-fd access (the delayed keystroke and the final close)
        // happens on this serial queue so a late write can never touch a
        // closed — or reused — descriptor.
        let ptyQueue = DispatchQueue(label: "dev.niyongsheng.moler.pty")
        var masterOpen = true
        var confirmationScheduled = false

        var outData = Data()
        var errData = Data()
        let drainGroup = DispatchGroup()
        drainGroup.enter()
        drainGroup.enter()

        // Match the prompt across chunk boundaries without keeping a second
        // copy of the whole (potentially large) log around.
        let marker = confirmationMarker.lowercased()
        var markerTail = ""

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                outPipe.fileHandleForReading.readabilityHandler = nil
                drainGroup.leave()
                return
            }
            outData.append(chunk)

            guard !confirmationScheduled else { return }
            let text = (markerTail + (String(data: chunk, encoding: .utf8) ?? "")).lowercased()
            markerTail = String(text.suffix(marker.count * 2))
            guard text.contains(marker) else { return }
            confirmationScheduled = true

            // Mole drains pending input immediately before reading the key,
            // so an Enter sent before that finishes would be discarded.
            ptyQueue.asyncAfter(deadline: .now() + 0.2) {
                guard masterOpen else { return }
                try? masterHandle.write(contentsOf: Data("\n".utf8))
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

        do {
            try task.run()
        } catch {
            try? slaveHandle.close()
            try? masterHandle.close()
            throw error
        }
        // The child has its own copy of the slave; the parent's is redundant.
        try? slaveHandle.close()

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

        _ = drainGroup.wait(timeout: .now() + 2)

        ptyQueue.sync {
            guard masterOpen else { return }
            masterOpen = false
            try? masterHandle.close()
        }

        return CapturedProcess(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: task.terminationStatus,
            timedOut: timedOut
        )
    }

    private static func ptyError() -> NSError {
        NSError(
            domain: "MolePTYProcess",
            code: Int(errno),
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Failed to allocate a pseudo-terminal: \(String(cString: strerror(errno)))"
            ]
        )
    }
}
