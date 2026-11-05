import AppKit
import CoreGraphics

/// Hides and shows the pointer. A protocol so the controller is testable without touching the real cursor.
protocol CursorDriver: AnyObject {
    func hide()
    func show()
    /// Hide again after macOS brought the pointer back on its own (a click, an app switch).
    func reassert()
}

/// Where the pointer is and when it last clicked. A protocol so tests can feed in movement.
protocol PointerProbe {
    var location: CGPoint { get }
    /// Seconds since the last mouse button press anywhere.
    var secondsSinceClick: Double { get }
}

// Private WindowServer calls. A background app's CGDisplayHideCursor is ignored unless its connection
// sets "SetsCursorInBackground". Every cursor hider relies on the same property.
private typealias CGSConnectionID = Int32
@_silgen_name("_CGSDefaultConnection") private func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ cid: CGSConnectionID, _ target: CGSConnectionID,
                                      _ key: CFString, _ value: CFTypeRef) -> Int32

/// The real pointer. CGDisplayHideCursor is reference counted per app, so this keeps it at exactly 0 or 1.
final class SystemCursor: CursorDriver {
    private(set) var isHidden = false

    init() {
        let cid = _CGSDefaultConnection()
        let err = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        if err != 0 { log.error("SetsCursorInBackground failed: \(err, privacy: .public)") }
    }

    func hide() {
        guard !isHidden else { return }
        CGDisplayHideCursor(CGMainDisplayID())   // the display argument is ignored: hides on every screen
        isHidden = true
    }

    func show() {
        guard isHidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        isHidden = false
    }

    func reassert() {
        guard isHidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        CGDisplayHideCursor(CGMainDisplayID())
    }
}

/// Reads the pointer without any permission: no event tap, no Accessibility, no Input Monitoring.
struct SystemProbe: PointerProbe {
    var location: CGPoint { NSEvent.mouseLocation }
    var secondsSinceClick: Double {
        [CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown]
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
    }
}
