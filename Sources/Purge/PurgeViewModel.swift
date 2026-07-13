import Foundation

enum PurgeState: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case review(entries: [PurgeEntry])
    case running(log: [String])
    case done(freedBytes: Int64, itemsRemoved: Int, itemsFailed: Int = 0)
}

struct PurgeEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let category: String
}

/// A selectable scan target shown as a pill in the idle view.
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
    @Published var selectedPaths: Set<String> = []

    /// Combined toggleable scan targets — presets + custom.
    @Published var scanTargets: [ScanTarget] = []

    private var scanTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let customPathsKey = "moler.purgeCustomPaths"

    /// Built-in presets with auto-detection.
    private let presetTargets: [(name: String, path: String)] = [
        ("DerivedData",     "~/Library/Developer/Xcode/DerivedData"),
        ("Archives",        "~/Library/Developer/Xcode/Archives"),
        ("iOS Device Logs", "~/Library/Developer/Xcode/iOS Device Logs"),
        ("Caches",          "~/Library/Caches"),
        ("CocoaPods",       "~/Library/Caches/CocoaPods"),
        ("Maven",           "~/.m2/repository"),
        ("Gradle",          "~/.gradle/caches"),
        ("SwiftPM",         "~/Library/Caches/org.swift.swiftpm"),
    ]

    init() {
        rebuildTargets()
    }

    /// Rebuild the full target list from presets + persisted custom paths.
    private func rebuildTargets() {
        let fm = FileManager.default
        var result: [ScanTarget] = []

        // Presets — auto-selected if directory exists
        for t in presetTargets {
            let expanded = (t.path as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
            result.append(ScanTarget(id: "preset.\(t.name)", name: t.name, path: expanded, isSelected: exists))
        }

        // Custom paths persisted by the user
        for (i, path) in persistedCustomPaths.enumerated() {
            let expanded = (path as NSString).expandingTildeInPath
            let name = URL(fileURLWithPath: expanded).lastPathComponent
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
            result.append(ScanTarget(id: "custom.\(i)", name: name, path: expanded, isSelected: exists))
        }

        scanTargets = result
    }

    // MARK: - Custom Paths Persistence

    private var persistedCustomPaths: [String] {
        get { defaults.stringArray(forKey: customPathsKey) ?? [] }
        set { defaults.set(newValue, forKey: customPathsKey) }
    }

    /// Add a custom scan directory and persist it.
    func addCustomPath(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { return }
        // Avoid duplicates
        let all = scanTargets.map(\.path)
        guard !all.contains(expanded) else { return }
        var paths = persistedCustomPaths
        paths.append(path) // store the un-expanded form
        persistedCustomPaths = paths
        rebuildTargets()
        // Auto-select the newly added target
        if let idx = scanTargets.firstIndex(where: { $0.path == expanded }) {
            scanTargets[idx].isSelected = true
        }
    }

    /// Remove a custom target by id. Built-in presets cannot be removed.
    func removeTarget(_ id: String) {
        guard id.hasPrefix("custom.") else { return } // only custom targets
        guard let idx = scanTargets.firstIndex(where: { $0.id == id }) else { return }
        let path = scanTargets[idx].path
        var paths = persistedCustomPaths
        // Find and remove the matching raw path
        let raw = paths.first { ($0 as NSString).expandingTildeInPath == path }
        if let raw { paths.removeAll { $0 == raw } }
        persistedCustomPaths = paths
        rebuildTargets()
    }

    /// Toggle a scan target's selection state.
    func toggleTarget(_ id: String) {
        guard let idx = scanTargets.firstIndex(where: { $0.id == id }) else { return }
        scanTargets[idx].isSelected.toggle()
    }

    /// Select or deselect all targets.
    func selectAllTargets(_ select: Bool) {
        for i in scanTargets.indices { scanTargets[i].isSelected = select }
    }

    /// Whether at least one target is selected.
    var hasSelectedTargets: Bool {
        scanTargets.contains(where: \.isSelected)
    }

    /// Whether a target id refers to a custom (user-added) entry.
    func isCustomTarget(_ id: String) -> Bool {
        id.hasPrefix("custom.")
    }

    /// The targets currently toggled on.
    private var activeTargets: [(name: String, path: String)] {
        scanTargets.filter(\.isSelected).map { ($0.name, $0.path) }
    }

    func startScan() {
        let targets = activeTargets
        guard !targets.isEmpty else { return }

        state = .scanning(progress: ScanProgress(
            currentItem: 0, totalItems: targets.count,
            currentPath: "", elapsedSeconds: 0, scannedBytes: 0
        ))
        let start = Date()
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            var entries: [PurgeEntry] = []
            var totalSize: Int64 = 0
            for (i, target) in targets.enumerated() {
                if Task.isCancelled { return }
                let expanded = target.path
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
                    await MainActor.run { [weak self] in
                        guard let self, case .scanning(let p) = self.state else { return }
                        self.state = .scanning(progress: ScanProgress(
                            currentItem: i+1, totalItems: targets.count,
                            currentPath: target.path,
                            elapsedSeconds: Int(Date().timeIntervalSince(start)),
                            scannedBytes: totalSize
                        ))
                    }
                    continue
                }
                let size = directorySize(expanded)
                totalSize += size
                entries.append(PurgeEntry(
                    id: target.name, name: target.name,
                    path: expanded, size: size,
                    category: "Project Artifacts"
                ))
                await MainActor.run { [weak self] in
                    guard let self, case .scanning(let p) = self.state else { return }
                    self.state = .scanning(progress: ScanProgress(
                        currentItem: i+1, totalItems: targets.count,
                        currentPath: target.path,
                        elapsedSeconds: Int(Date().timeIntervalSince(start)),
                        scannedBytes: totalSize
                    ))
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
            var removedCount = 0
            var failedCount = 0
            for entry in toPurge {
                if Task.isCancelled { break }
                let size = directorySize(entry.path)
                do {
                    try FileManager.default.removeItem(atPath: entry.path)
                    freed += size
                    removedCount += 1
                    log.append("Removed \(entry.name) (\(formatBytes(size)))")
                } catch {
                    failedCount += 1
                    log.append("Failed: \(entry.name) — \(error.localizedDescription)")
                }
                await MainActor.run { self?.state = .running(log: log) }
            }
            await MainActor.run {
                self?.state = .done(freedBytes: freed, itemsRemoved: removedCount, itemsFailed: failedCount)
            }
        }
    }

    func reset() {
        scanTask?.cancel(); scanTask = nil
        state = .idle
        selectedPaths = []
        errorMessage = nil
        rebuildTargets()
    }
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
