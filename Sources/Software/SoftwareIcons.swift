import AppKit
import Foundation

/// Synchronous icon cache for app icons from NSWorkspace.
///
/// Call `prewarm(_:)` **before** the app list is displayed (on a background thread)
/// so that `icon(for:)` returns from cache immediately when the view renders.
enum SoftwareIcons {
    private static let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 200
        return c
    }()
    private static let placeholder = NSWorkspace.shared.icon(for: .applicationBundle)

    /// Return a cached icon or a placeholder. SwiftUI will re-render when the
    /// the caller triggers an update (e.g. via @Published after prewarm completes).
    static func icon(for path: String) -> NSImage {
        cache.object(forKey: path as NSString) ?? placeholder
    }

    /// Synchronously pre-warm the icon cache for every app.
    /// Call on a background queue before setting `state = .loaded`.
    static func prewarm(_ apps: [InstalledApp]) {
        for app in apps {
            let img = NSWorkspace.shared.icon(forFile: app.path)
            cache.setObject(img, forKey: app.path as NSString)
        }
    }
}
