# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A native macOS color toolkit for web development: parse and convert every CSS Color 4
format, with an eyedropper, a menu bar panel, and accessibility/transform tooling
planned. Swift 6, SwiftUI, no third-party runtime dependencies.

**[PLAN.md](PLAN.md) is the source of truth** for the roadmap, milestone status, and
the reasoning behind every decision recorded below. This file is the operational
layer — what to run and what will break. When the two overlap, PLAN.md has the
argument; read it before making a design call.

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
node Tools/generate-constants.mjs      # → ColorCore/Spaces/Matrices.swift, NamedColors.swift
node Tools/generate-fixtures.mjs       # → Color ToolkitTests/Fixtures/reference-vectors.json
node Tools/generate-parse-fixtures.mjs # → Color ToolkitTests/Fixtures/parse-vectors.json
```

Ask the oracle rather than reasoning about gamuts:

```bash
cd Tools && node -e "import('colorjs.io').then(({default:C}) => console.log(new C('oklch(0.9 0.3 140)').inGamut('rec2020')))"
```

## Architecture

Layered so the numeric core stays independently testable and UI-free:

- **`ColorCore/`** — pure value types, no AppKit, no SwiftUI. `ColorValue` +
  `ColorSpace`, 14 spaces routed through XYZ D65, CSS Color 4 §13 gamut mapping,
  a hand-written recursive-descent CSS parser, and a serializer.
- **`Features/Shell/ColorStore.swift`** — `@MainActor @Observable`, one instance
  injected into both scenes (menu bar + window).
- **`Features/`, `DesignSystem/`** — SwiftUI. `Services/` wraps AppKit (pasteboard,
  `NSColorSampler`, Carbon hot keys).

### Invariants that cause immediate breakage

- The app builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Every ColorCore
  declaration needs an explicit `nonisolated`, and so does plain data in the UI layer
  or non-`@MainActor` tests cannot read it.
- `ColorCore/Spaces/Matrices.swift` and `NamedColors.swift` are **generated**.
  Regenerate; never hand-edit.
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

### Testing

Swift Testing (`@Suite`/`@Test`/`#expect`) for units; XCUITest only for what unit
tests structurally cannot reach — rendering. See the header of
[ConversionSmokeTests.swift](Color%20ToolkitUITests/ConversionSmokeTests.swift) for
the accessibility-tree conventions before writing UI tests.

- A green test is not a test that tests anything. Confirm a new regression test
  **fails against the unfixed code** before trusting it.
- Never write to the real pasteboard from a test.
- Every running instance owns its own `MenuBarExtra` icon, so an orphaned process
  looks like a duplicate app. See *Running the app* in PLAN.md for the diagnosis.

### Commits

Each commit must build and test **standalone** — a green run at HEAD says nothing
about whether intermediate commits are bisectable. Verify in a throwaway worktree
before stacking the next one:

```bash
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt && xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -derivedDataPath /tmp/dd test
```
