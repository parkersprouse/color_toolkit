//
//  GlobalHotKey.swift
//  Color Toolkit
//

import AppKit
import Carbon.HIToolbox

/// A key combination the system delivers even when another app is frontmost.
///
/// Carbon's vocabulary, not AppKit's: virtual key codes and `cmdKey`-style masks,
/// which are what ``GlobalHotKeyCenter`` has to hand to `RegisterEventHotKey`.
/// Named `GlobalShortcut` rather than the obvious `KeyboardShortcut` because SwiftUI
/// already owns that name and means something different by it.
nonisolated struct GlobalShortcut: Sendable, Hashable {
    /// A virtual key code — `kVK_ANSI_C`, not the character `"c"`. Key codes describe
    /// a physical key position, so this stays the same key on a Dvorak layout.
    let keyCode: UInt32
    /// A Carbon modifier mask (`cmdKey`, `optionKey`, …), unrelated in value to
    /// `NSEvent.ModifierFlags`.
    let modifiers: UInt32
    /// How the key prints. A key code cannot be turned back into a character without
    /// consulting the active keyboard layout, so the label is carried alongside it.
    let keyLabel: String

    /// The shortcut as a menu would show it, in the order Apple's HIG specifies.
    var displayString: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + keyLabel
    }

    /// Pick a color from anywhere on screen.
    ///
    /// Three modifiers on purpose. ⇧⌘C is Digital Color Meter's own copy shortcut and
    /// is claimed by plenty of editors; ⌥⌘C is Finder's "Copy as Pathname". A global
    /// hot key wins over the frontmost app's, so a collision here would silently break
    /// something the user already relies on — a worse outcome than an awkward chord.
    static let sampleColor = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(controlKey | optionKey | cmdKey),
        keyLabel: "C"
    )
}

/// Owns the app's system-wide hot keys.
///
/// Uses Carbon's `RegisterEventHotKey` rather than
/// `NSEvent.addGlobalMonitorForEvents`, which would work identically *and* demand the
/// user grant Input Monitoring in System Settings. Carbon needs no permission and no
/// prompt, even sandboxed. It has been deprecated for over a decade and remains the
/// only way to do this; the deprecation is why it is quarantined in one file.
@MainActor
final class GlobalHotKeyCenter {
    static let shared = GlobalHotKeyCenter()

    /// `'CLRT'`. Carbon tags every hot key with a four-character app signature, so the
    /// handler can tell ours apart from any other registered on the same target.
    nonisolated static let signature: OSType = 0x434C_5254

    private var actions: [UInt32: () -> Void] = [:]
    private var registrations: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    private init() {}

    /// Claims `shortcut` system-wide, reporting whether the system accepted it.
    ///
    /// Returns `false` rather than throwing because there is nothing to recover from:
    /// the app works fine without a hot key, and the caller's only real option is to
    /// stop advertising one. Note that macOS does **not** reliably report a collision
    /// with another application, so `true` means "registered", not "unique".
    @discardableResult
    func register(_ shortcut: GlobalShortcut, action: @escaping () -> Void) -> Bool {
        guard installHandlerIfNeeded() else { return false }

        let id = nextID
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }

        nextID += 1
        registrations[id] = ref
        actions[id] = action
        return true
    }

    /// Releases every hot key. Registrations outlive the objects that made them, so
    /// tests must call this or they leak a system-wide chord for the session.
    func unregisterAll() {
        for ref in registrations.values {
            UnregisterEventHotKey(ref)
        }
        registrations.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() -> Bool {
        guard handler == nil else { return true }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        return InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &spec,
            nil,
            &handler
        ) == noErr
    }
}

/// Carbon's half of the bridge, and the one place Swift 6 concurrency actually costs
/// something in this codebase.
///
/// `EventHandlerUPP` is a C function pointer, so this closure can capture nothing —
/// not `self`, not the store, nothing. Carbon offers a `userData` pointer for exactly
/// that, but round-tripping a Swift object through `UnsafeMutableRawPointer` means
/// hand-managing its lifetime against a registration that outlives normal ARC scope.
/// Reaching a `shared` singleton by name is the same indirection with none of the
/// unsafety.
private let hotKeyEventHandler: EventHandlerUPP = { _, event, _ in
    guard let event else { return OSStatus(eventNotHandledErr) }

    var id = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &id
    )
    guard status == noErr, id.signature == GlobalHotKeyCenter.signature else {
        return OSStatus(eventNotHandledErr)
    }

    // Carbon dispatches application-target events from the main run loop, which is the
    // main thread — the same guarantee AppKit leans on for every event it delivers.
    // Asserting it beats hopping: `Task { @MainActor in }` would defer the loupe to a
    // later runloop turn *and* silently absorb the day the guarantee stopped holding.
    MainActor.assumeIsolated {
        GlobalHotKeyCenter.shared.fire(id.id)
    }
    return noErr
}
