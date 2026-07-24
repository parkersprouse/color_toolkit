//
//  ColorStore.swift
//  Color Toolkit
//

import Foundation
import Observation

/// The result of parsing whatever is currently in the input field.
///
/// Three states rather than an optional, because "nothing typed yet" and "typed
/// something wrong" want opposite treatment in the UI: one is a hint, the other is an
/// error.
enum ParsedInput: Equatable {
    case empty
    case failed(ParseError)
    case parsed(ParseResult)

    init(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        do {
            self = .parsed(try CSSColorParser.parse(trimmed))
        } catch {
            self = .failed(error)
        }
    }

    var color: ColorValue? {
        if case .parsed(let result) = self { result.color } else { nil }
    }

    var error: ParseError? {
        if case .failed(let error) = self { error } else { nil }
    }

    var warnings: [ParseWarning] {
        if case .parsed(let result) = self { result.warnings } else { [] }
    }
}

/// One editable color: the text, and whatever it currently parses to.
///
/// Extracted when contrast arrived, because the app went from editing one color to
/// editing a pair and will keep going — harmony bases, palette entries. A value type
/// rather than a class so that mutating it counts as mutating the store's own stored
/// property, which is what `@Observable` watches; a nested reference type would need
/// its own observation and would silently fail to notify anything.
struct ColorField {
    /// The source of truth while editing, never rewritten from the parsed value.
    /// Canonicalizing mid-edit would move the cursor out from under someone halfway
    /// through typing `oklch(`.
    var text: String {
        didSet {
            guard text != oldValue else { return }
            reparse()
        }
    }

    private(set) var parsed: ParsedInput = .empty

    /// The most recent text that parsed. Retained across invalid edits on purpose:
    /// without it everything downstream blanks out between `#3b82f` and `#3b82f6`,
    /// which reads as the app breaking rather than as feedback.
    private(set) var color: ColorValue?

    init(text: String) {
        // Assignment during initialization does not fire `didSet`, so the first parse
        // is explicit.
        self.text = text
        reparse()
    }

    private mutating func reparse() {
        parsed = ParsedInput(text)
        switch parsed {
        case .parsed(let result): color = result.color
        case .empty: color = nil
        case .failed: break  // keep showing the last good color
        }
    }
}

/// Which panel the main window is showing.
///
/// The input field sits above this and belongs to no tool in particular — it is the
/// app's spine, and every tool is a different question asked about the same color.
enum Tool: String, CaseIterable, Identifiable, Sendable {
    case convert
    case contrast

    var id: String { rawValue }

    /// Also the accessibility label, because the switcher shows text rather than
    /// icons — see the note in `ContentView`.
    var title: String {
        switch self {
        case .convert: "Convert"
        case .contrast: "Contrast"
        }
    }
}

/// A color the user has already worked with, plus the text that produced it.
///
/// The text is stored alongside the value so that clicking a recent returns you to
/// *your* spelling. Re-deriving it from the `ColorValue` would hand back a
/// canonicalized form, quietly rewriting `rebeccapurple` as `#663399`.
struct RecentColor: Identifiable, Hashable, Sendable {
    let color: ColorValue
    let text: String

    var id: String { text }
}

/// Shared state for the whole app: what is being edited, and what came before.
///
/// One instance, injected into both the window and the menu bar. Two instances would
/// compile perfectly and then silently diverge — recents added from the menu bar
/// would never appear in the window.
@MainActor
@Observable
final class ColorStore {

    /// The color everything is about: the one being converted, sampled, and copied.
    private var foreground: ColorField

    /// The color contrast is measured against. Separate from `foreground` because
    /// contrast is the first question this app asks that needs two colors at once.
    private var background: ColorField

    /// How every format in the panel is serialized.
    var formatOptions = CSSFormatOptions()

    /// Which panel the main window is showing.
    var tool: Tool = .convert

    private(set) var recents: [RecentColor] = []

    /// Enough to be useful, few enough to stay scannable in a menu-bar panel.
    private static let recentLimit = 12

    init(initialInput: String = "#3b82f6", initialBackground: String = "#ffffff") {
        foreground = ColorField(text: initialInput)
        background = ColorField(text: initialBackground)
    }

    // MARK: - Editing

    /// What the user typed. Forwarded to ``ColorField`` so the two fields cannot drift
    /// apart in behavior — the background gets live parsing, retained-last-good, and
    /// no mid-edit canonicalization for free rather than by a second implementation.
    var inputText: String {
        get { foreground.text }
        set { foreground.text = newValue }
    }

    var parsed: ParsedInput { foreground.parsed }
    var color: ColorValue? { foreground.color }

    var backgroundText: String {
        get { background.text }
        set { background.text = newValue }
    }

    var backgroundParsed: ParsedInput { background.parsed }
    var backgroundColor: ColorValue? { background.color }

    /// Exchanges foreground and background, text and all.
    ///
    /// Worth a button because APCA is asymmetric: dark-on-light and light-on-dark are
    /// different results, and swapping is how you see both without retyping either.
    func swapForegroundAndBackground() {
        let outgoing = foreground.text
        foreground.text = background.text
        background.text = outgoing
    }

    /// Replaces the input with a color chosen elsewhere — a recent, the eyedropper,
    /// or the picker.
    func use(_ recent: RecentColor) {
        inputText = recent.text
    }

    /// Adopts a color that has no authored text of its own — an eyedropper sample, a
    /// picker result — writing it in `format` where `format` can carry it.
    ///
    /// The subtlety is that this store keeps *text* as its source of truth, so the
    /// string written here is immediately parsed back into a new `ColorValue`. Any
    /// rounding or gamut mapping in the spelling is therefore permanent: naively
    /// writing a Display P3 sample as hex would map it into sRGB on the way in, and
    /// the color the rest of the app sees would be one the screen never showed. Hence
    /// ``ColorValue/spelling(preferring:)`` to choose the format and
    /// ``CSSFormatOptions/lossless`` to choose the digits — neither of which is the
    /// user's display precision, which governs only what panels show.
    func adopt(_ newColor: ColorValue, preferring format: CSSOutputFormat = .hex) {
        inputText = newColor.cssStringOrHex(
            as: newColor.spelling(preferring: format),
            options: .lossless
        )
    }

    // MARK: - Recents

    /// Files the current color under recents.
    ///
    /// Called at deliberate moments — submitting the field, copying a value, sampling
    /// the screen — rather than on every keystroke. Live-parsing means every prefix of
    /// what you type parses too, so an eager version would fill the list with the
    /// accidental colors between `#f` and `#f0a`.
    func remember() {
        guard let color else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Exact-value dedupe, so `red` and `#f00` collapse but `rgb(255 0 0)` and
        // `hsl(0 100% 50%)` stay separate — they are the same pixel but different
        // authored colors, and which space a color lives in is the thing this app
        // refuses to throw away.
        recents.removeAll { $0.color == color }
        recents.insert(RecentColor(color: color, text: text), at: 0)
        if recents.count > Self.recentLimit {
            recents.removeLast(recents.count - Self.recentLimit)
        }
    }

    func clearRecents() {
        recents.removeAll()
    }

    // MARK: - Output

    /// Every format for the current color, or nothing if the field has no valid color.
    var formats: [FormattedColor] {
        color?.allFormats(options: formatOptions) ?? []
    }

    /// Copies one serialization and files the color under recents, since reaching for
    /// a value is the clearest signal that you intend to use it.
    func copy(_ formatted: FormattedColor) {
        Clipboard.copy(formatted.css)
        remember()
    }

    // MARK: - Screen sampling

    /// True for a moment after a sample lands, so the menu bar can acknowledge a
    /// capture the user made while looking at some other app entirely.
    private(set) var justCaptured = false

    private var captureResetTask: Task<Void, Never>?

    /// Shows the loupe and adopts whatever pixel the user clicks.
    ///
    /// - Parameter alsoCopy: Put the result on the clipboard too. True for the global
    ///   hot key, whose entire point is capturing a color while another app is
    ///   frontmost — filling a text field nobody can see would accomplish nothing.
    ///   False for the in-app button, where the field is right there and clobbering
    ///   the clipboard would be presumptuous.
    /// - Returns: Whether a color was captured; `false` if the user cancelled.
    @discardableResult
    func sampleFromScreen(alsoCopy: Bool = false) async -> Bool {
        guard let sampled = await ScreenSampler.sample() else { return false }

        adopt(sampled)
        remember()

        if alsoCopy, let color {
            // The user's precision, not `.lossless`: this string is going somewhere
            // else to be read by a person, so it should look like the values the rest
            // of the app shows. Only the stored text has to survive a round trip.
            Clipboard.copy(
                color.cssStringOrHex(
                    as: color.spelling(preferring: .hex),
                    options: formatOptions
                )
            )
        }

        acknowledgeCapture()
        return true
    }

    private func acknowledgeCapture() {
        justCaptured = true
        captureResetTask?.cancel()
        captureResetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            justCaptured = false
        }
    }

    // MARK: - Global shortcut

    /// Whether the system accepted the sampling hot key. Shown in the menu bar panel,
    /// because a shortcut advertised but not registered is worse than none offered.
    private(set) var globalShortcutIsActive = false

    /// Claims the system-wide sampling shortcut, once.
    ///
    /// Idempotent because it is called from both scenes: neither is guaranteed to
    /// exist — the window can be closed, and the menu bar item can be hidden — so
    /// whichever appears first registers and the other no-ops. Deliberately *not*
    /// called from `init`, so tests can build a store without claiming a chord
    /// system-wide.
    func activateGlobalShortcut() {
        guard !globalShortcutIsActive else { return }
        globalShortcutIsActive = GlobalHotKeyCenter.shared.register(.sampleColor) { [weak self] in
            guard let self else { return }
            Task { await self.sampleFromScreen(alsoCopy: true) }
        }
    }
}
