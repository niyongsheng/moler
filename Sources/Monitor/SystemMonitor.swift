import Foundation
import SwiftUI

/// Streams `mo status --watch` (NDJSON, one snapshot per line) and publishes
/// parsed system stats. Keeps a rolling buffer of network RX/TX history for the
/// sparkline.
///
/// Mole **1.71+** makes `--watch` cheap (about 0.1% CPU at a 1 s interval), so
/// one long-lived process is much cheaper than re-spawning `mo status --json`
/// every few seconds. The first watch snapshot is a warm-up with empty
/// hardware/pressure fields; `SystemStats.isComplete` filters it out.
@MainActor
final class SystemMonitor: ObservableObject {
    @Published var stats: SystemStats?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastFetchedAt: Date?

    /// Rolling network history (30 samples ≈ 1 min at the 2 s active interval)
    @Published var rxHistory: [Double] = []
    @Published var txHistory: [Double] = []

    private var streamProcess: Process?
    private var streamInterval: TimeInterval = 0
    private var streamGeneration = 0
    private var restartTask: Task<Void, Never>?
    private var wantsStreaming = false
    private var isAppActive = true
    private let maxHistory = 30

    private static let activeInterval: TimeInterval = 2
    private static let backgroundInterval: TimeInterval = 10

    /// Live monitors are stopped on app termination so the child
    /// `status-go --watch` process never outlives Moler.
    private static weak var current: SystemMonitor?

    init() {
        Self.current = self
    }

    @MainActor
    static func stopShared() {
        current?.stop()
    }

    func start() {
        setPolling(enabled: true, appActive: true)
    }

    /// Start, slow down, or pause the stream.
    ///
    /// Mole's `--watch` interval is fixed at launch, so a change between the
    /// active and background cadence restarts the process. Only one process
    /// runs at a time.
    func setPolling(enabled: Bool, appActive: Bool) {
        wantsStreaming = enabled
        isAppActive = appActive

        guard enabled else {
            pause()
            return
        }

        let desired = appActive ? Self.activeInterval : Self.backgroundInterval
        if streamProcess != nil && streamInterval == desired { return }
        startStream(interval: desired)
    }

    func stop() {
        pause()
        stats = nil
        isLoading = false
        error = nil
        lastFetchedAt = nil
        rxHistory = []
        txHistory = []
    }

    /// Stop streaming but keep the last snapshot, so returning to the
    /// dashboard shows data immediately while a fresh sample loads.
    func pause() {
        restartTask?.cancel()
        restartTask = nil
        stopStream()
    }

    // MARK: - Streaming

    private func startStream(interval: TimeInterval) {
        stopStream()
        guard let mo = MoleCLI.findExecutable() else {
            error = L10n.errorMoNotFound
            return
        }

        isLoading = stats == nil
        streamInterval = interval
        streamGeneration += 1
        let generation = streamGeneration

        let task = Process()
        task.executableURL = URL(fileURLWithPath: mo)
        task.arguments = ["status", "--watch", "--interval", "\(Int(interval))s"]
        task.standardInput = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        task.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty {
                errPipe.fileHandleForReading.readabilityHandler = nil
            }
        }

        let buffer = NDJSONLineBuffer()
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = String(data: data, encoding: .utf8) ?? ""

            for line in buffer.append(chunk) {
                guard !line.isEmpty, let raw = line.data(using: .utf8) else { continue }
                guard let snapshot = try? JSONDecoder().decode(SystemStats.self, from: raw) else { continue }
                // Skip Mole's warm-up snapshot (empty hardware/pressure).
                guard snapshot.isComplete else { continue }

                Task { @MainActor [weak self] in
                    guard let self, self.streamGeneration == generation else { return }
                    self.apply(snapshot)
                }
            }
        }

        do {
            try task.run()
        } catch {
            isLoading = false
            errorMessage(error.localizedDescription)
            scheduleRestart(generation: generation)
            return
        }

        streamProcess = task

        Task.detached(priority: .utility) { [weak self] in
            task.waitUntilExit()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            _ = try? outPipe.fileHandleForReading.readToEnd()
            _ = try? errPipe.fileHandleForReading.readToEnd()

            await MainActor.run { [weak self] in
                guard let self, self.streamGeneration == generation else { return }
                self.streamProcess = nil
                self.streamInterval = 0
                self.isLoading = false
                self.scheduleRestart(generation: generation)
            }
        }
    }

    /// Invalidate the current stream and terminate its child.
    private func stopStream() {
        streamGeneration += 1
        streamProcess?.terminate()
        streamProcess = nil
        streamInterval = 0
        isLoading = false
    }

    /// `mo status --watch` should not die in normal use, but a Mole upgrade or
    /// a transient failure must not leave the dashboard frozen.
    private func scheduleRestart(generation: Int) {
        guard wantsStreaming else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, let self,
                  self.wantsStreaming,
                  self.streamGeneration == generation else { return }
            let interval = self.isAppActive ? Self.activeInterval : Self.backgroundInterval
            self.startStream(interval: interval)
        }
    }

    private func errorMessage(_ message: String) {
        error = message
        isLoading = false
    }

    private func apply(_ snapshot: SystemStats) {
        stats = snapshot
        lastFetchedAt = Date()
        isLoading = false
        error = nil

        if let net = snapshot.network.first {
            rxHistory.append(net.rxRateMbs ?? 0)
            txHistory.append(net.txRateMbs ?? 0)
            if rxHistory.count > maxHistory {
                rxHistory = Array(rxHistory.suffix(maxHistory))
                txHistory = Array(txHistory.suffix(maxHistory))
            }
        }
    }
}

// MARK: - NDJSON Buffer

/// Thread-safe line splitter for the watch process's stdout.
private final class NDJSONLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var partial = ""

    func append(_ chunk: String) -> [String] {
        lock.lock(); defer { lock.unlock() }
        partial += chunk
        var parts = partial.components(separatedBy: "\n")
        guard parts.count > 1 else { return [] }
        partial = parts.removeLast()
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
