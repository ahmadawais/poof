import Foundation

enum K {
    static let showMenuIcon = "showInStatusBar"
    static let hideWhenIdle = "hideWhenIdle"
    static let idleDelay = "idleDelay"
    static let showOnMove = "showOnMove"
    static let launchAtLogin = "launchAtLogin"
}

/// All settings go through `Prefs.d`, so tests can swap in an isolated suite.
enum Prefs {
    static var d = UserDefaults.standard
    static let delayRange: ClosedRange<Double> = 1...60

    static func register() {
        d.register(defaults: [
            K.showMenuIcon: true,
            K.hideWhenIdle: true,
            K.idleDelay: 3.0,
            K.showOnMove: true,
            K.launchAtLogin: true,
        ])
    }

    static var showMenuIcon: Bool {
        get { d.bool(forKey: K.showMenuIcon) }
        set { d.set(newValue, forKey: K.showMenuIcon) }
    }

    static var hideWhenIdle: Bool {
        get { d.bool(forKey: K.hideWhenIdle) }
        set { d.set(newValue, forKey: K.hideWhenIdle) }
    }

    /// Seconds without moving or clicking before the pointer hides. Clamped: a bad value can't hide it instantly.
    static var idleDelay: Double {
        get { min(delayRange.upperBound, max(delayRange.lowerBound, d.double(forKey: K.idleDelay))) }
        set { d.set(newValue, forKey: K.idleDelay) }
    }

    /// After ⌃⌥K: moving the pointer brings it back. Off: only ⌃⌥K does.
    static var showOnMove: Bool {
        get { d.bool(forKey: K.showOnMove) }
        set { d.set(newValue, forKey: K.showOnMove) }
    }
}
