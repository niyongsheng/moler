import Foundation

/// Parsers for `mo uninstall --list` (JSON) and `mo uninstall --dry-run` (text).
enum SoftwareUninstallParser {

    // MARK: - JSON: mo uninstall --list

    /// Parse the JSON output of `mo uninstall --list` into `[InstalledApp]`.
    static func parseAppListJSON(_ data: Data) -> [InstalledApp] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let path = dict["path"] as? String else { return nil }
            let bundleId = dict["bundle_id"] as? String ?? ""
            let sizeStr = dict["size"] as? String ?? "--"
            return InstalledApp(
                id: bundleId.isEmpty ? path : "\(bundleId)|\(path)",
                name: name,
                bundleId: bundleId,
                source: dict["source"] as? String ?? "App",
                uninstallName: dict["uninstall_name"] as? String ?? name,
                path: path,
                sizeStr: sizeStr,
                sizeBytes: parseBytes(sizeStr)
            )
        }
    }

    // MARK: - Text: mo uninstall --dry-run

    /// Parse the dry-run output (with NO_COLOR=1) into an `UninstallPreview`.
    ///
    /// Expected format:
    /// ```
    /// Files to be removed:
    ///
    /// ◎ Slack , 239.6MB
    ///   ✓ /Applications/Slack.app
    ///   ✓ ~/Library/Containers/com.slack.Slack/
    ///   ...
    /// ```
    static func parseDryRunOutput(_ text: String) -> UninstallPreview {
        var entries: [UninstallPreview.Entry] = []
        var inFileList = false

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Files to be removed") {
                inFileList = true
                continue
            }

            guard inFileList else { continue }
            if trimmed.hasPrefix("◎") { continue }
            if trimmed.hasPrefix("✓") || trimmed.hasPrefix("✔") {
                var path = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                // Mole appends the bundle size to the .app row:
                //   ✓ /Applications/X.app , 65.0MB
                if let suffix = path.range(
                    of: #"\s*,\s*[0-9.]+\s*[KMGT]?B\s*$"#,
                    options: .regularExpression
                ) {
                    path.removeSubrange(suffix)
                }
                guard path.hasPrefix("/") || path.hasPrefix("~") else { continue }
                entries.append(UninstallPreview.Entry(path: path, kind: classify(path)))
            }
        }

        return UninstallPreview(entries: entries)
    }

    // MARK: - Text: mo uninstall failure reason

    /// Extract a concise, user-facing reason from a failed `mo uninstall` run.
    ///
    /// Mole writes warnings on stdout (`requires the official … uninstaller`)
    /// and hard errors on stderr. Prefer a line that names the app and carries
    /// a failure keyword; fall back to the last keyword line, then the exit code.
    static func failureReason(from result: CapturedProcess, appName: String) -> String? {
        let text = result.stdout + "\n" + result.stderr
        let lines = text.components(separatedBy: .newlines)
            .map { stripAnsi($0).trimmingCharacters(in: .whitespaces) }
            // Skip preview rows (files to be removed) — a path such as
            // `/Applications/FailedApp.app` must not be mistaken for a reason.
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("✓") && !line.hasPrefix("✔")
                    && !line.hasPrefix("◎")
            }

        let keywords = [
            "requires the official", "cannot be removed", "could not",
            "failed", "error", "not permitted", "still running",
        ]
        let appLower = appName.lowercased()

        func matchesKeyword(_ line: String) -> Bool {
            let lower = line.lowercased()
            return keywords.contains { lower.contains($0) }
        }

        if let line = lines.last(where: {
            $0.lowercased().contains(appLower) && matchesKeyword($0)
        }) {
            return clipped(line)
        }
        if let line = lines.last(where: matchesKeyword) {
            return clipped(line)
        }
        if result.exitCode != 0 {
            return "mo exited with code \(result.exitCode)"
        }
        return nil
    }

    private static func clipped(_ line: String) -> String {
        String(line.prefix(180))
    }

    /// Remove ANSI CSI sequences so reasons render cleanly in SwiftUI.
    static func stripAnsi(_ text: String) -> String {
        let ns = text as NSString
        return ansiPattern.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: ""
        )
    }

    private static let ansiPattern = try! NSRegularExpression(
        pattern: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
    )

    // MARK: - Classification

    /// Classify a file path into an `UninstallPreview.Kind`.
    /// Order matters: .application (suffix) before .container (substring).
    static func classify(_ rawPath: String) -> UninstallPreview.Kind {
        let path = rawPath.hasPrefix("~")
            ? (rawPath as NSString).expandingTildeInPath
            : rawPath

        if path.hasSuffix(".app") { return .application }
        if path.contains("/Library/Group Containers/") { return .groupContainer }
        if path.contains("/Library/Containers/") { return .container }
        if path.contains("/Library/Application Scripts/") { return .helper }
        if path.contains("/Library/Application Support/") { return .appSupport }
        if path.contains("/Library/Preferences/") { return .preferences }
        if path.contains("/Library/LaunchAgents/") || path.contains("/Library/LaunchDaemons/") { return .loginItem }
        if path.contains("/Library/Caches/") || path.contains("/var/folders/") || path.contains("/private/var/folders/") { return .cache }
        if path.contains("/Library/Logs/") { return .log }
        return .other
    }
}

// MARK: - Size parsing helper

/// Parse a size string like "239.6MB" or "1.08GB" or "--" into bytes.
private func parseBytes(_ text: String) -> Int64 {
    let t = text.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty, t != "--" else { return 0 }
    return parseSizeBytes(t)
}
