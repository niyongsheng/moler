import Foundation
import AppKit

/// Owns the update lifecycle: automatic checks at launch, manual checks,
/// download progress and the hand-off to `UpdateInstaller`.
///
/// Automatic *checks* happen without asking. Automatic *installs* never do:
/// the user always confirms before the app replaces itself and relaunches.
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateChecker.Release)
        case downloading(progress: Double)
        case installing
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle

    /// Persisted preference — on by default.
    @Published var autoCheckEnabled: Bool {
        didSet { defaults.set(autoCheckEnabled, forKey: Key.autoCheck) }
    }

    private enum Key {
        static let autoCheck = "moler.autoUpdateCheck"
        static let lastCheck = "moler.lastUpdateCheck"
    }

    private let defaults = UserDefaults.standard
    private var lastCheckDate: Date?

    private init() {
        // `object(forKey:)` distinguishes "never set" (default true) from
        // an explicit false.
        self.autoCheckEnabled = (defaults.object(forKey: Key.autoCheck) as? Bool) ?? true
        self.lastCheckDate = defaults.object(forKey: Key.lastCheck) as? Date
    }

    // MARK: - Derived

    var hasUpdate: Bool {
        if case .available = state { return true }
        return false
    }

    var availableVersion: String? {
        if case .available(let release) = state { return release.version }
        return nil
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    // MARK: - Launch Check

    /// Called once at launch. Checks silently (failure or "up to date" shows
    /// nothing) at most once a day. A newer release flips the sidebar badge.
    func start() {
        guard autoCheckEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.autoCheckEnabled else { return }
            self.check(userInitiated: false)
        }
    }

    // MARK: - Checking

    func check(userInitiated: Bool) {
        guard !isBusy else { return }
        if !userInitiated,
           let last = lastCheckDate,
           Date().timeIntervalSince(last) < 24 * 60 * 60 {
            return
        }
        runCheck(userInitiated: userInitiated)
    }

    private func runCheck(userInitiated: Bool) {
        state = .checking
        Task {
            do {
                let release = try await UpdateChecker.fetchLatest()
                let now = Date()
                lastCheckDate = now
                defaults.set(now, forKey: Key.lastCheck)

                if UpdateChecker.isNewer(release.version, than: UpdateChecker.currentVersion) {
                    state = .available(release)
                    Analytics.track(.updateChecked,
                                    ["result": "available", "manual": userInitiated])
                } else {
                    state = userInitiated ? .upToDate : .idle
                    Analytics.track(.updateChecked,
                                    ["result": "up_to_date", "manual": userInitiated])
                }
            } catch {
                // An automatic check must stay invisible when offline.
                state = userInitiated ? .failed(message: L10n.updateErrorBody) : .idle
                Analytics.track(.updateChecked,
                                ["result": "error", "manual": userInitiated])
            }
        }
    }

    // MARK: - Install

    func install() {
        guard case .available(let release) = state, let zipURL = release.zipURL else {
            if case .available(let release) = state {
                NSWorkspace.shared.open(release.url)
            }
            return
        }
        guard UpdateInstaller.canInstall else {
            NSWorkspace.shared.open(release.url)
            return
        }

        state = .downloading(progress: 0)
        Task {
            var workDirectory: URL?
            do {
                let directory = try UpdateInstaller.makeWorkDirectory()
                workDirectory = directory

                let zip = try await UpdateInstaller.download(
                    zipURL, to: directory
                ) { fraction in
                    Task { @MainActor in
                        guard case .downloading = self.state else { return }
                        self.state = .downloading(progress: fraction)
                    }
                }

                let staged = try await Task.detached(priority: .userInitiated) {
                    try UpdateInstaller.stage(
                        zip: zip, in: directory, expectedVersion: release.version
                    )
                }.value

                state = .installing
                try UpdateInstaller.beginInstall(stagedApp: staged, workDirectory: directory)
                Analytics.track(.updateInstalled, ["version": release.version])

                // Give the helper script a beat to start, then quit so it can
                // swap the bundle and relaunch.
                try? await Task.sleep(nanoseconds: 500_000_000)
                NSApp.terminate(nil)
            } catch {
                if let workDirectory {
                    try? FileManager.default.removeItem(at: workDirectory)
                }
                state = .failed(message: message(for: error))
            }
        }
    }

    private func message(for error: Error) -> String {
        if error is URLError { return L10n.updateErrorBody }
        return error.localizedDescription
    }
}
