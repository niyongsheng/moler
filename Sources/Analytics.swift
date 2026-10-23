import Foundation
import Aptabase

/// Privacy-first usage analytics backed by Aptabase.
///
/// Aptabase is anonymised by design: no cookies, no device identifiers and
/// no cross-app tracking. The SDK automatically attaches OS version, app
/// version, locale and device model — never anything from the user's disk.
/// Keep it that way: event properties must stay non-identifying. Counts and
/// byte sizes are fine; paths, file names and app names are not.
enum Analytics {

    /// Aptabase app key (US region).
    private static let appKey = "A-US-7709260850"

    /// Every event the app reports. Raw values are the dashboard names.
    enum Event: String {
        /// Cold app launch.
        case appStarted          = "app_started"
        /// User switched to another pane.
        case screenViewed        = "screen_viewed"
        /// A Clean run finished.
        case cleanCompleted      = "clean_completed"
        /// A Purge run finished.
        case purgeCompleted      = "purge_completed"
        /// An Optimize run finished.
        case optimizeCompleted   = "optimize_completed"
        /// An Analyze scan finished.
        case analyzeCompleted    = "analyze_completed"
        /// A Software uninstall run finished.
        case softwareUninstalled = "software_uninstalled"
        /// The `mo` CLI was missing at launch (install window shown).
        case moleMissing         = "mole_missing"
        /// The user explicitly checked for updates.
        case updateChecked       = "update_checked"
    }

    // MARK: - Lifecycle

    /// Call once, as early as possible in `applicationDidFinishLaunching`.
    /// Must run on the main thread: the SDK's delivery timer uses the main run loop.
    static func configure() {
        Aptabase.shared.initialize(appKey: appKey)
    }

    // MARK: - Tracking

    /// Track an event with optional string/number/bool properties.
    /// Returns immediately — delivery happens in the background.
    static func track(_ event: Event, _ props: [String: Any] = [:]) {
        Aptabase.shared.trackEvent(event.rawValue, with: props)
    }

    /// Convenience for screen-view events.
    static func screen(_ name: String) {
        track(.screenViewed, ["screen": name])
    }
}
