import Foundation

enum PurgeState: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case review(entries: [PurgeEntry])
    case running(log: [String])
    case done(freedBytes: Int64, itemsRemoved: Int)
}

struct PurgeEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let category: String
}

@MainActor
final class PurgeViewModel: ObservableObject {
    @Published var state: PurgeState = .idle
    @Published var errorMessage: String?
    @Published var selectedPaths: Set<String> = []

    private var scanTask: Task<Void, Never>?

    private let scanTargets: [(name: String, path: String)] = [
        ("DerivedData",     "~/Library/Developer/Xcode/DerivedData"),
        ("Archives",        "~/Library/Developer/Xcode/Archives"),
        ("iOS Device Logs", "~/Library/Developer/Xcode/iOS Device Logs"),
        ("Caches",          "~/Library/Caches"),
        ("CocoaPods",       "~/Library/Caches/CocoaPods"),
        ("Maven",           "~/.m2/repository"),
        ("Gradle",          "~/.gradle/caches"),
        ("SwiftPM",         "~/Library/Caches/org.swift.swiftpm"),
    ]

    func startScan() {
        state = .scanning(progress: ScanProgress(currentItem: 0, totalItems: scanTargets.count, currentPath: "", elapsedSeconds: 0, scannedBytes: 0))
        let start = Date()
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            var entries: [PurgeEntry] = []
            var totalSize: Int64 = 0
            for (i, target) in (self?.scanTargets ?? []).enumerated() {
                if Task.isCancelled { return }
                let expanded = (target.path as NSString).expandingTildeInPath
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
                    await MainActor.run { [weak self] in
                        guard let self, case .scanning(let p) = self.state else { return }
                        self.state = .scanning(progress: ScanProgress(currentItem: i+1, totalItems: scanTargets.count, currentPath: target.path, elapsedSeconds: Int(Date().timeIntervalSince(start)), scannedBytes: totalSize))
                    }
                    continue
                }
                let size = directorySize(expanded)
                totalSize += size
                entries.append(PurgeEntry(id: target.name, name: target.name, path: expanded, size: size, category: "Project Artifacts"))
                await MainActor.run { [weak self] in
                    guard let self, case .scanning(let p) = self.state else { return }
                    self.state = .scanning(progress: ScanProgress(currentItem: i+1, totalItems: scanTargets.count, currentPath: target.path, elapsedSeconds: Int(Date().timeIntervalSince(start)), scannedBytes: totalSize))
                }
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                entries.sort { $0.size > $1.size }
                state = .review(entries: entries)
                selectedPaths = Set(entries.map(\.path))
            }
        }
    }

    func cancelScan() { scanTask?.cancel(); scanTask = nil; state = .idle }

    func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) { selectedPaths.remove(path) }
        else { selectedPaths.insert(path) }
    }

    func selectedCount(from entries: [PurgeEntry]) -> Int {
        entries.filter { selectedPaths.contains($0.path) }.count
    }

    func selectedTotalBytes(from entries: [PurgeEntry]) -> Int64 {
        entries.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.size }
    }

    func startPurge() {
        guard case .review(let entries) = state else { return }
        state = .running(log: [])
        let toPurge = entries.filter { selectedPaths.contains($0.path) }
        Task.detached(priority: .userInitiated) { [weak self] in
            var log: [String] = []
            var freed: Int64 = 0
            for entry in toPurge {
                if Task.isCancelled { break }
                let size = directorySize(entry.path)
                do {
                    try FileManager.default.removeItem(atPath: entry.path)
                    freed += size
                    log.append("Removed \(entry.name) (\(formatBytes(size)))")
                } catch {
                    log.append("Failed: \(entry.name) — \(error.localizedDescription)")
                }
                await MainActor.run { self?.state = .running(log: log) }
            }
            await MainActor.run {
                self?.state = .done(freedBytes: freed, itemsRemoved: toPurge.count)
            }
        }
    }

    func reset() { scanTask?.cancel(); scanTask = nil; state = .idle; selectedPaths = []; errorMessage = nil }
}

private func directorySize(_ path: String) -> Int64 {
    guard let enumerator = FileManager.default.enumerator(atPath: path) else { return 0 }
    var total: Int64 = 0
    while let file = enumerator.nextObject() as? String {
        let full = (path as NSString).appendingPathComponent(file)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
           let size = attrs[.size] as? NSNumber { total += size.int64Value }
    }
    return total
}
