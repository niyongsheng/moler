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

struct UninstallResult: Equatable {
    let appNames: [String]
    let filesRemoved: Int
    let bytesFreed: Int64
    let durationSeconds: Int
    let timestamp: Date
}
