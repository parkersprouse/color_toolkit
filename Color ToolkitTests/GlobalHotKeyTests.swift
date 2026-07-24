//
//  GlobalHotKeyTests.swift
//  Color ToolkitTests
//

import Carbon.HIToolbox
import Foundation
import Testing

@testable import Color_Toolkit

/// The Carbon layer is deprecated API reached through a C callback, which is exactly
/// the combination that stops compiling one OS release without anyone noticing. These
/// tests exist to make that a red test rather than a feature that quietly does
/// nothing.
///
/// - Note: The firing path — key press → C callback → `@MainActor` → action — cannot
///   be tested here. Synthesizing a system-wide key event needs Accessibility
///   permission that a test runner has no business holding, so that half is verified
///   by pressing the key.
@MainActor
@Suite("Global hot key")
struct GlobalHotKeyTests {

    /// Deliberately not ``GlobalShortcut/sampleColor``: the unit tests are hosted in
    /// the app, which claims that chord as soon as a scene appears, and racing it
    /// would make this flaky. Four modifiers and Q is a combination nothing owns.
    private var probe: GlobalShortcut {
        GlobalShortcut(
            keyCode: UInt32(kVK_ANSI_Q),
            modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey),
            keyLabel: "Q"
        )
    }

    /// Proves both halves of the lifecycle: the system still accepts a Carbon hot key,
    /// and releasing one really does hand the chord back. The second registration
    /// would fail with `eventHotKeyExistsErr` if `unregisterAll` were a no-op.
    ///
    /// - Note: This clears the host app's own registration as collateral, since
    ///   `unregisterAll` is all or nothing. Harmless — the host exists only for the
    ///   duration of the run — but it is why no test here asserts on the app's state.
    @Test("A hot key can be claimed, released, and claimed again")
    func registrationLifecycle() {
        let center = GlobalHotKeyCenter.shared
        center.unregisterAll()
        defer { center.unregisterAll() }

        #expect(center.register(probe) {}, "the system refused a Carbon hot key")
        center.unregisterAll()
        #expect(center.register(probe) {}, "unregistering did not release the chord")
    }

    /// Modifier order is not cosmetic — ⌘⌥⌃C would read as a different shortcut to
    /// anyone who knows the convention.
    @Test("The shortcut prints modifiers in the order menus use")
    func displayStringFollowsConvention() {
        #expect(GlobalShortcut.sampleColor.displayString == "⌃⌥⌘C")

        let everything = GlobalShortcut(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey),
            keyLabel: "Space"
        )
        #expect(everything.displayString == "⌃⌥⇧⌘Space")
    }

    @Test("A shortcut with no modifiers prints as just its key")
    func bareKeyPrintsAlone() {
        let bare = GlobalShortcut(keyCode: UInt32(kVK_F13), modifiers: 0, keyLabel: "F13")
        #expect(bare.displayString == "F13")
    }
}
