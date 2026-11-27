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
    private let scanBuffer = LineBuffer()

    private var runProcess: Process?
    private let runBuffer = LineBuffer()

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
        persistSelection()
    }

    /// Remove a custom target by id. Built-in defaults cannot be removed,
    /// but they can be deselected.
    func removeTarget(_ id: String) {
        guard id.hasPrefix("custom.") else { return }
        scanTargets.removeAll { $0.id == id }
        persistSelection()
    }

    func toggleTarget(_ id: String) {
        guard let index = scanTargets.firstIndex(where: { $0.id == id }) else { return }
        scanTargets[index].isSelected.toggle()
        persistSelection()
    }

    func selectAllTargets(_ select: Bool) {
        for index in scanTargets.indices {
            scanTargets[index].isSelected = select
        }
        persistSelection()
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

    private func persistSelection() {
        let selected = scanTargets.filter(\.isSelected).map(\.path)
        // An empty config means "use Mole defaults", so never write zero paths.
        guard !selected.isEmpty else { return }
        do {
            try PurgePathConfig.write(selected)
        } catch {
            errorMessage = String(format: L10n.purgePathsSaveError, error.localizedDescription)
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
        persistSelection()
        cancelScanTask()
        errorMessage = nil
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

        // Preview output is accumulated here; stderr is drained and discarded.
        let buffer = scanBuffer
        buffer.reset()

        do {
            let stream = try MoleCLI.stream(
                args: ["purge", "--dry-run"],
                timeout: Self.scanTimeout,
                onStdout: { chunk in
                    let snapshot = buffer.append(chunk).snapshot
                    let successes = snapshot.lines.reduce(0) {
                        $0 + (($1.hasPrefix("✓") || $1.hasPrefix("✔")) ? 1 : 0)
                    }
                    let lastLine = snapshot.lines.last ?? ""

                    Task { @MainActor [weak self] in
                        guard let self, case .scanning(let p) = self.state else { return }
                        self.state = .scanning(progress: ScanProgress(
                            currentItem: successes,
                            totalItems: 0,
                            currentPath: lastLine,
                            elapsedSeconds: p.elapsedSeconds,
                            scannedBytes: p.scannedBytes
                        ))
                    }
                },
                onExit: { [weak self] result, process in
                    let plan = PurgePlanParser.parse(buffer.snapshot().output)

                    Task { @MainActor [weak self] in
                        guard let self, self.scanProcess === process else { return }
                        self.scanProcess = nil
                        self.scanTimer?.invalidate(); self.scanTimer = nil

                        // Mole may have discovered and saved paths on first run.
                        self.rebuildTargets()

                        if plan.isEmpty && result.exitCode != 0 {
                            self.state = .idle
                            self.errorMessage = result.timedOut
                                ? String(format: L10n.errorTimedOut, Int(Self.scanTimeout) / 60)
                                : String(format: L10n.errorMoFailed, result.exitCode, "")
                        } else {
                            self.state = .review(plan: plan)
                            self.errorMessage = nil
                        }
                    }
                }
            )
            scanProcess = stream.process
            try stream.start()
        } catch {
            scanProcess = nil
            scanTimer?.invalidate(); scanTimer = nil
            state = .idle
            errorMessage = error.localizedDescription
        }
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

        // Mole prints live progress on both stdout and stderr; keep both in
        // the visible log.
        let buffer = runBuffer
        buffer.reset()
        let appendChunk: (String) -> Void = { [weak self] chunk in
            let lines = buffer.append(chunk).snapshot.lines
            Task { @MainActor [weak self] in
                guard let self, case .running = self.state else { return }
                self.state = .running(log: lines)
            }
        }

        do {
            let stream = try MoleCLI.stream(
                args: ["purge", "--yes"],
                timeout: Self.runTimeout,
                onStdout: appendChunk,
                onStderr: appendChunk,
                onExit: { [weak self] result, process in
                    let snapshot = buffer.snapshot()
                    let summary = PurgePlanParser.parseRunSummary(snapshot.output)
                    let skipped = snapshot.lines.filter {
                        $0.hasPrefix("◎") && $0.localizedCaseInsensitiveContains("Skipped")
                    }.count

                    Task { @MainActor [weak self] in
                        guard let self, self.runProcess === process else { return }
                        self.runProcess = nil

                        if result.timedOut {
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
                            self.errorMessage = String(
                                format: L10n.errorMoFailed, result.exitCode, ""
                            )
                            return
                        }

                        let failed = (summary.incomplete || result.exitCode != 0)
                            ? max(skipped, 1)
                            : skipped
                        Store.shared.recordPurge(freedBytes: summary.freedBytes)
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
            )
            runProcess = stream.process
            try stream.start()
        } catch {
            runProcess = nil
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
        scanStartTime = nil
        rebuildTargets()
    }
}
