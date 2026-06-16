import SwiftUI
import AppKit
import os

extension Notification.Name {
    /// Posted when the user wants to show the Settings pane (Cmd-, or gear button).
    static let showSettingsPane = Notification.Name("com.moler.showSettingsPane")
}

/// The central application delegate — owns the window, orchestrates startup.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    private var windowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the main menu (Cmd-, → Settings)
        setupMainMenu()

        // No `mo` engine yet → guided install instead of a dead-end quit.
        // Discovery can shell out to `which mo`, so run off main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = MoleCLI.findExecutable() != nil
            DispatchQueue.main.async {
                guard let self else { return }
                if found {
                    NSApp.setActivationPolicy(.regular)
                    self.openMainWindow()
                } else {
                    NSApp.setActivationPolicy(.regular)
                    self.showInstallWindow()
                }
            }
        }
    }

    // MARK: - Main Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(
            title: "\(L10n.settingsWindowTitle)...",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Moler",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsFromMenu() {
        openSettingsWindow()
    }

    // MARK: - Install Window

    private var installWC: NSWindowController?

    /// Guided install window when `mo` is missing.
    private func showInstallWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        let view = MoleInstallView(onReady: { [weak self] in
            self?.installWC?.close()
            self?.installWC = nil
            self?.openMainWindow()
        })
        window.contentViewController = NSHostingController(rootView: view)
        let wc = NSWindowController(window: window)
        installWC = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Main Window

    /// Opens (or re-opens) the single-window hosting RootView.
    func openMainWindow() {
        if let controller = windowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = RootView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Moler"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.titled)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.miniaturizable)
        window.styleMask.insert(.resizable)
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.055, green: 0.078, blue: 0.122, alpha: 1.0) // #0e141f
        window.setContentSize(NSSize(width: 900, height: 640))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings

    /// Posts a notification to RootView to switch the content pane to Settings.
    @objc func openSettingsWindow() {
        NotificationCenter.default.post(name: .showSettingsPane, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Switch back to accessory policy when window is closed (menu bar mode)
        NSApp.setActivationPolicy(.accessory)
    }
}
