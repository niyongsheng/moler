import SwiftUI
import Foundation

// MARK: - State Machine

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

    @Published var selectedPaths: Set<String> = []

    // MARK: - Private

    private var scanTimer: Timer?
    private var scanStartTime: Date?
    private var scanTask: Task<Void, Error>?
    private var cleanTimer: Timer?
    private var cleanProcess: Process?
    private(set) var cleanStartTime: Date?
    private let currentMoProcess = ProcessBox()
    private final class ProcessBox {
        weak var process: Process?
    }

    // MARK: - Scan Accumulator

    private var scannedEntries: [DiskScanEntry] = []
    private var scannedTotal: Int64 = 0
    private var scanShouldDiscard = false
    /// Once set, all background error/cancellation handlers bail out immediately
    /// so they never override the state that stopScan/cancelScan set on the main thread.
    private var scanStopped = false

    // MARK: - Actions

    func startScan() {
        cancelScanTask()
        scanStopped = false

        let scanPath = Store.shared.lastScanPath
        scanStartTime = Date()

        let items: [String]
        let fm = FileManager.default
        do {
            items = try fm.contentsOfDirectory(atPath: scanPath)
        } catch {
            state = .idle
            errorMessage = "Failed to list scan path: \(error.localizedDescription)"
            return
        }

        let totalItems = items.count
        state = .scanning(progress: ScanProgress(
            currentItem: 0, totalItems: totalItems, currentPath: scanPath, elapsedSeconds: 0, scannedBytes: 0
        ))

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, case .scanning(let p) = self.state else { return }
            let elapsed = Int(Date().timeIntervalSince(self.scanStartTime ?? Date()))
            self.state = .scanning(progress: ScanProgress(
                currentItem: p.currentItem, totalItems: p.totalItems,
                currentPath: p.currentPath, elapsedSeconds: elapsed, scannedBytes: p.scannedBytes
            ))
        }

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            await MainActor.run { [weak self] in
                self?.scannedEntries = []
                self?.scannedTotal = 0
            }

            do {
                for (index, name) in items.enumerated() {
                    try Task.checkCancellation()

                    let childPath = (scanPath as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: childPath, isDirectory: &isDir) else { continue }

                    var batchEntries: [DiskScanEntry] = []
                    var batchSize: Int64 = 0

                    if isDir.boolValue {
                        guard let self else { continue }
                        let result = try await scanDirectory(childPath)
                        batchEntries = result.entries
                        batchSize = result.totalSize
                    } else {
                        let attrs = try fm.attributesOfItem(atPath: childPath)
                        if let fileSize = attrs[.size] as? NSNumber {
                            let size = fileSize.int64Value
                            batchEntries = [DiskScanEntry(
                                id: childPath, name: name, path: childPath, size: size, isDir: false
                            )]
                            batchSize = size
                        }
                    }

                    await MainActor.run { [weak self] in
                        guard let self, case .scanning = self.state, !scanStopped else { return }
                        scannedEntries.append(contentsOf: batchEntries)
                        scannedTotal += batchSize
                        let elapsed = Int(Date().timeIntervalSince(scanStartTime ?? Date()))
                        state = .scanning(progress: ScanProgress(
                            currentItem: index + 1, totalItems: totalItems,
                            currentPath: childPath, elapsedSeconds: elapsed, scannedBytes: scannedTotal
                        ))
                    }
                }

                try Task.checkCancellation()

                await MainActor.run { [weak self] in
                    guard let self, !scanStopped else { return }
                    scannedEntries.sort { $0.size > $1.size }
                    let result = DiskScanResult(
                        path: scanPath, totalSize: scannedTotal,
                        totalFiles: scannedEntries.count, entries: scannedEntries, scannedAt: Date()
                    )
                    scanTimer?.invalidate(); scanTimer = nil
                    state = .review(result: result)
                    selectedPaths = Set(result.entries.map(\.path))
                    errorMessage = nil
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self, !scanStopped else { return }
                    scanTimer?.invalidate(); scanTimer = nil
                    if scanShouldDiscard || scannedEntries.isEmpty {
                        state = .idle
                    } else {
                        scannedEntries.sort { $0.size > $1.size }
                        let result = DiskScanResult(
                            path: scanPath, totalSize: scannedTotal,
                            totalFiles: scannedEntries.count, entries: scannedEntries, scannedAt: Date()
                        )
                        state = .review(result: result)
                        selectedPaths = Set(result.entries.map(\.path))
                    }
                    errorMessage = nil
                    scanShouldDiscard = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, !scanStopped else { return }
                    scanTimer?.invalidate(); scanTimer = nil
                    state = .idle
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Cancel scan — discard all progress, return to idle immediately.
    func cancelScan() {
        scanShouldDiscard = true
        scanStopped = true
        cancelScanTask()
        scanTimer?.invalidate(); scanTimer = nil
        state = .idle
        errorMessage = nil
    }

    /// Stop scan — preserve scanned items, show review immediately.
    func stopScan() {
        scanShouldDiscard = false
        scanStopped = true
        cancelScanTask()
        scanTimer?.invalidate(); scanTimer = nil
        errorMessage = nil
        if scannedEntries.isEmpty {
            state = .idle
        } else {
            scannedEntries.sort { $0.size > $1.size }
            let result = DiskScanResult(
                path: Store.shared.lastScanPath,
                totalSize: scannedTotal,
                totalFiles: scannedEntries.count,
                entries: scannedEntries,
                scannedAt: Date()
            )
            state = .review(result: result)
            selectedPaths = Set(result.entries.map(\.path))
        }
    }

    private func cancelScanTask() {
        currentMoProcess.process?.terminate()
        currentMoProcess.process = nil
        scanTask?.cancel()
        scanTask = nil
    }

    private func scanDirectory(_ path: String) async throws -> DiskScanResult {
        guard let mo = MoleCLI.findExecutable() else { throw MoleError.notFound }
        return try await Task.detached(priority: .utility) { [ref = currentMoProcess] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: mo)
            task.arguments = ["analyze", "--json", path]
            let outPipe = Pipe()
            task.standardOutput = outPipe
            let errPipe = Pipe()
            task.standardError = errPipe
            try task.run()
            ref.process = task
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            if ref.process === task { ref.process = nil }
            guard task.terminationStatus == 0 else {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw MoleError.failed(exitCode: task.terminationStatus, stderr: err)
            }
            return try DiskScanner.parse(outData)
        }.value
    }

    func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) { selectedPaths.remove(path) }
        else { selectedPaths.insert(path) }
    }

    func selectedTotalBytes(from result: DiskScanResult) -> Int64 {
        result.entries.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.size }
    }

    func selectedCount(from result: DiskScanResult) -> Int {
        result.entries.filter { selectedPaths.contains($0.path) }.count
    }

    // MARK: - Clean Execution

    func startClean() {
        cancelCleanTask()
        state = .running(log: [], progress: 0)
        cleanStartTime = Date()
        let startTime = cleanStartTime!

        cleanTimer?.invalidate()
        cleanTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self, case .running(let log, _) = self.state else { return }
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
                lock.lock()
                if let chunk = String(data: data, encoding: .utf8) {
                    allOutput += chunk; partialLine += chunk
                    var lines = partialLine.components(separatedBy: "\n")
                    if lines.count > 1 {
                        partialLine = lines.removeLast()
                        for line in lines {
                            let t = line.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty { logLines.append(t) }
                        }
                    }
                }
                let snapshot = logLines
                lock.unlock()
                Task { @MainActor in
                    guard let self, case .running = self.state else { return }
                    self.state = .running(log: snapshot, progress: 0.5)
                }
            }

            Task.detached(priority: .userInitiated) { [weak self] in
                task.waitUntilExit()
                outPipe.fileHandleForReading.readabilityHandler = nil
                lock.lock()
                let freed = estimateFreedBytes(from: allOutput)
                let lines = logLines
                lock.unlock()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    cleanTimer?.invalidate(); cleanTimer = nil; cleanProcess = nil
                    Store.shared.recordClean(freedBytes: freed, filesRemoved: lines.count)
                    state = .done(freedBytes: freed, filesRemoved: lines.count)
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
        state = .idle; errorMessage = nil
    }

    private func cancelCleanTask() {
        cleanProcess?.terminate()
        cleanProcess = nil
    }

    func reset() {
        scanTimer?.invalidate(); scanTimer = nil
        cleanTimer?.invalidate(); cleanTimer = nil
        cleanProcess = nil
        currentMoProcess.process = nil
        state = .idle
        selectedPaths = []
        scannedEntries = []
        scannedTotal = 0
        errorMessage = nil
        scanStopped = false
    }
}

// MARK: - Helpers

private func estimateFreedBytes(from text: String) -> Int64 {
    var total: Int64 = 0
    guard let pattern = try? NSRegularExpression(pattern: "(\\d+\\.?\\d*)\\s*(TB|GB|MB|KB|B)", options: .caseInsensitive) else {
        return 0
    }
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
