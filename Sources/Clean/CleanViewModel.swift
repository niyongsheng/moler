import SwiftUI
import Foundation

// MARK: - State Machine

enum CleanState: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case review(plan: CleanPlan)
    case running(log: [String], progress: Double)
    case done(freedBytes: Int64, filesRemoved: Int, partial: Bool)

    static func == (lhs: CleanState, rhs: CleanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.review(let a), .review(let b)): return a == b
        case (.running, .running): return true
        case (.done(let aB, let aF, let aP), .done(let bB, let bF, let bP)):
            return aB == bB && aF == bF && aP == bP
        default: return false
        }
    }
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

    /// Dry-run output accumulator, shared across the pipe handler, timeout
    /// work item, and exit task without touching main-actor state.
    private let scanBuffer = CleanScanBuffer()

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

        guard let mo = MoleCLI.findExecutable() else {
            scanTimer?.invalidate(); scanTimer = nil
            state = .idle
            errorMessage = L10n.errorMoNotFound
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: mo)
        task.arguments = ["clean", "--dry-run"]
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
                    currentItem: snapshot.categories,
                    totalItems: 0,
                    currentPath: snapshot.lastLine,
                    elapsedSeconds: p.elapsedSeconds,
                    scannedBytes: p.scannedBytes
                ))
            }
        }

        // Kill a runaway preview so Cancel is never the only escape.
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
                let plan = CleanDryRunParser.parse(snapshot.output)
                let status = task.terminationStatus

                await MainActor.run { [weak self] in
                    guard let self, self.scanProcess === task else { return }
                    self.scanProcess = nil
                    self.scanTimer?.invalidate(); self.scanTimer = nil

                    if plan.categories.isEmpty {
                        self.state = .idle
                        // A user-requested stop is not a failure.
                        if status != 0 && !self.scanStopRequested {
                            self.errorMessage = snapshot.timedOut
                                ? String(format: L10n.errorTimedOut, Int(Self.scanTimeout) / 60)
                                : String(format: L10n.errorMoFailed, status, "")
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

        guard let mo = MoleCLI.findExecutable() else {
            cleanTimer?.invalidate(); cleanTimer = nil
            state = .idle; errorMessage = L10n.errorMoNotFound; return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: mo)
        task.arguments = ["clean"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        let errPipe = Pipe()
        task.standardError = errPipe
        let inPipe = Pipe()
        task.standardInput = inPipe

        var logLines: [String] = []
        var partialLine = ""
        var allOutput = ""
        let lock = NSLock()
        var errData = Data()
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let d = handle.availableData
            if !d.isEmpty {
                lock.lock()
                errData.append(d)
                lock.unlock()
            }
        }

        do {
            try task.run()
            cleanProcess = task
            if let data = "y\ny\n".data(using: .utf8) {
                inPipe.fileHandleForWriting.write(data)
                try? inPipe.fileHandleForWriting.close()
            }

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                var newCompleted = 0
                lock.lock()
                if let chunk = String(data: data, encoding: .utf8) {
                    allOutput += chunk; partialLine += chunk
                    var lines = partialLine.components(separatedBy: "\n")
                    if lines.count > 1 {
                        partialLine = lines.removeLast()
                        for line in lines {
                            let t = line.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty {
                                logLines.append(t)
                                // Mole prints `✓ <item> · <size>` per
                                // completed row when stdout is not a TTY.
                                if t.hasPrefix("✓") { newCompleted += 1 }
                            }
                        }
                    }
                }
                let snapshot = logLines
                lock.unlock()

                guard newCompleted > 0 else { return }
                Task { @MainActor [weak self] in
                    guard let self, case .running = self.state else { return }
                    self.completedRows += newCompleted
                    let fraction = min(Double(self.completedRows) / Double(self.expectedRowCount), 1.0)
                    let progress = min(0.12 + 0.83 * fraction, 0.95)
                    self.state = .running(log: snapshot, progress: progress)
                }
            }

            Task.detached(priority: .userInitiated) { [weak self] in
                task.waitUntilExit()
                outPipe.fileHandleForReading.readabilityHandler = nil
                lock.lock()
                let summary = CleanSummaryParser.parse(allOutput)
                lock.unlock()

                // Trust Mole's own summary: per-item lines also contain sizes,
                // so summing them would over-count. No summary means the run
                // was interrupted (or found nothing) — report zero, not noise.
                let freed = summary?.freedBytes ?? 0
                let filesRemoved = summary?.itemsCleaned ?? 0
                let partial = summary?.isPartial ?? false

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    cleanTimer?.invalidate(); cleanTimer = nil; cleanProcess = nil
                    Store.shared.recordClean(freedBytes: freed, filesRemoved: filesRemoved)
                    Analytics.track(.cleanCompleted, [
                        "freed_bytes": Int(freed),
                        "files_removed": filesRemoved,
                    ])
                    state = .done(freedBytes: freed, filesRemoved: filesRemoved, partial: partial)
                    errorMessage = nil
                }
            }
        } catch {
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

// MARK: - Scan Buffer

/// Thread-safe accumulator for `mo clean --dry-run` output.
/// Kept outside the main-actor view model so the pipe handler and exit task
/// never touch actor-isolated state.
private final class CleanScanBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var output = ""
    private var partialLine = ""
    private var categoryCount = 0
    private var lastLine = ""
    private var timedOut = false

    func reset() {
        lock.lock(); defer { lock.unlock() }
        output = ""
        partialLine = ""
        categoryCount = 0
        lastLine = ""
        timedOut = false
    }

    /// Append a chunk and return the live section count / last line for UI.
    func append(_ chunk: String) -> (categories: Int, lastLine: String) {
        lock.lock(); defer { lock.unlock() }
        output += chunk
        partialLine += chunk
        var lines = partialLine.components(separatedBy: "\n")
        if lines.count > 1 {
            partialLine = lines.removeLast()
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                if trimmed.hasPrefix("➤") { categoryCount += 1 }
                lastLine = trimmed
            }
        }
        return (categoryCount, lastLine)
    }

    func markTimedOut() {
        lock.lock(); defer { lock.unlock() }
        timedOut = true
    }

    func snapshot() -> (output: String, timedOut: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (output, timedOut)
    }
}
