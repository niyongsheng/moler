import Foundation
import SwiftUI

// MARK: - ViewModel

@MainActor
final class SoftwareViewModel: ObservableObject {

    @Published var state: SoftwareState = .idle
    @Published var errorMessage: String?

    // App list state
    @Published var query: String = ""
    @Published var sortByName = true
    @Published var sortAscending = true
    @Published var selected: Set<String> = []
    @Published var expandedAppID: String?
    @Published var previews: [String: UninstallPreview] = [:]
    @Published var previewLoading: Set<String> = []
    @Published var pathSelections: [String: Set<String>] = [:]

    private(set) var allApps: [InstalledApp] = []

    // MARK: - Computed

    var filteredApps: [InstalledApp] {
        var apps = allApps
        if !query.isEmpty {
            let q = query.lowercased()
            apps = apps.filter { $0.name.lowercased().contains(q) || $0.bundleId.lowercased().contains(q) }
        }
        if sortByName {
            apps.sort { sortAscending ? $0.name < $1.name : $0.name > $1.name }
        } else {
            apps.sort { sortAscending ? $0.sizeBytes < $1.sizeBytes : $0.sizeBytes > $1.sizeBytes }
        }
        return apps
    }

    var selectedApps: [InstalledApp] {
        allApps.filter { selected.contains($0.id) }
    }

    var selectionLabel: String {
        let apps = selectedApps
        guard !apps.isEmpty else { return "" }
        let total = apps.reduce(0) { $0 + $1.sizeBytes }
        if apps.count == 1 {
            return "\(apps[0].name) · \(apps[0].sizeStr)"
        }
        return String(format: L10n.softwareSelectionCount, apps.count, Format.bytes(total))
    }

    // MARK: - Actions

    func loadAppList() {
        guard case .idle = state else { return }
        state = .loading

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try MoEngine.shared.uninstallList()
                guard result.exitCode == 0 else {
                    throw MoleError.failed(exitCode: result.exitCode, stderr: result.stderr)
                }

                let apps = SoftwareUninstallParser.parseAppListJSON(Data(result.stdout.utf8))

                // Prewarm icon cache synchronously BEFORE the view renders,
                // so every icon(for:) call hits the cache immediately.
                SoftwareIcons.prewarm(apps)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.allApps = apps
                    self.selected = []
                    self.previews = [:]
                    self.pathSelections = [:]
                    self.expandedAppID = nil
                    self.state = .loaded
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.state = .error(error.localizedDescription)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancel() {
        state = .idle
        errorMessage = nil
    }

    func reset() {
        state = .idle
        errorMessage = nil
        allApps = []
        selected = []
        previews = [:]
        pathSelections = [:]
        expandedAppID = nil
        query = ""
    }

    func toggleSelection(_ id: String) {
        if selected.contains(id) { selected.remove(id) }
        else { selected.insert(id) }
    }

    func clearSelection() {
        selected.removeAll()
    }

    func toggleExpansion(_ app: InstalledApp) {
        if expandedAppID == app.id {
            expandedAppID = nil
            return
        }

        expandedAppID = app.id

        // If we already have the preview, just show it
        guard previews[app.id] == nil else { return }

        previewLoading.insert(app.id)

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try MoEngine.shared.uninstallDryRun(name: app.uninstallName)
                let preview = SoftwareUninstallParser.parseDryRunOutput(result.stdout)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.previews[app.id] = preview
                    self.previewLoading.remove(app.id)
                    // Default selections based on autoSelected
                    var selections: Set<String> = []
                    for entry in preview.entries where entry.kind.autoSelected {
                        selections.insert(entry.path)
                    }
                    self.pathSelections[app.id] = selections
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.previewLoading.remove(app.id)
                    self.previews[app.id] = UninstallPreview(entries: [])
                }
            }
        }
    }

    func toggleFileSelection(appID: String, path: String) {
        var sels = pathSelections[appID] ?? []
        if sels.contains(path) { sels.remove(path) }
        else { sels.insert(path) }
        pathSelections[appID] = sels
    }

    func confirmAndRemove() {
        guard !selectedApps.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = L10n.softwareConfirmTitle
        alert.informativeText = String(format: L10n.softwareConfirmMessage, selectedApps.count)
        alert.addButton(withTitle: L10n.softwareRemove)
        alert.addButton(withTitle: L10n.softwareCancel)

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let apps = selectedApps
        state = .running(detail: "\(L10n.softwareRemoving) \(apps[0].name)...")

        Task.detached(priority: .userInitiated) { [weak self] in
            var totalRemoved = 0
            var totalBytes: Int64 = 0
            var failures: [UninstallFailure] = []
            var removedIDs: Set<String> = []
            let start = Date()

            for app in apps {
                do {
                    let result = try MoEngine.shared.uninstall(name: app.uninstallName)
                    // Mole can exit 0 while skipping an app (for example when
                    // a vendor uninstaller is required). The bundle still
                    // being on disk is the reliable success signal.
                    if FileManager.default.fileExists(atPath: app.path) {
                        failures.append(UninstallFailure(
                            appName: app.name,
                            reason: SoftwareUninstallParser.failureReason(
                                from: result, appName: app.name
                            )
                        ))
                    } else {
                        totalRemoved += 1
                        totalBytes += app.sizeBytes
                        removedIDs.insert(app.id)
                    }
                    // Update progress text for next app
                    let done = totalRemoved + failures.count
                    if apps.count > 1, done < apps.count {
                        let next = apps[done]
                        await MainActor.run { [weak self] in
                            self?.state = .running(detail: "\(L10n.softwareRemoving) \(next.name)...")
                        }
                    }
                } catch {
                    failures.append(UninstallFailure(
                        appName: app.name,
                        reason: error.localizedDescription
                    ))
                }
            }

            let duration = Int(Date().timeIntervalSince(start))

            await MainActor.run { [weak self] in
                guard let self else { return }
                let result = UninstallResult(
                    appNames: apps.map(\.name),
                    filesRemoved: totalRemoved,
                    bytesFreed: totalBytes,
                    failures: failures,
                    durationSeconds: duration,
                    timestamp: Date()
                )
                Store.shared.recordSoftwareUninstall(appsRemoved: totalRemoved, bytesFreed: totalBytes)
                Analytics.track(.softwareUninstalled, [
                    "apps_removed": totalRemoved,
                    "apps_failed": failures.count,
                    "bytes_freed": Int(totalBytes),
                ])
                self.state = .done(result: result)
                // Keep failed apps in the list so a retry doesn't require a rescan.
                self.allApps = self.allApps.filter { !removedIDs.contains($0.id) }
                self.selected = []
                self.previews = [:]
                self.expandedAppID = nil
            }
        }
    }
}
