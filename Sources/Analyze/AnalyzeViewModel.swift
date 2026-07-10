import UniformTypeIdentifiers
import Foundation
import SwiftUI

// MARK: - Path Picker Types

/// A quick-select scan target shown as a pill button in the idle view.
struct ScanPreset: Identifiable, Equatable {
    let id: String       // SF Symbol name
    let label: String    // Display name
    let path: String     // Absolute path
}

// MARK: - ViewModel

@MainActor
final class AnalyzeViewModel: ObservableObject {

    @Published var state: AnalyzeState = .idle
    @Published var errorMessage: String?

    /// The currently selected scan target path (default: home directory).
    @Published var selectedPath: String

    // Breadcrumb navigation stack
    private(set) var breadcrumb: [BreadcrumbItem] = []

    // Scanning state
    private var scanTask: Task<Void, Never>?
    private var scanTimer: Timer?
    private var scanStartTime: Date?

    private let homePath = FileManager.default.homeDirectoryForCurrentUser.path

    /// Common directories available as quick-select presets.
    var scanPresets: [ScanPreset] {
        let fm = FileManager.default
        return [
            ScanPreset(id: "house",           label: "Home",        path: homePath),
            ScanPreset(id: "desktopcomputer",  label: "Desktop",    path: homePath + "/Desktop"),
            ScanPreset(id: "doc.text",         label: "Documents",  path: homePath + "/Documents"),
            ScanPreset(id: "arrow.down.doc",   label: "Downloads", path: homePath + "/Downloads"),
            ScanPreset(id: "archivebox",       label: "Caches",     path: homePath + "/Library/Caches"),
        ].filter { fm.fileExists(atPath: $0.path) }
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.selectedPath = home
    }

    deinit {
        scanTimer?.invalidate()
    }

    // MARK: - Path Selection

    /// Select a scan target path (does NOT start scanning).
    func selectPath(_ path: String) {
        selectedPath = path
    }

    /// Present an NSOpenPanel for custom folder selection.
    /// Returns the selected path, or nil if cancelled.
    @MainActor
    func pickFolder() async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to analyze"
        panel.prompt = "Select"

        let response = panel.runModal()
        return response == .OK ? panel.url?.path : nil
    }

    // MARK: - Actions

    /// Start scanning the currently selected path.
    func startScan() {
        performScan(path: selectedPath)
    }

    /// Start scanning a specific directory.
    func startScan(path: String) {
        selectedPath = path
        performScan(path: path)
    }

    /// Drill into a subdirectory by re-scanning its path.
    func drillInto(entry: DiskScanEntry) {
        guard entry.isDir else { return }
        breadcrumb.append(BreadcrumbItem(id: entry.path, name: entry.name))
        performScan(path: entry.path)
    }

    /// Navigate to a specific breadcrumb level (truncate stack and re-scan).
    func navigateToCrumb(_ item: BreadcrumbItem) {
        guard let idx = breadcrumb.firstIndex(where: { $0.id == item.id }) else { return }
        breadcrumb = Array(breadcrumb.prefix(upTo: idx + 1))
        performScan(path: item.id)
    }

    /// Pop the last breadcrumb and go back.
    func goBack() {
        guard breadcrumb.count > 1 else { return }
        breadcrumb.removeLast()
        if let parent = breadcrumb.last {
            performScan(path: parent.id)
        }
    }

    /// Go back to the root of the current scan tree (the directory that was
    /// originally selected before any drill-down).
    func goHome() {
        let rootPath = breadcrumb.first?.id ?? homePath
        breadcrumb.removeAll()
        performScan(path: rootPath)
    }

    /// Cancel the current scan.
    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        scanTimer?.invalidate()
        scanTimer = nil
        state = .idle
        errorMessage = nil
    }

    /// Reset to idle.
    func reset() {
        cancel()
        breadcrumb.removeAll()
    }

    // MARK: - Private

    private func performScan(path: String) {
        // Cancel any existing scan
        scanTask?.cancel()
        scanTask = nil
        scanTimer?.invalidate()

        scanStartTime = Date()

        // Start elapsed timer
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, case .scanning(let p) = self.state else { return }
            let elapsed = Int(Date().timeIntervalSince(self.scanStartTime ?? Date()))
            self.state = .scanning(progress: AnalyzeProgress(currentPath: p.currentPath, elapsedSeconds: elapsed))
        }

        state = .scanning(progress: AnalyzeProgress(currentPath: path, elapsedSeconds: 0))

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try DiskScanner.scan(path)

                try Task.checkCancellation()

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    // Initialise breadcrumb stack if empty
                    if self.breadcrumb.isEmpty {
                        let name = URL(fileURLWithPath: result.path).lastPathComponent
                        self.breadcrumb = [BreadcrumbItem(id: result.path, name: name.isEmpty ? "~" : name)]
                    }

                    self.scanTimer?.invalidate()
                    self.scanTimer = nil
                    self.state = .loaded(result: result, breadcrumb: self.breadcrumb)
                    self.errorMessage = nil
                    Store.shared.recordAnalyze(path: result.path)
                }
            } catch is CancellationError {
                // Silently handle cancellation
                await MainActor.run { [weak self] in
                    self?.scanTimer?.invalidate()
                    self?.scanTimer = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.scanTimer?.invalidate()
                    self.scanTimer = nil
                    self.state = .error(error.localizedDescription)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
