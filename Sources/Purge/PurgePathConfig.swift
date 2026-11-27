import Foundation

/// Reads and writes Mole's purge search-path config.
///
/// `mo purge` scans the directories listed in `~/.config/mole/purge_paths`
/// (one per line, `~` supported). An empty or missing file falls back to the
/// built-in default paths, and on first run Mole may auto-discover project
/// directories and save them there. The file is shared with the CLI — the
/// Moler UI edits the same list `mo purge --paths` does.
enum PurgePathConfig {

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mole/purge_paths")
    }

    /// Mole 1.74's default search roots. Used only for display and for
    /// pre-selecting paths; the CLI remains the source of truth at run time.
    static let defaultPaths: [String] = [
        "~/www",
        "~/dev",
        "~/Projects",
        "~/GitHub",
        "~/Code",
        "~/Workspace",
        "~/Repos",
        "~/Development",
        "~/Developer",
        "~/Library/CloudStorage",
        "~/.codex/worktrees",
        "~/.claude/worktrees",
        "~/.t3/worktrees",
    ].map { ($0 as NSString).expandingTildeInPath }

    /// Active (non-comment, non-empty) paths.
    /// - Returns: `nil` when the file does not exist or cannot be read.
    static func read() -> [String]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        return activePaths(in: text)
    }

    static func activePaths(in text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            return (trimmed as NSString).expandingTildeInPath
        }
    }

    /// Replace the config with the given paths. Writes absolute paths.
    static func write(_ paths: [String]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )

        var text = """
        # Mole Purge Paths - shared by `mo purge` and Moler
        # One path per line (supports ~). Empty means Mole defaults.

        """
        for path in paths {
            text += path + "\n"
        }
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
