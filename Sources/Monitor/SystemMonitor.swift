import Foundation
import SwiftUI

/// Polls `mo status --json` every 3 seconds and publishes parsed system stats.
/// Keeps a rolling buffer of network RX/TX history for the sparkline chart.
@MainActor
final class SystemMonitor: ObservableObject {
    @Published var stats: SystemStats?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastFetchedAt: Date?

    /// Rolling network history (last 30 samples ≈ 90s at 3s interval)
    @Published var rxHistory: [Double] = []
    @Published var txHistory: [Double] = []

    private var timer: Timer?
    private var isFetching = false
    private let maxHistory = 30

    func start() {
        guard timer == nil else { return }
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetch()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stats = nil
        isLoading = false
        error = nil
        lastFetchedAt = nil
        rxHistory = []
        txHistory = []
    }

    func pause() {
        timer?.invalidate()
        timer = nil
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
