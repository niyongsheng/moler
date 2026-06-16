import Foundation

// MARK: - Domain Models

/// A single file or directory found during a disk scan.
struct DiskScanEntry: Identifiable, Hashable {
    let id: String       // absolute path
    let name: String     // display name (last path component)
    let path: String     // full absolute path
    let size: Int64      // bytes; for dirs this is the recursive aggregate
    let isDir: Bool

    /// File kind for colour grouping (extension or "<dir>").
    var kind: String {
        if isDir { return "<dir>" }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ext.isEmpty ? "<none>" : ext
    }
}

/// The result of a `mo analyze --json` scan at a single directory level.
struct DiskScanResult {
    let path: String
    let totalSize: Int64
    let totalFiles: Int
    let entries: [DiskScanEntry]
    let scannedAt: Date

    /// 5-minute staleness threshold (TOCTOU prevention)
    static let stalenessInterval: TimeInterval = 300
    var isStale: Bool { Date().timeIntervalSince(scannedAt) > Self.stalenessInterval }
}

// MARK: - Scanner

/// Wraps `mo analyze --json` to produce typed disk scan results.
/// Callers must invoke `scan` on a background queue (it blocks).
enum DiskScanner {

    /// Scan a single directory level via `mo analyze --json <path>`.
    /// Returns aggregated sizes for each direct child.
    static func scan(_ path: String = FileManager.default.homeDirectoryForCurrentUser.path) throws -> DiskScanResult {
        guard let mo = MoleCLI.findExecutable() else {
            throw MoleError.notFound
        }

        let result = try MoleProcess.run(
            executable: mo,
            args: ["analyze", "--json", path],
            timeout: 300 // 5-minute timeout for large scans
        )

        guard result.exitCode == 0 else {
            throw MoleError.failed(exitCode: result.exitCode, stderr: result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw MoleError.parseFailed("Non-UTF8 output from mo analyze")
        }

        return try parse(data)
    }

    // MARK: - JSON Parsing

    /// Decode mo's JSON output into `DiskScanResult`.
    /// Loose decoding — unknown fields are ignored so upstream changes are safe.
    static func parse(_ data: Data) throws -> DiskScanResult {
        let raw: [String: Any]
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MoleError.parseFailed("Expected JSON object")
            }
            raw = dict
        } catch let error as MoleError {
            throw error
        } catch {
            throw MoleError.parseFailed(error.localizedDescription)
        }

        let path = raw["path"] as? String ?? "?"
        let totalSize = (raw["total_size"] as? Int64) ?? Int64(raw["total_size"] as? Int ?? 0)
        let totalFiles = raw["total_files"] as? Int ?? 0
        let entriesRaw = raw["entries"] as? [[String: Any]] ?? []

        var entries: [DiskScanEntry] = []
        entries.reserveCapacity(entriesRaw.count)
        for e in entriesRaw {
            guard let name = e["name"] as? String,
                  let path = e["path"] as? String else { continue }
            let size = (e["size"] as? Int64) ?? Int64(e["size"] as? Int ?? 0)
            let isDir = e["is_dir"] as? Bool ?? false

            entries.append(DiskScanEntry(
                id: path,
                name: name,
                path: path,
                size: size,
                isDir: isDir
            ))
        }
        // Largest first — natural sort that matches mo's own TUI.
        entries.sort { $0.size > $1.size }

        return DiskScanResult(
            path: path,
            totalSize: totalSize,
            totalFiles: totalFiles,
            entries: entries,
            scannedAt: Date()
        )
    }
}
