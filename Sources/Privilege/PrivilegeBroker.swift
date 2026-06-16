import Foundation

/// Executes commands with administrator privileges via osascript.
/// Used for operations that require root access (e.g., cleaning
/// system-level caches that are owned by root).
enum PrivilegeBroker {

    /// Run a command with administrator privileges via AppleScript.
    /// Shows the system password dialog (password only, not Touch ID).
    /// Returns the exit code. Blocks — call off the main thread.
    static func runElevated(executable: String, args: [String]) -> Int32 {
        let script = buildScript(executable: executable, args: args)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            // Log output for debugging
            let stdoutStr = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                   encoding: .utf8) ?? ""
            let stderrStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                   encoding: .utf8) ?? ""

            if task.terminationStatus != 0 {
                // User cancelled auth dialog → error -128
                if stderrStr.contains("User canceled") || task.terminationStatus == 1 {
                    return -128
                }
                fputs("[PrivilegeBroker] Elevated command failed (exit \(task.terminationStatus)): \(stderrStr.prefix(200))\n",
                      stderr)
            }
            return task.terminationStatus
        } catch {
            fputs("[PrivilegeBroker] Failed to spawn osascript: \(error)\n", stderr)
            return -1
        }
    }

    /// Build the AppleScript `do shell script ... with administrator privileges`.
    private static func buildScript(executable: String, args: [String]) -> String {
        func shQuote(_ s: String) -> String {
            "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let cmd = ([executable] + args).map(shQuote).joined(separator: " ")
        return "do shell script \"\(cmd)\" with administrator privileges"
    }
}
