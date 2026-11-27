import AppKit
import Combine

/// Tracks whether the app's window is actually on screen.
///
/// Continuous animations (topographic canvas, SceneKit scenes) and background
/// polling (`mo status`) are expensive; when the window is closed (menu-bar
/// mode), minimized, fully occluded, or the app is hidden, nobody can see them
/// and they should stop. Views observe this object and suspend themselves.
final class AppActivityMonitor: ObservableObject {
    static let shared = AppActivityMonitor()

    /// The window exists, is visible, not miniaturized, not hidden, and is not
    /// fully occluded by other windows.
    @Published private(set) var isWindowVisible: Bool = false

    /// The app is frontmost. Used to slow — not stop — cheap polling.
    @Published private(set) var isAppActive: Bool = NSApplication.shared.isActive

    private weak var window: NSWindow?
    private var tokens: [NSObjectProtocol] = []

    private init() {
        let nc = NotificationCenter.default
        let appNotifications: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
        ]
        for name in appNotifications {
            tokens.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
    }

    /// Start tracking the app's main window. Safe to call more than once.
    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window

        let nc = NotificationCenter.default
        let windowNotifications: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didExposeNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.willCloseNotification,
        ]
        for name in windowNotifications {
            tokens.append(nc.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
        refresh()
    }

    /// Re-evaluate the current visibility state and publish any change.
    func refresh() {
        let app = NSApplication.shared
        let visible = (window?.isVisible ?? false)
            && !(window?.isMiniaturized ?? true)
            && (window?.occlusionState.contains(.visible) ?? false)
            && !app.isHidden
        if isWindowVisible != visible { isWindowVisible = visible }
        if isAppActive != app.isActive { isAppActive = app.isActive }
    }
}
