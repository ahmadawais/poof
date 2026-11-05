import AppKit
import OSLog

let log = Logger(subsystem: "com.ahmadawais.poof", category: "app")

/// Windows, menus, the status item and the timer. Behaviour lives in `Controller`.
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var controller: Controller!
    private let hotKey = HotKey()
    private var timer: Timer?
    private var interval = 0.0

    public override init() { super.init() }

    static var now: Double { ProcessInfo.processInfo.systemUptime }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        LoginItem.apply()
        controller = Controller(cursor: SystemCursor(), probe: SystemProbe(), now: Self.now)
        controller.onChange = { [weak self] in self?.reschedule() }
        hotKey.action = { [weak self] in self?.controller.toggle(now: Self.now) }
        hotKey.register()
        installMainMenu()
        updateStatusItem()
        reschedule()
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appActivated),
                                                          name: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        controller?.show(now: Self.now)
    }

    /// Launching again (Spotlight, Finder) opens Settings — the way back when the icon is hidden.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    // MARK: Timer — fast while hidden, slow while visible

    private func reschedule() {
        let next = controller.pollInterval
        guard next != interval || timer == nil else { return }
        interval = next
        timer?.invalidate()
        let t = Timer(timeInterval: next, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.tick() }
        }
        t.tolerance = next / 5
        RunLoop.main.add(t, forMode: .common)   // keeps running while a menu is open
        timer = t
    }

    private func tick() {
        controller.tick(now: Self.now)
    }

    @objc private func appActivated() { controller.appSwitched() }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async { [weak self] in self?.updateStatusItem() }
    }

    // MARK: Menu bar

    private let toggleItem = NSMenuItem(title: "Hide Cursor", action: #selector(toggleCursor), keyEquivalent: "k")
    private let idleItem = NSMenuItem(title: "Hide When Idle", action: #selector(toggleIdle), keyEquivalent: "")

    private func updateStatusItem() {
        guard Prefs.showMenuIcon else {
            if let s = statusItem { NSStatusBar.system.removeStatusItem(s) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let s = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "cursorarrow.slash", accessibilityDescription: "Poof")
        image?.isTemplate = true
        s.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        toggleItem.target = self
        idleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(idleItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Poof", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        s.menu = menu
        statusItem = s
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = controller.isHidden ? "Show Cursor" : "Hide Cursor"
        idleItem.state = Prefs.hideWhenIdle ? .on : .off
    }

    @objc private func toggleCursor() { controller.toggle(now: Self.now) }
    @objc private func toggleIdle() { Prefs.hideWhenIdle.toggle() }
    @objc private func openSettingsMenu() { openSettings() }

    private func openSettings() {
        controller.show(now: Self.now)
        if settingsWindow == nil { settingsWindow = SettingsWindow.make(hotKeyOK: hotKey.isRegistered) }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Settings + Quit with their shortcuts while the Settings window is in front.
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit Poof", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
}
