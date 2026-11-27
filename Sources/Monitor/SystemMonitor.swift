import Foundation
import SwiftUI

/// Polls `mo status --json` (10 s while visible) and publishes parsed system
/// stats. Keeps a rolling buffer of network RX/TX history for the sparkline.
@MainActor
final class SystemMonitor: ObservableObject {
    @Published var stats: SystemStats?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastFetchedAt: Date?

    /// Rolling network history (last 30 samples ≈ 5 min at the 10 s interval)
    @Published var rxHistory: [Double] = []
    @Published var txHistory: [Double] = []

    private var timer: Timer?
    private var isFetching = false
    private var interval: TimeInterval = 0
    private let maxHistory = 30

    func start() {
        setPolling(enabled: true, appActive: true)
    }

    /// Start, slow down, or pause polling.
    ///
    /// Each fetch spawns the `mo` CLI, which costs roughly a full CPU-second.
    /// Polling is therefore kept off unless the dashboard is actually visible,
    /// and the interval is deliberately relaxed: 10 s while the app is
    /// frontmost, 60 s when it is in the background, none when the window is
    /// closed.
    func setPolling(enabled: Bool, appActive: Bool) {
        guard enabled else {
            pause()
            return
        }
        let desired: TimeInterval = appActive ? 10.0 : 60.0
        if timer != nil && interval == desired { return }

        interval = desired
        timer?.invalidate()
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: desired, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetch()
            }
        }
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

    /// Stop polling but keep the last snapshot, so returning to the dashboard
    /// shows data immediately while a fresh sample loads.
    func pause() {
        timer?.invalidate()
        timer = nil
        interval = 0
    }

    private func fetch() {
        guard !isFetching else { return }
        isFetching = true
        isLoading = stats == nil

        Task.detached(priority: .utility) { [weak self] in
            // Ensure isFetching is always reset, even on unexpected early exits
            defer {
                Task { @MainActor [weak self] in
                    self?.isFetching = false
                }
            }

            do {
                guard let mo = MoleCLI.findExecutable() else { throw MoleError.notFound }
                let result = try MoleProcess.run(executable: mo, args: ["status", "--json"], timeout: 10)
                guard result.exitCode == 0 else {
                    throw MoleError.failed(exitCode: result.exitCode, stderr: result.stderr)
                }
                guard let data = result.stdout.data(using: .utf8) else {
                    throw MoleError.parseFailed("Non-UTF8 output")
                }

                let decoder = JSONDecoder()
                let stats = try decoder.decode(SystemStats.self, from: data)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.stats = stats
                    self.lastFetchedAt = Date()
                    self.isLoading = false
                    self.error = nil

                    // Append network samples to rolling buffer
                    if let net = stats.network.first {
                        self.rxHistory.append(net.rxRateMbs ?? 0)
                        self.txHistory.append(net.txRateMbs ?? 0)
                        if self.rxHistory.count > self.maxHistory {
                            self.rxHistory = Array(self.rxHistory.suffix(self.maxHistory))
                            self.txHistory = Array(self.txHistory.suffix(self.maxHistory))
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isLoading = false
                    if self?.stats == nil {
                        self?.error = error.localizedDescription
                    }
                }
            }
        }
    }
}
