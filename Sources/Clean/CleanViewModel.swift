import SwiftUI
import Foundation

// MARK: - State Machine

/// The five states of the clean workflow.
enum CleanState: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case review(result: DiskScanResult)
    case running(log: [String], progress: Double)
    case done(freedBytes: Int64, filesRemoved: Int)

    static func == (lhs: CleanState, rhs: CleanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.review(let a), .review(let b)): return a.path == b.path
        case (.running, .running): return true
        case (.done(let aB, let aF), .done(let bB, let bF)): return aB == bB && aF == bF
        default: return false
        }
    }
}

/// Live progress during scanning, updated by a periodic timer.
struct ScanProgress: Equatable {
    let filesFound: Int
    let totalBytes: Int64
    let currentPath: String
    let elapsedSeconds: Int
}

// MARK: - ViewModel

/// Drives the Clean tab UI through the five-state workflow.
@MainActor
final class CleanViewModel: ObservableObject {

    // MARK: Published State

    @Published var state: CleanState = .idle
    @Published var errorMessage: String?

    /// Selected file paths in the review phase (default: all selected).
    @Published var selectedPaths: Set<String> = []

    // MARK: - Private

    private var scanTimer: Timer?
    private var scanStartTime: Date?

    // MARK: - Scan Logic (improved metadata)

    /// Extra metadata from the cleaned DryRun, like categories and total potential savings
    private var dryRunTotalBytes: Int64 = 0
    private var dryRunTotalItems: Int = 0

    // MARK: - Actions

    /// Begin scanning the home directory with live progress.
    func startScan() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        state = .scanning(progress: ScanProgress(
            filesFound: -1, totalBytes: -1, currentPath: home, elapsedSeconds: 0
        ))
        scanStartTime = Date()

        // Elapsed-time ticker
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, case .scanning(let p) = self.state else { return }
            let elapsed = Int(Date().timeIntervalSince(self.scanStartTime ?? Date()))
            self.state = .scanning(progress: ScanProgress(
                filesFound: p.filesFound,
                totalBytes: p.totalBytes,
                currentPath: p.currentPath,
                elapsedSeconds: elapsed
            ))
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try MoEngine.shared.analyze()

                await MainActor.run { [weak self] in
                    self?.scanTimer?.invalidate()
                    self?.scanTimer = nil
                    self?.state = .review(result: result)
                    self?.selectedPaths = Set(result.entries.map(\.path))
                    self?.errorMessage = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.scanTimer?.invalidate()
                    self?.scanTimer = nil
                    self?.state = .idle
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Toggle whether a path is selected for cleaning.
    func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    /// Total byte size of the selected paths.
    func selectedTotalBytes(from result: DiskScanResult) -> Int64 {
        result.entries
            .filter { selectedPaths.contains($0.path) }
            .reduce(0) { $0 + $1.size }
    }

    /// Number of selected entries.
    func selectedCount(from result: DiskScanResult) -> Int {
        result.entries.filter { selectedPaths.contains($0.path) }.count
    }

    /// Execute the clean operation.
    ///
    /// Uses `mo clean` with canned "y" + "y" stdin (confirm + proceed).
    /// Writes output to the terminal-style log view.
    func startClean() {
        state = .running(log: [], progress: 0)

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                // Pipe "y\ny\n" to auto-confirm mo's interactive prompts.
                let result = try MoEngine.shared.capture(MoCommand(
                    args: ["clean"],
                    stdin: "y\ny\n",
                    timeout: 300
                ))

                let allOutput = (result.stdout + "\n" + result.stderr)
                let logLines = allOutput
                    .components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                // Rough estimate: scan for size patterns like "1.2GB" in output.
                let freed: Int64 = estimateFreedBytes(from: allOutput)

                await MainActor.run { [weak self] in
                    Store.shared.recordClean(freedBytes: freed, filesRemoved: logLines.count)
                    self?.state = .done(freedBytes: freed, filesRemoved: logLines.count)
                    self?.errorMessage = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.state = .idle
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Return to idle from any state.
    func reset() {
        scanTimer?.invalidate()
        scanTimer = nil
        state = .idle
        selectedPaths = []
        errorMessage = nil
    }
}

// MARK: - Helpers

/// Crude parser that scans text for byte-size patterns like "1.2GB", "500MB", etc.
/// Returns the summed total in bytes. Designed for `mo clean`'s ANSI TUI output.
private func estimateFreedBytes(from text: String) -> Int64 {
    var total: Int64 = 0
    // Match patterns like "1.2GB", "500MB", "30KB", "100B"
    let pattern = try! NSRegularExpression(
        pattern: "(\\d+\\.?\\d*)\\s*(TB|GB|MB|KB|B)",
        options: .caseInsensitive
    )
    let nsText = text as NSString
    for match in pattern.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
        guard match.numberOfRanges >= 3,
              let value = Double(nsText.substring(with: match.range(at: 1))) else { continue }
        let unit = nsText.substring(with: match.range(at: 2)).uppercased()
        let multiplier: Double = {
            switch unit {
            case "TB": return 1_099_511_627_776
            case "GB": return 1_073_741_824
            case "MB": return 1_048_576
            case "KB": return 1_024
            default:   return 1
            }
        }()
        total += Int64(value * multiplier)
    }
    return total
}
