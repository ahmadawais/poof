import AppKit

/// All of Poof's behaviour. Feed it `tick(now:)` on a timer and `toggle(now:)` from the hotkey;
/// it decides when the pointer hides and comes back.
final class Controller {
    enum Reason: Equatable { case shortcut, idle }

    /// Movement smaller than this (points) is trackpad jitter, not the user moving the pointer.
    static let jitter: CGFloat = 2
    /// Poll fast while hidden so the pointer comes back the instant it moves; slow otherwise.
    static let hiddenInterval = 1.0 / 30
    static let visibleInterval = 0.2

    private let cursor: CursorDriver
    private let probe: PointerProbe
    private(set) var hidden: Reason?
    private var lastLocation: CGPoint
    private var lastActivity: Double
    private var lastClick: Double
    var onChange: (() -> Void)?

    init(cursor: CursorDriver, probe: PointerProbe, now: Double) {
        self.cursor = cursor
        self.probe = probe
        lastLocation = probe.location
        lastActivity = now
        lastClick = now - probe.secondsSinceClick
    }

    var isHidden: Bool { hidden != nil }
    var pollInterval: Double { isHidden ? Self.hiddenInterval : Self.visibleInterval }

    /// ⌃⌥K: hide now, or bring it back.
    func toggle(now: Double) {
        if isHidden {
            show(now: now)
        } else {
            sync(now: now)
            hide(.shortcut)
        }
    }

    func tick(now: Double) {
        let (moved, clicked) = sync(now: now)
        guard let reason = hidden else {
            if Prefs.hideWhenIdle, now - lastActivity >= Prefs.idleDelay { hide(.idle) }
            return
        }
        guard moved || clicked else { return }
        switch reason {
        case .idle: show(now: now)
        case .shortcut where Prefs.showOnMove: show(now: now)
        case .shortcut: if clicked { cursor.reassert() }   // macOS shows it on click; keep it gone
        }
    }

    /// Another app came to the front: macOS may have shown the pointer again.
    func appSwitched() { if isHidden { cursor.reassert() } }

    /// Put the pointer back (quit, Settings, menu).
    func show(now: Double) {
        guard isHidden else { return }
        cursor.show()
        hidden = nil
        lastActivity = now   // idle countdown starts over from here
        onChange?()
    }

    private func hide(_ reason: Reason) {
        cursor.hide()
        hidden = reason
        onChange?()
    }

    /// Reads the pointer; records activity. Returns what happened since the last read.
    @discardableResult
    private func sync(now: Double) -> (moved: Bool, clicked: Bool) {
        let loc = probe.location
        let moved = hypot(loc.x - lastLocation.x, loc.y - lastLocation.y) > Self.jitter
        if moved { lastLocation = loc }
        let click = now - probe.secondsSinceClick
        let clicked = click > lastClick + 0.001
        if clicked { lastClick = click }
        if moved || clicked { lastActivity = now }
        return (moved, clicked)
    }
}
