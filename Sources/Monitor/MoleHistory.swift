import Foundation

/// One completed `mo` operation from `mo history --json`.
///
/// Mole logs clean/uninstall/optimize/purge/installer runs (including ones
/// started by Moler) in `~/Library/Logs/mole/operations.log`, so this is the
/// only place the app can see CLI activity too. Dry runs are filtered out.
struct MoleHistorySession: Codable, Identifiable, Equatable {
    let command: String
    let runId: String
    let startedAt: String
    let endedAt: String
    let items: Int
    let size: String
    let operationCount: Int?
    let failedTasks: Int?
    let actions: MoleHistoryActions?

    var id: String { runId.isEmpty ? "\(command)|\(startedAt)" : runId }
    var isDryRun: Bool { command.hasSuffix("-dry-run") }

    var displayCommand: String {
        switch command {
        case "clean":          return "CLEAN"
        case "purge":          return "PURGE"
        case "optimize":       return "OPTIMIZE"
        case "uninstall":      return "UNINSTALL"
        case "installer":      return "INSTALLER"
        case "slim":           return "SLIM"
        case "clean-external": return "CLEAN EXT"
        default:               return command.uppercased()
        }
    }

    var startedDate: Date? { Self.dateFormatter.date(from: startedAt) }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    enum CodingKeys: String, CodingKey {
        case command
        case runId = "run_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case items, size
        case operationCount = "operation_count"
        case failedTasks = "failed_tasks"
        case actions
    }
}

struct MoleHistoryActions: Codable, Equatable {
    let removed: Int
    let trashed: Int
    let skipped: Int
    let failed: Int
    let rebuilt: Int
    let other: Int
}

private struct MoleHistorySnapshot: Codable {
    let sessions: [MoleHistorySession]
}

enum MoleHistoryLoader {

    /// Load non-dry-run sessions, newest first. Blocks — call off main thread.
    static func load(limit: Int = 20) throws -> [MoleHistorySession] {
        let result = try MoleCLI.capture(
            args: ["history", "--json", "--limit", "\(limit)"],
            timeout: 20,
            env: ["NO_COLOR": "1"]
        )
        guard result.exitCode == 0 else {
            throw MoleError.failed(exitCode: result.exitCode, stderr: result.stderr)
        }
        guard let data = result.stdout.data(using: .utf8) else {
            throw MoleError.parseFailed("Non-UTF8 output from mo history")
        }
        return try parse(data)
    }

    /// Decode `mo history --json` and drop dry runs / empty probe sessions.
    static func parse(_ data: Data) throws -> [MoleHistorySession] {
        let snapshot = try JSONDecoder().decode(MoleHistorySnapshot.self, from: data)
        return snapshot.sessions.filter { session in
            guard !session.isDryRun else { return false }
            // Skip no-op sessions that only appear because mo was probed.
            return !(session.items == 0 && session.size == "0B" && (session.failedTasks ?? 0) == 0)
        }
    }
}
