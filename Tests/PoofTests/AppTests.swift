import AppKit
import ServiceManagement
import Testing
@testable import PoofKit

/// Suites that touch global state (Prefs, AppKit) run one at a time.
@Suite(.serialized) struct SharedState {}

enum Env {
    /// Fresh, isolated preferences for one test — never the user's real ones.
    @discardableResult
    static func prefs() -> UserDefaults {
        let d = UserDefaults(suiteName: "com.ahmadawais.poof.tests.\(UUID().uuidString)")!
        Prefs.d = d
        Prefs.register()
        return d
    }
}

/// Records calls instead of touching the real pointer.
final class FakeCursor: CursorDriver {
    var calls: [String] = []
    var hidden = false
    func hide() { calls.append("hide"); hidden = true }
    func show() { calls.append("show"); hidden = false }
    func reassert() { calls.append("reassert") }
}

final class FakeProbe: PointerProbe {
    var location = CGPoint(x: 100, y: 100)
    var lastClickAt = -1000.0
    var now = 0.0
    var secondsSinceClick: Double { now - lastClickAt }
    func click() { lastClickAt = now }
}

/// A controller driven by a fake clock: `run(to:)` ticks every 0.1 s like the real timer.
final class Rig {
    let cursor = FakeCursor()
    let probe = FakeProbe()
    let c: Controller
    var changes = 0

    init() {
        c = Controller(cursor: cursor, probe: probe, now: 0)
        c.onChange = { [unowned self] in changes += 1 }
    }

    func run(to t: Double) {
        while probe.now + 0.1 <= t + 1e-9 { probe.now += 0.1; c.tick(now: probe.now) }
    }
    func move(by d: CGFloat = 10) { probe.location.x += d }
    func toggle() { c.toggle(now: probe.now) }
}

extension SharedState {
    struct PrefsTests {
        init() { Env.prefs() }

        @Test("Defaults: idle hide on after 3 s, no shortcut, no menu icon, launch at login")
        func defaults() {
            #expect(Prefs.hideWhenIdle)
            #expect(Prefs.idleDelay == 3)
            #expect(!Prefs.shortcutEnabled)
            #expect(!Prefs.showMenuIcon)
            #expect(Prefs.showOnMove)
            #expect(LoginItem.enabled)
        }

        @Test("Idle delay is clamped to 1…60 s", arguments: [(0.0, 1.0), (-5, 1), (0.4, 1), (7, 7), (600, 60)])
        func clamp(input: Double, expected: Double) {
            Prefs.idleDelay = input
            #expect(Prefs.idleDelay == expected)
        }

        @Test("Preferences are isolated per test")
        func isolated() {
            Prefs.showOnMove = false
            Env.prefs()
            #expect(Prefs.showOnMove)
        }
    }

    /// Timing tests pin the delay to 5 s, so they don't depend on the default.
    struct IdleTests {
        init() { Env.prefs(); Prefs.idleDelay = 5 }

        @Test("Hides after the idle delay, not before")
        func hidesAfterDelay() {
            let r = Rig()
            r.run(to: 4.8)
            #expect(!r.c.isHidden)
            r.run(to: 5.1)
            #expect(r.c.hidden == .idle)
            #expect(r.cursor.calls == ["hide"])
        }

        @Test("Moving resets the countdown")
        func moveResets() {
            let r = Rig()
            r.run(to: 4)
            r.move()
            r.run(to: 8.5)
            #expect(!r.c.isHidden)
            r.run(to: 9.2)
            #expect(r.c.isHidden)
        }

        @Test("Clicking without moving resets the countdown")
        func clickResets() {
            let r = Rig()
            r.run(to: 4)
            r.probe.click()
            r.run(to: 8.5)
            #expect(!r.c.isHidden)
        }

        @Test("Trackpad jitter under 2 pt is not movement")
        func jitter() {
            let r = Rig()
            r.run(to: 3)
            r.move(by: 1.5)
            r.run(to: 5.1)
            #expect(r.c.isHidden)
        }

        @Test("Small moves that add up past 2 pt count")
        func drift() {
            let r = Rig()
            r.run(to: 5.1)
            #expect(r.c.isHidden)
            r.move(by: 1.5); r.run(to: 5.2)
            #expect(r.c.isHidden)
            r.move(by: 1.5); r.run(to: 5.3)
            #expect(!r.c.isHidden)
        }

        @Test("Moving brings an idle-hidden cursor back, then it hides again after the delay")
        func comesBack() {
            let r = Rig()
            r.run(to: 5.1)
            r.move()
            r.run(to: 5.2)
            #expect(!r.c.isHidden)
            r.run(to: 10.3)
            #expect(r.c.isHidden)
            #expect(r.cursor.calls == ["hide", "show", "hide"])
        }

        @Test("A click brings an idle-hidden cursor back")
        func clickShows() {
            let r = Rig()
            r.run(to: 5.1)
            r.probe.click()
            r.run(to: 5.2)
            #expect(!r.c.isHidden)
        }

        @Test("Idle hide off: never hides on its own")
        func off() {
            Prefs.hideWhenIdle = false
            let r = Rig()
            r.run(to: 120)
            #expect(r.cursor.calls.isEmpty)
        }

        @Test("Delay change applies without restarting")
        func liveDelay() {
            let r = Rig()
            r.run(to: 2)
            Prefs.idleDelay = 1
            r.run(to: 2.1)
            #expect(r.c.isHidden)
        }
    }

    struct ShortcutTests {
        init() { Env.prefs(); Prefs.idleDelay = 5 }

        @Test("⌃⌥K hides at once and again shows")
        func toggles() {
            let r = Rig()
            r.toggle()
            #expect(r.c.hidden == .shortcut)
            r.toggle()
            #expect(!r.c.isHidden)
            #expect(r.cursor.calls == ["hide", "show"])
            #expect(r.changes == 2)
        }

        @Test("⌃⌥K over an idle-hidden cursor shows it")
        func overIdle() {
            let r = Rig()
            r.run(to: 5.1)
            r.toggle()
            #expect(!r.c.isHidden)
        }

        @Test("Shown by ⌃⌥K, the idle countdown starts over")
        func restartsCountdown() {
            let r = Rig()
            r.run(to: 1)
            r.toggle()
            r.run(to: 30)          // still: hidden by shortcut, stays hidden
            #expect(r.c.hidden == .shortcut)
            r.toggle()
            r.run(to: 34.8)
            #expect(!r.c.isHidden)
            r.run(to: 35.2)
            #expect(r.c.hidden == .idle)
        }

        @Test("Show when moved on: moving brings it back")
        func moveShows() {
            let r = Rig()
            r.toggle()
            r.move()
            r.run(to: 0.1)
            #expect(!r.c.isHidden)
        }

        @Test("Movement before ⌃⌥K doesn't undo it")
        func staleMove() {
            let r = Rig()
            r.move()               // moved, but no tick read it yet
            r.toggle()
            r.run(to: 0.3)
            #expect(r.c.isHidden)
        }

        @Test("Show when moved off: moving keeps it hidden, clicks re-hide, only ⌃⌥K shows")
        func stayHidden() {
            Prefs.showOnMove = false
            let r = Rig()
            r.toggle()
            r.move(); r.run(to: 0.5)
            #expect(r.c.hidden == .shortcut)
            r.probe.click(); r.run(to: 0.6)
            #expect(r.c.hidden == .shortcut)
            #expect(r.cursor.calls == ["hide", "reassert"])
            r.run(to: 60)          // idle never takes over a shortcut hide
            #expect(r.c.hidden == .shortcut)
            r.toggle()
            #expect(!r.c.isHidden)
        }

        @Test("App switch re-hides only while hidden")
        func appSwitch() {
            let r = Rig()
            r.c.appSwitched()
            #expect(r.cursor.calls.isEmpty)
            r.toggle()
            r.c.appSwitched()
            #expect(r.cursor.calls == ["hide", "reassert"])
        }

        @Test("show() when visible does nothing")
        func showIdempotent() {
            let r = Rig()
            r.c.show(now: 0)
            #expect(r.cursor.calls.isEmpty)
            #expect(r.changes == 0)
        }

        @Test("Polls fast only while hidden")
        func interval() {
            let r = Rig()
            #expect(r.c.pollInterval == Controller.visibleInterval)
            r.toggle()
            #expect(r.c.pollInterval == Controller.hiddenInterval)
        }
    }

    struct LoginItemTests {
        @Test("Login item steps", arguments: [
            (true, SMAppService.Status.notRegistered, LoginItem.Step.register),
            (true, .notFound, .register),
            (true, .enabled, .nothing),
            (true, .requiresApproval, .nothing),
            (false, .enabled, .unregister),
            (false, .notRegistered, .nothing),
        ])
        func steps(enabled: Bool, status: SMAppService.Status, step: LoginItem.Step) {
            #expect(LoginItem.step(enabled: enabled, status: status) == step)
        }
    }

    @MainActor
    struct SystemTests {
        @Test("⌃⌥K registers system-wide")
        func hotKey() {
            _ = NSApplication.shared
            let h = HotKey()
            #expect(h.register())
            #expect(h.isRegistered)
            h.unregister()
            #expect(!h.isRegistered)
        }

        @Test("Real cursor: hide/show stay balanced at 0 or 1")
        func balanced() {
            _ = NSApplication.shared
            let c = SystemCursor()
            c.show()
            #expect(!c.isHidden)
            c.hide(); c.hide()
            #expect(c.isHidden)
            c.show()
            #expect(!c.isHidden)
            c.show()
            #expect(!c.isHidden)
        }

        @Test("Settings window uses golden-ratio tabs")
        func goldenRatio() throws {
            _ = NSApplication.shared
            Env.prefs()
            let window = SettingsWindow.make()
            let tabs = try #require(window.contentViewController as? NSTabViewController)
            #expect(tabs.tabStyle == .toolbar)
            #expect(tabs.tabViewItems.map(\.label) == ["General", "Shortcut", "Privacy"])
            #expect(SettingsWindow.short == 346)
        }

        /// Renders every tab to .build/renders/*.png — open them and look before calling the UI done.
        @Test("Render settings for review", arguments: [NSAppearance.Name.aqua, .darkAqua])
        func render(appearance: NSAppearance.Name) throws {
            _ = NSApplication.shared
            Env.prefs()
            let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../.build/renders").standardized
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for on in [false, true] {
                Prefs.shortcutEnabled = on
                let window = SettingsWindow.make()
                window.appearance = NSAppearance(named: appearance)
                let tabs = try #require(window.contentViewController as? NSTabViewController)
                tabs.transitionOptions = []
                for i in tabs.tabViewItems.indices where !on || i == 1 {
                    tabs.selectedTabViewItemIndex = i
                    window.layoutIfNeeded()
                    let view = try #require(window.contentView?.superview)
                    view.layoutSubtreeIfNeeded()
                    let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: rep)
                    let png = try #require(rep.representation(using: .png, properties: [:]))
                    let name = "settings-\(appearance == .aqua ? "light" : "dark")-\(tabs.tabViewItems[i].label)\(on ? "-on" : "").png"
                    try png.write(to: dir.appendingPathComponent(name))
                }
            }
        }
    }
}
