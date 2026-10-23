import Foundation

// MARK: - Command Shape

/// Describes one `mo` invocation.
struct MoCommand {
    let args: [String]
    let stdin: String?
    let timeout: TimeInterval
    let env: [String: String]?

    init(args: [String], stdin: String? = nil, timeout: TimeInterval = 10, env: [String: String]? = nil) {
        self.args = args
        self.stdin = stdin
        self.timeout = timeout
        self.env = env
    }
}

// MARK: - Facade

/// The single entry point for all `mo` CLI interactions.
/// For MVP: capture (analyze) + streaming (clean).
final class MoEngine {
    static let shared = MoEngine()

    private init() {}

    // MARK: Availability

    /// Whether `mo` is installed and where.
    func availability() -> MoleAvailability {
        if let path = MoleCLI.findExecutable() {
            return .installed(path: path)
        }
        return .missing
    }

    /// Check that mo is installed; throw if not.
    func requireInstalled() throws -> String {
        guard case .installed(let path) = availability() else {
            throw MoleError.notFound
        }
        return path
    }

    // MARK: Capture (blocking commands)

    /// Run a captured command and return its result. Blocks — call off main thread.
    @discardableResult
    func capture(_ command: MoCommand) throws -> CapturedProcess {
        try MoleCLI.capture(
            args: command.args,
            stdin: command.stdin,
            timeout: command.timeout,
            env: command.env
        )
    }

    // MARK: Scan

    /// Run `mo analyze --json <path>` and return typed results.
    func analyze(path: String = FileManager.default.homeDirectoryForCurrentUser.path) throws -> DiskScanResult {
        try DiskScanner.scan(path)
    }

    // MARK: Clean

    /// Run `mo clean --dry-run` to preview what would be cleaned.
    /// Returns the raw output for parsing.
    func cleanDryRun() throws -> CapturedProcess {
        try capture(MoCommand(args: ["clean", "--dry-run"], timeout: 120))
    }

    /// Run `mo clean` for real. Returns streaming-style capture.
    /// This is a destructive operation — callers must gate behind user confirmation.
    func clean() throws -> CapturedProcess {
        try capture(MoCommand(args: ["clean"], timeout: 300))
    }

    // MARK: Optimize

    /// Run `mo optimize --dry-run` to preview optimizations.
    func optimizeDryRun() throws -> CapturedProcess {
        try capture(MoCommand(args: ["optimize", "--dry-run"], timeout: 120))
    }

    /// Run `mo optimize` for real. Returns streaming-style capture.
    func optimize() throws -> CapturedProcess {
        try capture(MoCommand(args: ["optimize"], timeout: 300))
    }

    // MARK: Uninstall

    /// List installed apps via `mo uninstall --list`.
    func uninstallList() throws -> CapturedProcess {
        try capture(MoCommand(args: ["uninstall", "--list"], timeout: 180))
    }

    /// Preview what files would be removed for a given app.
    func uninstallDryRun(name: String) throws -> CapturedProcess {
        try capture(MoCommand(args: ["uninstall", "--dry-run", name],
                              stdin: "y\n", timeout: 30,
                              env: ["NO_COLOR": "1"]))
    }

    /// Uninstall an app using `mo uninstall <name>`.
    ///
    /// Mole V1.62.0+ requires an interactive terminal for the confirmation
    /// prompt, so this one command needs a PTY on stdin instead of a pipe.
    func uninstall(name: String) throws -> CapturedProcess {
        guard let mo = MoleCLI.findExecutable() else { throw MoleError.notFound }
        return try MolePTYProcess.run(
            executable: mo,
            args: ["uninstall", name],
            confirmationMarker: "Enter confirm",
            timeout: 300,
            env: ["NO_COLOR": "1"]
        )
    }
}

// MARK: - Availability

enum MoleAvailability: Equatable {
    case installed(path: String)
    case missing
}
