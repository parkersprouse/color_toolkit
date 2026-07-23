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

    /// What the user typed.
    ///
    /// The text is the source of truth while editing, never rewritten from the parsed
    /// value. Canonicalizing mid-edit would move the cursor out from under someone
    /// halfway through typing `oklch(`.
    ///
    /// Computed over private storage rather than declared with a `didSet`, because
    /// `@Observable` rewrites stored properties into computed ones and cannot carry
    /// property observers through that transformation.
    var inputText: String {
        get { storedInput }
        set {
            guard newValue != storedInput else { return }
            storedInput = newValue
            reparse()
        }
    }

    private var storedInput: String = ""

    /// How every format in the panel is serialized.
    var formatOptions = CSSFormatOptions()

    private(set) var parsed: ParsedInput = .empty

    /// The most recent color that parsed successfully.
    ///
    /// Retained across invalid edits on purpose: without it the entire conversion
    /// panel blanks out between `#3b82f` and `#3b82f6`, which makes typing feel
    /// broken. Cleared only when the field is emptied.
    private(set) var color: ColorValue?

    private(set) var recents: [RecentColor] = []

    /// Enough to be useful, few enough to stay scannable in a menu-bar panel.
    private static let recentLimit = 12

    init(initialInput: String = "#3b82f6") {
        storedInput = initialInput
        reparse()
    }

    // MARK: - Editing

    private func reparse() {
        parsed = ParsedInput(inputText)
        switch parsed {
        case .parsed(let result): color = result.color
        case .empty: color = nil
        case .failed: break  // keep showing the last good color
        }
    }

    /// Replaces the input with a color chosen elsewhere — a recent, the eyedropper,
    /// or the picker.
    func use(_ recent: RecentColor) {
        inputText = recent.text
    }

    /// Adopts a color that has no authored text of its own, writing it in `format`.
    func adopt(_ newColor: ColorValue, as format: CSSOutputFormat = .hex) {
        inputText = newColor.cssStringOrHex(as: format, options: formatOptions)
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
}
