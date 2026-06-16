import Foundation
import AppKit

/// Detects whether the app has Full Disk Access (FDA).
/// FDA is required for scanning and cleaning files outside the app's sandbox.
enum Privacy {

    /// Check if Full Disk Access is granted.
    /// Tries to open a TCC-protected file; success = FDA is active.
    /// The file contents are never read — it's a pure capability probe.
    static func hasFullDiskAccess() -> Bool {
        // Try Safari bookmarks (TCC-protected).
        let safariPath = NSString(string: "~/Library/Safari/Bookmarks.plist")
            .expandingTildeInPath
        if access(safariPath, R_OK) == 0 {
            return true
        }

        // Try the TCC database itself (most protected).
        let tccPath = NSString(string: "~/Library/Application Support/com.apple.TCC/TCC.db")
            .expandingTildeInPath
        if access(tccPath, R_OK) == 0 {
            return true
        }

        return false
    }

    /// Open System Settings to the Full Disk Access preference pane.
    static func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    /// Show an alert guiding the user to grant Full Disk Access.
    static func showFDAPrompt() {
        let alert = NSAlert()
        alert.messageText = L10n.privacyTitle
        alert.informativeText = L10n.privacyMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.privacyOpenSettings)
        alert.addButton(withTitle: L10n.privacyLater)
        if alert.runModal() == .alertFirstButtonReturn {
            openFullDiskAccessSettings()
        }
    }
}
