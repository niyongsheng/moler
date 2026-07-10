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
                let path = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                guard path.hasPrefix("/") || path.hasPrefix("~") else { continue }
                entries.append(UninstallPreview.Entry(path: path, kind: classify(path)))
            }
        }

        return UninstallPreview(entries: entries)
    }

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
