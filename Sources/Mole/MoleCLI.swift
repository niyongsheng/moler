import Foundation

/// Locates and vends metadata about the `mo` CLI binary.
/// Mole is a required runtime dependency; the app is useless without it.
enum MoleCLI {

    // MARK: - Discovery

    /// Find the `mo` executable. Checks known install locations first, then
    /// falls back to `which mo` via the shell (for GUI-launched cases where
    /// Homebrew's bin dir isn't in the inherited PATH).
    static func findExecutable() -> String? {
        // Known install locations — fastest path, works even when PATH
        // is `/usr/bin:/bin:/usr/sbin:/sbin` (GUI launch default).
        let trusted = [
            "/opt/homebrew/bin/mo",      // Apple Silicon Homebrew
            "/usr/local/bin/mo",          // Intel Homebrew / manual
        ]
        for path in trusted where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // Fallback: ask the shell
        if let path = try? runWhichMo() {
            return path
        }
        return nil
    }

    private static func runWhichMo() throws -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "mo"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !result.isEmpty,
              FileManager.default.isExecutableFile(atPath: result) else { return nil }
        return result
    }

    // MARK: - Version

    /// Parse the `mo --version` output into a semver string (e.g. "1.39.1").
    static func version() -> String? {
        guard let output = try? capture(args: ["--version"], timeout: 5) else {
            return nil
        }
        let text = output.stdout.isEmpty ? output.stderr : output.stdout
        for token in text.split(whereSeparator: { !($0.isNumber || $0 == ".") }) {
            let parts = token.split(separator: ".")
            if parts.count >= 2, parts.allSatisfy({ Int($0) != nil }) {
                return String(token)
            }
        }
        return nil
    }

    /// Canonical install command shown to users when `mo` is missing.
    static let installCommand = "brew install mole"
    static let repoURL = URL(string: "https://github.com/tw93/Mole")!

    // MARK: - Low-level capture

    /// Run `mo` with the given args and capture stdout + stderr.
    /// Blocks until exit. Callers must run on a background queue.
    static func capture(args: [String], stdin: String? = nil, timeout: TimeInterval = 10) throws -> CapturedProcess {
        guard let mo = findExecutable() else {
            throw MoleError.notFound
        }
        return try MoleProcess.run(
            executable: mo,
            args: args,
            stdin: stdin,
            timeout: timeout
        )
    }
}

// MARK: - Types

/// Result of a captured process invocation.
struct CapturedProcess {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    var timedOut: Bool = false
}

/// Errors when interacting with the Mole CLI.
enum MoleError: Error, LocalizedError {
    case notFound
    case failed(exitCode: Int32, stderr: String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return L10n.errorMoNotFound
        case .failed(let code, let stderr):
            return String(format: L10n.errorMoFailed, code, String(stderr.prefix(200)))
        case .parseFailed(let msg):
            return String(format: L10n.errorParseFailed, msg)
        }
    }
}
