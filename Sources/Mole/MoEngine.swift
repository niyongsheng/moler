import Foundation

// MARK: - Command Shape

/// Describes one `mo` invocation.
struct MoCommand {
    let args: [String]
    let stdin: String?
    let timeout: TimeInterval

    init(args: [String], stdin: String? = nil, timeout: TimeInterval = 10) {
        self.args = args
        self.stdin = stdin
        self.timeout = timeout
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
            timeout: command.timeout
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
}

// MARK: - Availability

enum MoleAvailability: Equatable {
    case installed(path: String)
    case missing
}
