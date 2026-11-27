import Foundation
import AppKit

/// Downloads, verifies and installs a new Moler build in place.
///
/// The app is ad-hoc signed (no Developer ID), so updates are a plain
/// `Moler-<version>.zip` from the GitHub release. Before anything is
/// replaced we check the bundle identifier, version and that the ad-hoc
/// signature verifies. The actual swap runs from a detached shell script
/// after the app quits, because a running bundle cannot reliably replace
/// itself; when the app lives in `/Applications` the script asks for
/// administrator rights via a standard macOS authorization prompt.
enum UpdateInstaller {

    enum InstallError: LocalizedError {
        /// Running outside /Applications, from a read-only volume, or from
        /// App Translocation — self-replacement is not safe there.
        case unsupportedLocation
        case downloadFailed(status: Int)
        case archiveInvalid
        case versionMismatch(expected: String, found: String?)
        case signatureInvalid
        case launchFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedLocation:
                return L10n.updateManualOnly
            case .downloadFailed(let status):
                return "GitHub returned HTTP \(status)."
            case .archiveInvalid:
                return L10n.updateVerifyFailed
            case .versionMismatch(let expected, let found):
                return String(
                    format: L10n.updateVerifyFailedDetail,
                    "expected \(expected), found \(found ?? "?")"
                )
            case .signatureInvalid:
                return L10n.updateVerifyFailed
            case .launchFailed:
                return L10n.updateInstallFailedBody
            }
        }
    }

    // MARK: - Location

    /// The bundle being replaced. Symlinks are resolved so we edit the real
    /// copy, not a link pointing at it.
    static var appURL: URL {
        Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
    }

    /// True when Gatekeeper launched a randomized read-only copy of the app.
    static var isTranslocated: Bool {
        appURL.path.contains("/AppTranslocation/")
    }

    /// Self-update is only offered for copies in the user's Applications
    /// folder; running from Xcode/DerivedData or a DMG should not rewrite
    /// itself. Homebrew Cask installs into /Applications and qualifies.
    static var canInstall: Bool {
        guard !isTranslocated else { return false }
        let path = appURL.path
        let inApplications = path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        guard inApplications else { return false }
        let readOnly = (try? appURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?
            .volumeIsReadOnly ?? false
        return !readOnly
    }

    // MARK: - Download

    /// Create a private scratch directory for this update run.
    static func makeWorkDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MolerUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Download `url` into `directory` with progress in 0...1.
    static func download(
        _ url: URL,
        to directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let destination = directory.appendingPathComponent("MolerUpdate.zip")
        let delegate = DownloadDelegate(destination: destination, progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    // MARK: - Staging & Verification

    /// Unzip the downloaded archive and verify the contained app.
    /// Blocking — call from a background task.
    static func stage(
        zip: URL,
        in directory: URL,
        expectedVersion: String,
        expectedBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) throws -> URL {
        let extracted = directory.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        try runTool("/usr/bin/ditto", ["-x", "-k", zip.path, extracted.path])

        // New archives put Moler.app at the root, but releases built before
        // the CI fix nested it under `.build/Build/Products/Release/`, so
        // search the whole tree for the matching bundle (hidden dirs included).
        guard let app = findApp(
            in: extracted,
            expectedVersion: expectedVersion,
            bundleIdentifier: expectedBundleIdentifier
        ), let bundle = Bundle(url: app) else {
            throw InstallError.archiveInvalid
        }

        let found = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let found, normalizedVersion(found) == normalizedVersion(expectedVersion) else {
            throw InstallError.versionMismatch(expected: expectedVersion, found: found)
        }

        guard let executable = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
              FileManager.default.isExecutableFile(
                atPath: app.appendingPathComponent("Contents/MacOS/\(executable)").path
              ) else {
            throw InstallError.archiveInvalid
        }

        // The CI build is ad-hoc signed. A valid signature here means the
        // archive was not corrupted between CI and this Mac.
        do {
            try runTool("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        } catch {
            throw InstallError.signatureInvalid
        }

        return app
    }

    /// Locate the Moler bundle inside an extracted archive, wherever the
    /// archive placed it. Hidden paths are included on purpose: releases
    /// built before the CI fix embedded `.build/Build/Products/Release/`.
    private static func findApp(
        in directory: URL,
        expectedVersion: String,
        bundleIdentifier: String?
    ) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return nil }

        var fallback: URL?
        for case let url as URL in enumerator where url.pathExtension == "app" {
            let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            guard let bundle = Bundle(url: url),
                  bundle.bundleIdentifier == bundleIdentifier else { continue }
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            if let version, normalizedVersion(version) == normalizedVersion(expectedVersion) {
                return url
            }
            fallback = fallback ?? url
        }
        return fallback
    }

    private static func runTool(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw InstallError.launchFailed
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw InstallError.archiveInvalid
        }
    }

    // MARK: - Install

    /// Hand the verified app to a detached helper that waits for this
    /// process to exit, swaps the bundle, clears quarantine and relaunches.
    /// The caller should terminate the app right after this returns.
    static func beginInstall(stagedApp: URL, workDirectory: URL) throws {
        guard canInstall else { throw InstallError.unsupportedLocation }

        let target = appURL
        let parent = target.deletingLastPathComponent()
        let needsAdmin = !(FileManager.default.isWritableFile(atPath: parent.path)
            && FileManager.default.isWritableFile(atPath: target.path))

        let script = workDirectory.appendingPathComponent("install.sh")
        try Self.script.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: script.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            script.path,
            String(ProcessInfo.processInfo.processIdentifier),
            target.path,
            stagedApp.path,
            needsAdmin ? "1" : "0",
            L10n.updateAdminPrompt,
            workDirectory.path,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw InstallError.launchFailed
        }
    }

    /// Runs detached. Arguments:
    ///   1 pid, 2 target app, 3 new app, 4 admin flag, 5 prompt, 6 work dir.
    /// The shell script itself contains no substituted paths — everything
    /// arrives through argv, so a path with spaces or quotes is harmless.
    private static let script = #"""
    #!/bin/sh
    set -u

    PID="$1"
    TARGET="$2"
    NEW="$3"
    ADMIN="$4"
    PROMPT="$5"
    WORKDIR="$6"
    LOG=/tmp/moler-update.log

    exec >>"$LOG" 2>&1
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') moler update (admin=$ADMIN)"
    echo "target=$TARGET"
    echo "new=$NEW"

    if [ "$ADMIN" = "1" ]; then
      /usr/bin/osascript - "$PID" "$TARGET" "$NEW" "$PROMPT" <<'APPLESCRIPT'
    on run argv
      set thePID to item 1 of argv
      set targetPath to item 2 of argv
      set newPath to item 3 of argv
      set thePrompt to item 4 of argv

      set qTarget to quoted form of targetPath
      set qNew to quoted form of newPath
      set parentDir to do shell script "/usr/bin/dirname " & qTarget
      set backupPath to parentDir & "/.Moler-old-" & thePID & ".app"
      set qBackup to quoted form of backupPath

      set waitCmd to "i=0; while /bin/kill -0 " & thePID & " 2>/dev/null; do i=$((i + 1)); if [ $i -ge 300 ]; then exit 2; fi; /bin/sleep 0.2; done; "
      set swapCmd to "/bin/mv " & qTarget & " " & qBackup & " && /usr/bin/ditto " & qNew & " " & qTarget & " && /bin/rm -rf " & qBackup
      set cleanupCmd to "/usr/bin/xattr -dr com.apple.quarantine " & qTarget & " 2>/dev/null || true"
      set restoreCmd to "if [ ! -e " & qTarget & " ] && [ -e " & qBackup & " ]; then /bin/mv " & qBackup & " " & qTarget & "; fi"
      set fullCmd to "if " & swapCmd & "; then " & cleanupCmd & "; exit 0; else " & restoreCmd & "; exit 1; fi"

      do shell script (waitCmd & fullCmd) with administrator privileges with prompt thePrompt
    end run
    APPLESCRIPT
      STATUS=$?
    else
      i=0
      while /bin/kill -0 "$PID" 2>/dev/null; do
        i=$((i + 1))
        if [ "$i" -ge 300 ]; then
          echo "timed out waiting for app to quit"
          /usr/bin/open "$TARGET"
          exit 1
        fi
        /bin/sleep 0.2
      done

      BACKUP="$(/usr/bin/dirname "$TARGET")/.Moler-old-$$.app"
      if /bin/mv "$TARGET" "$BACKUP" && /usr/bin/ditto "$NEW" "$TARGET"; then
        /bin/rm -rf "$BACKUP"
        /usr/bin/xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null
        STATUS=0
      else
        echo "swap failed"
        [ ! -e "$TARGET" ] && [ -e "$BACKUP" ] && /bin/mv "$BACKUP" "$TARGET"
        STATUS=1
      fi
    fi

    if [ "$STATUS" -eq 0 ]; then
      echo "installed; relaunching"
      /usr/bin/open "$TARGET"
    else
      echo "aborted (status $STATUS)"
      [ -d "$TARGET" ] && /usr/bin/open "$TARGET"
    fi

    /bin/rm -rf "$WORKDIR"
    """#
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let destination: URL
    let progress: @Sendable (Double) -> Void
    var continuation: CheckedContinuation<URL, Error>?

    private var movedURL: URL?
    private var failure: Error?

    init(destination: URL, progress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            failure = UpdateInstaller.InstallError.downloadFailed(status: http.statusCode)
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            movedURL = destination
        } catch {
            failure = error
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else if let failure {
            continuation.resume(throwing: failure)
        } else if let movedURL {
            continuation.resume(returning: movedURL)
        } else {
            continuation.resume(throwing: UpdateInstaller.InstallError.archiveInvalid)
        }
    }
}
