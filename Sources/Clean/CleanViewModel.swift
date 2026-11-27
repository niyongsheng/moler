import SwiftUI
import Foundation

// MARK: - State Machine

enum CleanState: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case review(plan: CleanPlan)
    case running(log: [String], progress: Double)
    case done(freedBytes: Int64, filesRemoved: Int, partial: Bool)
}

struct ScanProgress: Equatable {
    let currentItem: Int
    let totalItems: Int
    let currentPath: String
    let elapsedSeconds: Int
    let scannedBytes: Int64
}

// MARK: - ViewModel

@MainActor
final class CleanViewModel: ObservableObject {

    @Published var state: CleanState = .idle
    @Published var errorMessage: String?

    // MARK: - Private

    private var scanTimer: Timer?
    private var scanStartTime: Date?
    private var scanProcess: Process?
    private var scanStopRequested = false
    private var cleanTimer: Timer?
    private var cleanProcess: Process?
    private(set) var cleanStartTime: Date?

    /// Rows in the reviewed plan, used to estimate real-run progress from the
    /// `✓ …` result lines Mole prints as it cleans (spinners are TTY-only).
    private var plannedRowCount = 0
    private var completedRows = 0
    private var expectedRowCount = 1

    /// Dry-run output accumulator, shared across the pipe handler and exit
    /// task without touching main-actor state.
    private let scanBuffer = LineBuffer()
    /// Real-run output accumulator for the live log and summary parsing.
    private let cleanBuffer = LineBuffer()

    /// `mo clean --dry-run` walks the whole cache surface; 1.74 takes about a
    /// minute on a warm cache, so allow plenty of headroom.
    private static let scanTimeout: TimeInterval = 300

    // MARK: - Scan

    /// Run `mo clean --dry-run` and show Mole's real cleanup plan.
    ///
    /// The preview — not a directory scan — is the source of truth: it lists
    /// exactly what Mole would delete, what it deliberately skips, and what is
    /// review-only. Per-path checkboxes are intentionally gone: `mo clean`
    /// has no path arguments, so a selection that did not affect execution
    /// would be misleading.
    func startScan() {
        cancelScanTask()
        scanStopRequested = false
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

        // Dry-run output is accumulated here; stderr is drained and discarded.
        let buffer = scanBuffer
        buffer.reset()

        do {
            let stream = try MoleCLI.stream(
                args: ["clean", "--dry-run"],
                timeout: Self.scanTimeout,
                onStdout: { chunk in
                    let snapshot = buffer.append(chunk).snapshot
                    let categories = snapshot.lines.reduce(0) {
                        $0 + ($1.hasPrefix("➤") ? 1 : 0)
                    }
                    let lastLine = snapshot.lines.last ?? ""

                    Task { @MainActor [weak self] in
                        guard let self, case .scanning(let p) = self.state else { return }
                        self.state = .scanning(progress: ScanProgress(
                            currentItem: categories,
                            totalItems: 0,
                            currentPath: lastLine,
                            elapsedSeconds: p.elapsedSeconds,
                            scannedBytes: p.scannedBytes
                        ))
                    }
                },
                onExit: { [weak self] result, process in
                    let plan = CleanDryRunParser.parse(buffer.snapshot().output)

                    Task { @MainActor [weak self] in
                        guard let self, self.scanProcess === process else { return }
                        self.scanProcess = nil
                        self.scanTimer?.invalidate(); self.scanTimer = nil

                        if plan.categories.isEmpty {
                            self.state = .idle
                            // A user-requested stop is not a failure.
                            if result.exitCode != 0 && !self.scanStopRequested {
                                self.errorMessage = result.timedOut
                                    ? String(format: L10n.errorTimedOut, Int(Self.scanTimeout) / 60)
                                    : String(format: L10n.errorMoFailed, result.exitCode, "")
                            } else {
                                self.errorMessage = nil
                            }
                        } else {
                            self.plannedRowCount = plan.cleanableCount
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

    /// Stop the preview and review what was parsed so far.
    func stopScan() {
        scanStopRequested = true
        scanTimer?.invalidate(); scanTimer = nil
        // Leave `scanProcess` set so the exit handler parses the partial output.
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

    // MARK: - Clean Execution

    func startClean() {
        cancelCleanTask()
        state = .running(log: [], progress: 0)
        cleanStartTime = Date()
        let startTime = cleanStartTime!
        completedRows = 0
        expectedRowCount = max(plannedRowCount, 1)

        cleanTimer?.invalidate()
        cleanTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self, case .running(let log, _) = self.state else { return }
            // Once Mole reports result rows, the handler owns the progress
            // value; pulse only while waiting for the first one.
            guard self.completedRows == 0 else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let pulse = 0.15 + 0.7 * (0.5 + 0.5 * sin(elapsed * 3))
            self.state = .running(log: log, progress: pulse)
        }

        // Mole prints `✓ <item> · <size>` per completed row on stdout; stderr
        // is drained and discarded.
        let buffer = cleanBuffer
        buffer.reset()

        do {
            let stream = try MoleCLI.stream(
                args: ["clean"],
                stdin: "y\ny\n",
                onStdout: { [weak self] chunk in
                    let batch = buffer.append(chunk)
                    let newCompleted = batch.newLines.filter { $0.hasPrefix("✓") }.count
                    guard newCompleted > 0 else { return }
                    let lines = batch.snapshot.lines

                    Task { @MainActor [weak self] in
                        guard let self, case .running = self.state else { return }
                        self.completedRows += newCompleted
                        let fraction = min(
                            Double(self.completedRows) / Double(self.expectedRowCount), 1.0
                        )
                        let progress = min(0.12 + 0.83 * fraction, 0.95)
                        self.state = .running(log: lines, progress: progress)
                    }
                },
                onExit: { [weak self] _, process in
                    // Trust Mole's own summary: per-item lines also contain
                    // sizes, so summing them would over-count. No summary means
                    // the run was interrupted (or found nothing) — report zero.
                    let summary = CleanSummaryParser.parse(buffer.snapshot().output)
                    let freed = summary?.freedBytes ?? 0
                    let filesRemoved = summary?.itemsCleaned ?? 0
                    let partial = summary?.isPartial ?? false

                    Task { @MainActor [weak self] in
                        guard let self, self.cleanProcess === process else { return }
                        self.cleanTimer?.invalidate(); self.cleanTimer = nil
                        self.cleanProcess = nil
                        Store.shared.recordClean(freedBytes: freed)
                        Analytics.track(.cleanCompleted, [
                            "freed_bytes": Int(freed),
                            "files_removed": filesRemoved,
                        ])
                        self.state = .done(
                            freedBytes: freed, filesRemoved: filesRemoved, partial: partial
                        )
                        self.errorMessage = nil
                    }
                }
            )
            cleanProcess = stream.process
            try stream.start()
        } catch {
            cleanProcess = nil
            cleanTimer?.invalidate(); cleanTimer = nil
            state = .idle; errorMessage = error.localizedDescription
        }
    }

    func cancelClean() {
        cancelCleanTask()
        cleanTimer?.invalidate(); cleanTimer = nil
        state = .idle
        errorMessage = nil
    }

    private func cancelCleanTask() {
        cleanProcess?.terminate()
        cleanProcess = nil
    }

    func reset() {
        scanTimer?.invalidate(); scanTimer = nil
        cleanTimer?.invalidate(); cleanTimer = nil
        cancelScanTask()
        cleanProcess = nil
        state = .idle
        errorMessage = nil
        scanStopRequested = false
        scanStartTime = nil
        cleanStartTime = nil
    }
}
