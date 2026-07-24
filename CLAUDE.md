# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A native macOS color toolkit for web development. Built: CSS Color 4 parsing and
conversion across 14 spaces, a menu bar panel, a screen eyedropper with a global
shortcut, WCAG 2.2 / APCA contrast checking, and a gamut-aware HSV/OKLCH picker.
Planned: transforms and harmonies, CSS export, saved projects. Swift 6, SwiftUI, no
third-party runtime dependencies.

**[PLAN.md](PLAN.md) is the source of truth** for milestone status, what is deferred
and why, and the reasoning behind every decision recorded below. This file is the
operational layer — what to run and what will break. When the two overlap, PLAN.md
has the argument; read it before making a design call.

## Commands

Build:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' build
```

Full test suite:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' test
```

**`xcodebuild` does not print Swift Testing failure text.** A failed run names the
test and tells you nothing about why. Capture a result bundle and read the failure
messages out of it — this is the single most useful command here:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -resultBundlePath /tmp/res.xcresult test
```

```bash
xcrun xcresulttool get test-results tests --path /tmp/res.xcresult --compact
```

One suite. The target is the Swift **type** name, not the `@Suite("…")` display
string, and one file often holds several suites — `CSSParsingTests.swift` defines
`CSSParseValidTests`, `CSSParseRejectionTests`, and `CSSParseLeniencyTests`:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -only-testing:"Color ToolkitTests/ColorStoreTests" test
```

One test: append the function name — `-only-testing:"Color ToolkitTests/ColorStoreTests/adoptWritesInput()"`.

**No linter or formatter is configured**, and neither `swiftlint` nor `swift-format`
is installed. Match the surrounding style by hand.

### Reference tooling

`Tools/` holds Node generators driving everything numeric. **colorjs.io is pinned
exact at 0.7.0** (`Tools/package.json`) and is the conversion oracle.

```bash
node Tools/generate-constants.mjs         # → ColorCore/Spaces/Matrices.swift, NamedColors.swift
node Tools/generate-fixtures.mjs          # → Fixtures/reference-vectors.json
node Tools/generate-parse-fixtures.mjs    # → Fixtures/parse-vectors.json
node Tools/generate-contrast-fixtures.mjs # → Fixtures/contrast-vectors.json
```

The CVD matrices are the one exception to the Node/colorjs.io rule. Their oracle is
`colour-science` (Python), so the generator is Python — but it needs **only the
standard library**: it reads a vendored, pinned copy of Machado's Table 1 in
`Tools/vendor/machado2010.py` (colour-science 0.4.7, BSD-3, provenance in
`Tools/vendor/README.md`), no `pip install` required.

```bash
python3 Tools/generate-cvd-matrices.py    # → ColorCore/Analysis/CVDMatrices.swift, Fixtures/cvd-vectors.json
```

Ask the oracle rather than reasoning about gamuts:

```bash
cd Tools && node -e "import('colorjs.io').then(({default:C}) => console.log(new C('oklch(0.9 0.3 140)').inGamut('rec2020')))"
```

## Architecture

Layered so the numeric core stays independently testable and UI-free:

- **`ColorCore/`** — pure value types, no AppKit, no SwiftUI. `ColorValue` +
  `ColorSpace`, 14 spaces routed through XYZ D65, CSS Color 4 §13 gamut mapping,
  a hand-written recursive-descent CSS parser, a serializer, `Analysis/`
  (WCAG 2.2 and APCA contrast), and `Convert/GamutBoundary.swift` (how much chroma
  a lightness and hue have left).
- **`Features/Shell/ColorStore.swift`** — `@MainActor @Observable`, one instance
  injected into both scenes (menu bar + window). Holds a *pair* of `ColorField`s
  (foreground + background) and which `Tool` the window is showing.
- **`Features/`, `DesignSystem/`** — SwiftUI, one folder per tool. `Services/` wraps
  AppKit (pasteboard, `NSColorSampler`, Carbon hot keys).

### Invariants that cause immediate breakage

- The app builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Every ColorCore
  declaration needs an explicit `nonisolated`, and so does plain data in the UI layer
  or non-`@MainActor` tests cannot read it.
- `ColorCore/Spaces/Matrices.swift` and `NamedColors.swift` are **generated**.
  Regenerate; never hand-edit.
- `ColorCore/Analysis/CVDMatrices.swift` is **generated** too, from Machado's Table 1
  (`python3 Tools/generate-cvd-matrices.py`). Same rule — regenerate, never hand-edit —
  and never re-transcribe the 33 matrices from memory; the pinned vendored source and
  its three cross-checks exist precisely so nobody has to.
- **CVD matrices are applied in linear RGB, not gamma-encoded sRGB.** `simulating(_:​
  severity:)` decodes to linear, applies the 3×3, then re-encodes. Applying them to the
  sRGB channels directly is the classic mistake and is visibly wrong (≈0.26 off on a
  saturated mid-tone). A test asserts the linear answer *and* a mismatch with the
  gamma-space one; do not "simplify" the pipeline by dropping the linearization.
- The project uses file-system-synchronized groups (`objectVersion = 77`). New
  `.swift` files compile automatically — do not edit `project.pbxproj` to add them.
- **Never assert a gamut-containment claim from reasoning.** Space "widths" do not
  nest (Rec.2020 does not contain Display P3). Query the oracle.
- One predicate — `ColorValue.isGamutMapped(as:options:epsilon:)` — decides both the
  serialized string and the UI's "mapped" badge. Adding a second rule lets the badge
  lie about the value beside it.
- `ColorStore` keeps **text** as its source of truth, so an adopted color is
  serialized and immediately re-parsed. Storage precision (`CSSFormatOptions.lossless`)
  and display precision (`store.formatOptions.precision`) are separate settings; a
  panel that rounds re-derives next frame, a stored string that rounds is destroyed.
- ColorCore owns *facts* (the format catalog, gamut predicates); the UI layer owns
  *editorial copy* (format titles, section names in `FormatPresentation.swift`). A
  core test reaching into the UI for a display string is a smell.
- Precision is relative to each component's scale, not a flat decimal count — see
  `CSSFormatOptions.decimals(forFullScale:)`.
- **Two sRGB linearizations exist and must never be merged.** `TransferFunctions`
  uses **0.04045** (sRGB, what every conversion is validated against);
  `wcagRelativeLuminance` uses **0.03928** (WCAG's text). They look like the same
  function with a typo; merging them silently makes contrast results non-conformant.
- colorjs.io is a true oracle for conversions and APCA, but **only a cross-check for
  WCAG** — it implements a different definition. Never tighten the WCAG fixture
  tolerance to make a test pass.
- Contrast maths gamut-maps before measuring, because `pow` of a negative component
  is NaN and an out-of-sRGB color has them.
- **`GamutBoundary.maxChroma` and `gamutMapped` answer different questions and are
  meant to disagree.** §13 clips when clipping costs under a JND, so it maps blue to
  `#0000ff` at chroma `0.3132` while the boundary sits at `0.2656`. The picker's curve
  must match the **badge** (`inGamut`), never the mapper. Both facts are pinned by
  tests — do not "reconcile" them.
- **Never pass `gamutNoiseTolerance` to a chroma search.** It is 7.5e-5 of a *channel*;
  at `L = 0` that buys 0.041 of *chroma*. The boundary is strict, the badge forgiving.
- **HSV is not a `ColorSpace` case and must not become one** — CSS has no `hsv()`, so
  a case would leak into the parser, serializer, catalog and every `allCases` loop.
  It is `ColorCore/Convert/HSV.swift`, a coordinate on the side.
- The picker's axes are the source of truth during interaction, not the store. It
  writes on every change and re-seeds only when the field's text differs from what it
  last wrote — a boolean "am I writing" flag does not work, because observation fires
  after the synchronous reparse. Each mode writes a format that can hold its output:
  `oklch()` at `.lossless`, or hex for HSV.
- New tool panels: add a `Tool` case, a folder under `Features/`, and a branch in
  `ContentView`. Keep spec facts in ColorCore and wording in the panel — see
  `RequirementPresentation`.

### Testing

Swift Testing (`@Suite`/`@Test`/`#expect`) for units; XCUITest only for what unit
tests structurally cannot reach — rendering. See the header of
[ConversionSmokeTests.swift](Color%20ToolkitUITests/ConversionSmokeTests.swift) for
the accessibility-tree conventions before writing UI tests.

- A green test is not a test that tests anything. Confirm a new regression test
  **fails against the unfixed code** before trusting it.
- **Never write a fallback chain of XCUITest queries.** One named query, and dump
  `app.debugDescription` on failure. A chain that silently matches on index is a test
  that cannot fail — one hid a picker announcing its SF Symbol name to VoiceOver.
- Never write to the real pasteboard from a test.
- **`.accessibilityIdentifier` on a `Text` publishes the string as the element's
  `value`, not its `label`.** `element.label` returns `""` and the assertion reports a
  mismatch against nothing.
- Wait on **hittability**, not existence, before clicking something a tool switch may
  have moved — switching panels resizes the window, and a click already in flight
  lands where the control used to be.
- A `GeometryReader` square inside a `ScrollView` claims the whole unbounded height
  proposal. Size it from *width*, which is bounded.
- Every running instance owns its own `MenuBarExtra` icon, so an orphaned process
  looks like a duplicate app. See *Running the app* in PLAN.md for the diagnosis.

### Commits

Each commit must build and test **standalone** — a green run at HEAD says nothing
about whether intermediate commits are bisectable. Verify in a throwaway worktree
before stacking the next one:

```bash
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt && xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -derivedDataPath /tmp/dd test
```
