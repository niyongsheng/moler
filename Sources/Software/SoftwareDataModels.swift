import Foundation

// MARK: - State Machine

enum SoftwareState: Equatable {
    case idle
    case loading
    case loaded
    case running(detail: String)
    case done(result: UninstallResult)
    case error(String)
}

// MARK: - Installed App

struct InstalledApp: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleId: String
    let source: String
    let uninstallName: String
    let path: String
    let sizeStr: String
    let sizeBytes: Int64
}

// MARK: - Uninstall Preview

struct UninstallPreview: Equatable {
    enum Kind: String, Equatable, CaseIterable {
        case application
        case appSupport
        case preferences
        case container
        case groupContainer
        case helper
        case loginItem
        case cache
        case log
        case other

        var autoSelected: Bool {
            switch self {
            case .application, .appSupport, .preferences, .container, .helper, .loginItem:
                return true
            case .cache, .log, .groupContainer, .other:
                return false
            }
        }

        var label: String {
            switch self {
            case .application:   return "App Bundle"
            case .appSupport:    return "Application Support"
            case .preferences:   return "Preferences"
            case .container:     return "App Container"
            case .groupContainer: return "Group Container"
            case .helper:        return "Helper/Tool"
            case .loginItem:     return "Login Item"
            case .cache:         return "Cache"
            case .log:           return "Logs"
            case .other:         return "Other Files"
            }
        }
    }

    struct Entry: Identifiable, Equatable {
        let path: String
        let kind: Kind
        var id: String { path }
    }

    let entries: [Entry]
    var isEmpty: Bool { entries.isEmpty }
}

// MARK: - Uninstall Result

/// A selected app that `mo uninstall` did not remove.
///
/// Mole can exit 0 while skipping an app (for example when a vendor
/// uninstaller is required), so callers also verify the bundle is gone.
struct UninstallFailure: Equatable {
    let appName: String
    let reason: String?
}

struct UninstallResult: Equatable {
    let appNames: [String]
    /// Number of apps successfully removed.
    let filesRemoved: Int
    let bytesFreed: Int64
    let failures: [UninstallFailure]
    let durationSeconds: Int
    let timestamp: Date

    /// Names of the apps that were not removed.
    var failedAppNames: [String] { failures.map(\.appName) }
}
