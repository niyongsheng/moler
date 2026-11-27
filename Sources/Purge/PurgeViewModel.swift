import Foundation

enum PurgeState: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case review(plan: PurgePlan)
    case running(log: [String])
    case done(freedBytes: Int64, itemsRemoved: Int, itemsFailed: Int = 0)
}

/// A selectable scan root shown as a pill in the idle view.
struct ScanTarget: Identifiable, Equatable {
    let id: String           // unique key
    let name: String         // display name
    let path: String         // expanded path
    var isSelected: Bool     // whether the user has toggled it on
}

@MainActor
final class PurgeViewModel: ObservableObject {
    @Published var state: PurgeState = .idle
    @Published var errorMessage: String?

    /// Every path Moler knows about: Mole's defaults plus custom config paths.
    @Published var scanTargets: [ScanTarget] = []
    /// True when the active scope comes from Mole's defaults (no config file).
    @Published private(set) var usingDefaults = true

    // MARK: - Private

    private var scanProcess: Process?
    private var scanTimer: Timer?
    private var scanStartTime: Date?
    private var scanStopRequested = false
    private let scanBuffer = PurgeOutputBuffer()

    private var runProcess: Process?
    private let runBuffer = PurgeOutputBuffer()

    /// The UI edits Mole's shared purge_paths file; only write when the user
    /// actually changed the selection.
    private var selectionDirty = false

    private static let scanTimeout: TimeInterval = 600
    private static let runTimeout: TimeInterval = 600

    init() {
        rebuildTargets()
    }

    // MARK: - Scan Targets

    /// Rebuild the pill list from Mole's config.
    /// If the config has active paths they are the scope; otherwise all
    /// built-in defaults are active. Custom paths (not defaults) are appended.
    private func rebuildTargets() {
        let configured = PurgePathConfig.read() ?? []
        let effective = configured.isEmpty ? PurgePathConfig.defaultPaths : configured
        usingDefaults = configured.isEmpty
        let selected = Set(effective)

        var targets: [ScanTarget] = []
        for (index, path) in PurgePathConfig.defaultPaths.enumerated() {
            targets.append(ScanTarget(
                id: "default.\(index)",
                name: displayPath(path),
                path: path,
                isSelected: selected.contains(path)
            ))
        }

        var customIndex = 0
        for path in configured where !PurgePathConfig.defaultPaths.contains(path) {
            targets.append(ScanTarget(
                id: "custom.\(customIndex)",
                name: displayPath(path),
                path: path,
                isSelected: true
            ))
            customIndex += 1
        }

        scanTargets = targets
        selectionDirty = false
    }

    /// Add a custom scan directory and persist it.
    func addCustomPath(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { return }
        guard !scanTargets.contains(where: { $0.path == expanded }) else { return }

        scanTargets.append(ScanTarget(
            id: "custom.\(scanTargets.count)",
            name: displayPath(expanded),
            path: expanded,
            isSelected: true
        ))
        selectionDirty = true
        persistSelectionIfDirty()
    }

    /// Remove a custom target by id. Built-in defaults cannot be removed,
    /// but they can be deselected.
    func removeTarget(_ id: String) {
        guard id.hasPrefix("custom.") else { return }
        scanTargets.removeAll { $0.id == id }
        selectionDirty = true
        persistSelectionIfDirty()
    }

    func toggleTarget(_ id: String) {
        guard let index = scanTargets.firstIndex(where: { $0.id == id }) else { return }
        scanTargets[index].isSelected.toggle()
        selectionDirty = true
        persistSelectionIfDirty()
    }

    func selectAllTargets(_ select: Bool) {
        for index in scanTargets.indices {
            scanTargets[index].isSelected = select
        }
        selectionDirty = true
        if select { persistSelectionIfDirty() }
    }

    /// Whether a target id refers to a custom (user-added) entry.
    func isCustomTarget(_ id: String) -> Bool {
        id.hasPrefix("custom.")
    }

    /// Whether at least one target is selected.
    var hasSelectedTargets: Bool {
        scanTargets.contains(where: \.isSelected)
    }

    /// Whether the view model is currently in the scanning state.
    var isScanning: Bool { if case .scanning = state { true } else { false } }

    private func persistSelectionIfDirty() {
        guard selectionDirty else { return }
        let selected = scanTargets.filter(\.isSelected).map(\.path)
        // An empty config means "use Mole defaults", so never write zero paths.
        guard !selected.isEmpty else { return }
        do {
            try PurgePathConfig.write(selected)
            selectionDirty = false
        } catch {
            errorMessage = "Could not save purge paths: \(error.localizedDescription)"
        }
    }

    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }

    // MARK: - Scan

    /// Run `mo purge --dry-run` and show Mole's real artifact list.
    func startScan() {
        guard hasSelectedTargets else { return }
        persistSelectionIfDirty()
        cancelScanTask()
        errorMessage = nil
        scanStopRequested = false
        scanStartTime = Date()
        state = .scanning(progress: ScanProgress(
            currentItem: 0, totalItems: 0, currentPath: "", elapsedSeconds: 0, scannedBytes: 0
        ))

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, case .scanning(let p) = self.state else { return }
            let elapsed = Int(Date().timeIntervalSince(self.scanStartTime ?? Date()))
            self.state = .scanning(progress: ScanProgress(
                currentItem: p.currentItem, totalItems: p.totalItems,
                currentPath: p.currentPath, elapsedSeconds: elapsed,
                scannedBytes: p.scannedBytes
            ))
        }

        guard let mo = MoleCLI.findExecutable() else {
            scanTimer?.invalidate(); scanTimer = nil
            state = .idle
            errorMessage = L10n.errorMoNotFound
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: mo)
        task.arguments = ["purge", "--dry-run"]
        task.standardInput = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        task.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        // Drain stderr so a chatty child can never block on a full pipe.
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty {
                errPipe.fileHandleForReading.readabilityHandler = nil
            }
        }

        let buffer = scanBuffer
        buffer.reset()

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""
            let snapshot = buffer.append(chunk)

            Task { @MainActor [weak self] in
                guard let self, case .scanning(let p) = self.state else { return }
                self.state = .scanning(progress: ScanProgress(
                    currentItem: snapshot.successCount,
                    totalItems: 0,
                    currentPath: snapshot.lastLine,
                    elapsedSeconds: p.elapsedSeconds,
                    scannedBytes: p.scannedBytes
                ))
            }
        }

        let killer = DispatchWorkItem {
            buffer.markTimedOut()
            task.terminate()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + Self.scanTimeout, execute: killer
        )

        do {
            try task.run()
            scanProcess = task

            Task.detached(priority: .userInitiated) { [weak self] in
                task.waitUntilExit()
                killer.cancel()
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                if let remaining = try? outPipe.fileHandleForReading.readToEnd(),
                   let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                    _ = buffer.append(text)
                }

                let snapshot = buffer.snapshot()
                let plan = PurgePlanParser.parse(snapshot.output)
                let status = task.terminationStatus

                await MainActor.run { [weak self] in
                    guard let self, self.scanProcess === task else { return }
                    self.scanProcess = nil
                    self.scanTimer?.invalidate(); self.scanTimer = nil

                    // Mole may have discovered and saved paths on first run.
                    self.rebuildTargets()

                    if plan.isEmpty && status != 0 && !self.scanStopRequested {
                        self.state = .idle
                        self.errorMessage = snapshot.timedOut
                            ? String(format: L10n.errorTimedOut, Int(Self.scanTimeout) / 60)
                            : String(format: L10n.errorMoFailed, status, "")
                    } else {
                        self.state = .review(plan: plan)
                        self.errorMessage = nil
                    }
                }
            }
        } catch {
            scanTimer?.invalidate(); scanTimer = nil
            state = .idle
            errorMessage = error.localizedDescription
        }
    }

    /// Stop the preview and review what was parsed so far.
    func stopScan() {
        scanStopRequested = true
        scanTimer?.invalidate(); scanTimer = nil
        scanProcess?.terminate()
    }

    /// Discard the preview and return to idle.
    func cancelScan() {
        cancelScanTask()
        scanTimer?.invalidate(); scanTimer = nil
        state = .idle
        errorMessage = nil
    }

    private func cancelScanTask() {
        let process = scanProcess
        scanProcess = nil
        process?.terminate()
    }

    // MARK: - Purge

    /// Run `mo purge --yes`. Mole re-checks in-use protection at deletion
    /// time, skips recent and cloud-synced artifacts in unattended mode, and
    /// writes a session summary we parse for the result screen.
    func startPurge() {
        guard case .review(let plan) = state, !plan.isEmpty else { return }
        state = .running(log: [])
        runBuffer.reset()

        guard let mo = MoleCLI.findExecutable() else {
            state = .idle
            errorMessage = L10n.errorMoNotFound
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: mo)
        task.arguments = ["purge", "--yes"]
        task.standardInput = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        task.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        let buffer = runBuffer
        let handler: (FileHandle) -> Void = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""
            let snapshot = buffer.append(chunk)

            Task { @MainActor [weak self] in
                guard let self, case .running = self.state else { return }
                self.state = .running(log: snapshot.lines)
            }
        }
        outPipe.fileHandleForReading.readabilityHandler = handler
        errPipe.fileHandleForReading.readabilityHandler = handler

        let killer = DispatchWorkItem {
            buffer.markTimedOut()
            task.terminate()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + Self.runTimeout, execute: killer
        )

        do {
            try task.run()
            runProcess = task

            Task.detached(priority: .userInitiated) { [weak self] in
                task.waitUntilExit()
                killer.cancel()
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                for pipe in [outPipe, errPipe] {
                    if let remaining = try? pipe.fileHandleForReading.readToEnd(),
                       let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                        _ = buffer.append(text)
                    }
                }

                let snapshot = buffer.snapshot()
                let summary = PurgePlanParser.parseRunSummary(snapshot.output)
                let status = task.terminationStatus
                let skipped = snapshot.lines.filter {
                    $0.hasPrefix("◎") && $0.localizedCaseInsensitiveContains("Skipped")
                }.count

                await MainActor.run { [weak self] in
                    guard let self, self.runProcess === task else { return }
                    self.runProcess = nil

                    if snapshot.timedOut {
                        self.state = .idle
                        self.errorMessage = String(
                            format: L10n.errorTimedOut, Int(Self.runTimeout) / 60
                        )
                        return
                    }

                    // A normal run can exit 1 when the outcome is
                    // "Purge incomplete" while still printing valid totals.
                    guard let summary else {
                        self.state = .idle
                        self.errorMessage = String(format: L10n.errorMoFailed, status, "")
                        return
                    }

                    let failed = (summary.incomplete || status != 0)
                        ? max(skipped, 1)
                        : skipped
                    Store.shared.recordPurge(
                        freedBytes: summary.freedBytes,
                        itemsRemoved: summary.itemsRemoved
                    )
                    Analytics.track(.purgeCompleted, [
                        "freed_bytes": Int(summary.freedBytes),
                        "items_removed": summary.itemsRemoved,
                        "items_failed": failed,
                    ])
                    self.state = .done(
                        freedBytes: summary.freedBytes,
                        itemsRemoved: summary.itemsRemoved,
                        itemsFailed: failed
                    )
                    self.errorMessage = nil
                }
            }
        } catch {
            state = .idle
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        cancelScanTask()
        scanTimer?.invalidate(); scanTimer = nil
        runProcess?.terminate()
        runProcess = nil
        state = .idle
        errorMessage = nil
        scanStopRequested = false
        scanStartTime = nil
        rebuildTargets()
    }
}

// MARK: - Output Buffer

/// Thread-safe accumulator for `mo purge` output. Keeps raw text (for the
/// summary parser) and trimmed lines (for the live log and progress).
private final class PurgeOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var output = ""
    private var partialLine = ""
    private(set) var lines: [String] = []
    private(set) var successCount = 0
    private(set) var lastLine = ""
    private var timedOut = false

    func reset() {
        lock.lock(); defer { lock.unlock() }
        output = ""
        partialLine = ""
        lines = []
        successCount = 0
        lastLine = ""
        timedOut = false
    }

    func append(_ chunk: String) -> (lines: [String], successCount: Int, lastLine: String) {
        lock.lock(); defer { lock.unlock() }
        output += chunk
        partialLine += chunk

        var parts = partialLine.components(separatedBy: "\n")
        if parts.count > 1 {
            partialLine = parts.removeLast()
            for line in parts {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                lines.append(trimmed)
                lastLine = trimmed
                if trimmed.hasPrefix("✓") || trimmed.hasPrefix("✔") { successCount += 1 }
            }
        }
        return (lines, successCount, lastLine)
    }

    func markTimedOut() {
        lock.lock(); defer { lock.unlock() }
        timedOut = true
    }

    func snapshot() -> (output: String, lines: [String], timedOut: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (output, lines, timedOut)
    }
}
