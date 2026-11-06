import AppKit
import Combine
import SwiftUI

/// `@State` is a macro shipped only with Xcode; this keeps the app buildable with Command Line Tools.
final class Box<T>: ObservableObject {
    @Published var v: T
    init(_ v: T) { self.v = v }
    // Swift 6.3.3 (Xcode 26.6) crashes inlining into this deinit in -O builds. Nothing to optimize here.
    @_optimize(none) deinit {}
}

/// Toolbar-tab preferences window. Golden ratio: 560 × 346 (width ÷ φ).
enum SettingsWindow {
    static let width: CGFloat = 560
    static let short = (width / 1.618).rounded()

    static func make() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true
        func add<V: View>(_ title: String, _ symbol: String, height: CGFloat, _ view: V) {
            let host = NSHostingController(rootView: view.frame(width: width, height: height))
            host.sizingOptions = .preferredContentSize
            host.title = title
            let item = NSTabViewItem(viewController: host)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        add("General", "gearshape", height: short, GeneralTab())
        add("Shortcut", "keyboard", height: short, ShortcutTab())
        add("Privacy", "hand.raised", height: short, PrivacyTab())

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

// MARK: Building blocks — label left, value/control flush right

/// Compact slider without tick marks; value on the right.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 0.1
    var format = "%.1f s"
    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: Binding(get: { value }, set: { value = ($0 / step).rounded() * step }), in: range)
                    .labelsHidden()
                    .frame(width: 180)
                Text(String(format: format, value)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

/// Key caps for shortcut lists: `LabeledContent("Pin") { KeyCaps(keys: ["⌥P"]) }`.
struct KeyCaps: View {
    let keys: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                Text(k)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.12)))
            }
        }
    }
}

// MARK: Tabs

struct GeneralTab: View {
    @AppStorage(K.hideWhenIdle, store: Prefs.d) private var hideWhenIdle = true
    @AppStorage(K.idleDelay, store: Prefs.d) private var idleDelay = 3.0
    @AppStorage(K.launchAtLogin, store: Prefs.d) private var launchAtLogin = true
    @AppStorage(K.showMenuIcon, store: Prefs.d) private var showIcon = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hideWhenIdle) {
                    Text("Hide cursor when idle")
                    Text("Moving or clicking brings it back.")
                }
                SliderRow(title: "After", value: $idleDelay, range: Prefs.delayRange, step: 1, format: "%.0f s")
                    .disabled(!hideWhenIdle)
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, _ in LoginItem.apply() }
                Toggle(isOn: $showIcon) {
                    Text("Show menu bar icon")
                    Text("When hidden, open Poof from Spotlight to get here.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutTab: View {
    @AppStorage(K.shortcutEnabled, store: Prefs.d) private var enabled = false
    @AppStorage(K.showOnMove, store: Prefs.d) private var showOnMove = true

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HStack(spacing: 12) {
                        KeyCaps(keys: HotKey.display).opacity(enabled ? 1 : 0.5)
                        Toggle("Use ⌃⌥K", isOn: $enabled).toggleStyle(.switch).labelsHidden()
                    }
                } label: {
                    Text("Hide or show cursor")
                    Text("Suggested shortcut, off by default.")
                }
                Toggle(isOn: $showOnMove) {
                    Text("Show when moved")
                    Text("Off: only ⌃⌥K brings the cursor back.")
                }
                .disabled(!enabled)
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacyTab: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Network") { Text("Blocked by the App Sandbox") }
                LabeledContent("Permissions") { Text("None") }
                LabeledContent("Data") { Text("Settings only, on this Mac") }
            } footer: {
                Text("Poof only reads where the pointer is. It never sees what you type or what's on screen.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
    }
}
