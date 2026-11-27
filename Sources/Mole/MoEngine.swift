import Foundation

/// Facade for captured (non-streaming) `mo` commands.
/// Streaming runs (clean/purge/optimize) use `MoleCLI.stream` and keep their
/// state in the feature view models.
final class MoEngine {
    static let shared = MoEngine()

    private init() {}

    // MARK: Uninstall

    /// List installed apps via `mo uninstall --list`.
    func uninstallList() throws -> CapturedProcess {
        try MoleCLI.capture(
            args: ["uninstall", "--list"],
            timeout: 180,
            env: ["NO_COLOR": "1"]
        )
    }

    /// Preview what files would be removed for a given app.
    func uninstallDryRun(name: String) throws -> CapturedProcess {
        try MoleCLI.capture(
            args: ["uninstall", "--dry-run", name],
            stdin: "y\n",
            timeout: 30,
            env: ["NO_COLOR": "1"]
        )
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
