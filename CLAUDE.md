# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A native macOS color toolkit for web development. Built: CSS Color 4 parsing and
conversion across 14 spaces, a menu bar panel, a screen eyedropper with a global
shortcut, WCAG 2.2 / APCA contrast checking, a gamut-aware HSV/OKLCH picker, OKLCH
transforms — adjustment, harmonies, shade ramps and a contrast solver — export to CSS
declarations, custom properties, JSON and both Tailwind generations, and saved projects
on SwiftData with reordering and hand-picked palettes, and CSS Color 4 §13.2's
missing-component carry-forward. M0–M12 are built. **M13–M18 are planned and not
started** — the CSS syntaxes the parser still rejects (`calc()`, `rgb(from …)`,
`color-mix()`), a `@media (color-gamut)` export shape, design-token import, and a CLI
over `ColorCore`. M12 was the spine and is done, so each of those is now only the work
it says it is. Swift 6, SwiftUI, no third-party runtime dependencies.

**[PLAN.md](PLAN.md) is the source of truth** for milestone status, what is deferred
and why, and the reasoning behind every decision recorded below. This file is the
operational layer — what to run and what will break. When the two overlap, PLAN.md
has the argument; read it before making a design call.

## Commands

Build:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' build
```

Full test suite (~7 minutes, nearly all of it UI tests — the 308 Swift Testing functions
finish in under a second, the 25 XCUITests take about six minutes):

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' test
```

**Run exactly one suite at a time, and read the right line for the verdict.** Both of
these produced confidently wrong conclusions during M8:

- **Two concurrent `xcodebuild test` runs fight** over the same DerivedData and test
  host, which surfaces as *"The test runner hung before establishing connection"* or
  *"Lost connection to the application"* — and leaves orphans that break the next run
  too. If a long run gets backgrounded by a tool timeout it is still running; check
  `ps -Ao pid,ppid,command | grep -E "xcodebuild|UITests-Runner"` before starting
  another, and kill anything with `ppid 1`. See *Running the app* in PLAN.md.
- **Read the verdict off the right line.** The only authoritative markers are
  `** TEST SUCCEEDED **` and `** TEST FAILED **`, and there should be exactly one.
  `Test run with N tests in M suites passed` is the Swift Testing line and prints
  minutes before the UI phase ends, so reading it as the result announces a pass for a
  run that has not finished. `Executed N tests` counts XCTest only and reads `0` on a
  Swift-Testing-only run.

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
It is the Swift **function** name, not the `@Test("…")` display string.

The scheme is versioned at `Color Toolkit.xcodeproj/xcshareddata/xcschemes/`, so every
command above works from a fresh clone. It used to live only in gitignored
`xcuserdata/`, where deleting it made all of them fail with *"does not contain a scheme
named Color Toolkit"* — do not move it back.

### Formatting

**SwiftFormat is the formatter** — the `swiftformat` CLI plus the Xcode extension,
configured by `.swiftformat` (and `.swift-version`, which is `6.3.3`). Indentation is
**2 spaces**; the config also enables `organizeDeclarations`, so it will move
declarations and insert `// MARK:` headers.

Formatting is **its own commit, always after the work it reformats**:

1. Finish the work and commit it, unformatted.
2. Then run `swiftformat .` from the repo root.
3. Check the result, then commit the formatted files as a **separate** follow-up commit.

Never fold the two together. The reformat touches thousands of lines across dozens of
files, and a mixed commit buries the real change inside it; separate commits mean
`git diff` against step 1 is exactly the formatter's work and `git revert` undoes it
cleanly.

Four settings in `.swiftformat` are load-bearing, and each is there because the
default did damage. Do not "tidy" them back:

- **`--exclude` covers the three generated files** (`Spaces/Matrices.swift`,
  `Spaces/NamedColors.swift`, `Analysis/CVDMatrices.swift`). Their generators emit
  4-space, no-trailing-comma output, so without the exclusion regenerating reverts the
  formatting and the next `swiftformat .` re-applies it — churn with no end state.
- **`--test-case-name-format preserve`**, not the `raw-identifiers` default. That
  default rewrites `@Test("A name") func someTest()` into ``func `A name`()``, and when
  two tests **in the same file** share a display string it converts only the first —
  the second silently loses its description and gets its camelCase split instead
  (`outOfGamutDoesNotProduceNaN` → `` `out of gamut does not produce na N` ``).
  `ContrastTests.swift` has exactly that shape, one test per suite.
- **`--acronyms` is empty**, not the `ID,URL,UUID` default. It is a *rename* rule, and
  renames are the one thing here the compiler cannot check: `Codable` derives its keys
  from property names, and this project decodes four JSON fixture files. A future
  `sourceUrl` → `sourceURL` would break decoding at runtime with a green build.
- **`preferContains` and `preferMinOverSorted` are not enabled**, and
  `--anonymous-for-each` is `ignore`. All three rewrite *runtime behaviour*, not
  layout — `sorted(by:).first` → `min(by:)` differs on tie-breaking, and `return`
  inside `forEach` continues the loop where `return` inside `for in` leaves the
  function.

The rest of the config is compile-checked — reordering, indentation, MARK insertion,
`pattern-let`, `conditional-assignment`, `singlePropertyPerLine` — so a green build is
sufficient proof for it. The discriminating question when adding a rule is not "how
aggressive is it" but **can the compiler catch it if it is wrong**.

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

**Regenerating `cvd-vectors.json` on a different machine produces spurious churn — leave
it.** 26 of its 405 vectors come back differing in the last ULP. The generator is
idempotent on any given host, so this is not nondeterminism: `**` on Python floats calls
libm `pow`, which IEEE-754 does not require to be correctly rounded, so the result varies
by platform and libm version. The differences are ~1e-16, far inside every tolerance the
CVD tests use. Committing a regenerated fixture just moves the churn to the next person.
`CVDMatrices.swift` itself regenerates byte-identically, which is the check that matters.

Ask the oracle rather than reasoning about gamuts:

```bash
cd Tools && node -e "import('colorjs.io').then(({default:C}) => console.log(new C('oklch(0.9 0.3 140)').inGamut('rec2020')))"
```

## Architecture

Layered so the numeric core stays independently testable and UI-free:

- **`ColorCore/`** — at the **repo root**, not inside `Color Toolkit/`. It is its own
  `PBXFileSystemSynchronizedRootGroup` so a second target (a CLI) can list it without an
  exclusion list to maintain; the sources still compile *into* the app module, which is why
  everything in it stays `internal` and tests still reach it with
  `@testable import Color_Toolkit`. Pure value types, no AppKit, no SwiftUI. `ColorValue` +
  `ColorSpace`, 14 spaces routed through XYZ D65, CSS Color 4 §13 gamut mapping,
  a hand-written recursive-descent CSS parser, a serializer, `Analysis/`
  (WCAG 2.2 and APCA contrast), `Convert/GamutBoundary.swift` (how much chroma
  a lightness and hue have left), `Transform/` (relative adjustment, the S-curve,
  harmonies, shade ramps, the contrast solver — all in OKLCH), and `Export/`
  (declaration templates and five document shapes).
- **`Features/Shell/ColorStore.swift`** — `@MainActor @Observable`, one instance
  injected into both scenes (menu bar + window). Holds a *pair* of `ColorField`s
  (foreground + background) and which `Tool` the window is showing.
- **`Persistence/`** — the only SwiftData in the app, five files. `ColorRecord` is a plain
  value type bridging `ColorValue` to flat, queryable columns; `ProjectModels` holds the
  three `@Model` classes; `ProjectLibrary` owns every mutation so the rules are testable
  against a container; `SchemaVersions` declares `ColorToolkitSchemaV1` and an empty
  migration plan; `PersistenceStack` builds the one container both scenes share.
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
  There are **two** root groups feeding the app target, `ColorCore/` and
  `Color Toolkit/`; a file dropped in either compiles. Editing the project file is for
  adding a *target*, or a build setting with nowhere else to live — never for adding
  files.
- **`Info.plist` sits at the repo root, and that is the only place it can.** The app is
  otherwise `GENERATE_INFOPLIST_FILE = YES`, so every scalar stays an `INFOPLIST_KEY_*`
  build setting; the file exists solely for `UTExportedTypeDeclarations`, which is an
  array of dictionaries and has no `INFOPLIST_KEY_` spelling. Setting `INFOPLIST_FILE`
  alongside the generator **merges** rather than replaces — measured, 24 generated keys
  in and 24 plus the declaration out — but set it in *both* the Debug and Release blocks,
  because the type declaration is only read at runtime and a Release-only omission is
  invisible from a Debug build. It cannot live in `Color Toolkit/`: that folder is a
  synchronized root group, so it claims the file and the plist becomes the target's
  `Info.plist` *and* a bundled resource, which builds, warns, and ships a duplicate in
  `Contents/Resources`.
- **A SwiftData `VersionedSchema`'s statics need `nonisolated`**, like everything else
  under this project's default actor isolation. `PersistenceStack.schema` is built from
  `ColorToolkitSchemaV1`; the migration plan is deliberately empty, and a test asserting
  that it "works" would be asserting nothing — see PLAN.md.
- **Reordering renumbers `sortIndex` densely; appending does not.** `nextIndex(after:)`
  leaves gaps so a new color lands last after a deletion, and that is only safe while
  positions are append-only — slotting a *moved* color into a gap means inventing a value
  between neighbours, and two moves into one gap collide. `moveColors` is the only place
  that renumbers. Do not "unify" the two.
- **Two `savePalette` overloads, and merging them destroys data.** The `[PaletteEntry]`
  one re-derives a spelling because ramp stops and harmony members never had one; the
  `from: [SavedColor]` one copies `ColorRecord` so a user's typed `rebeccapurple` survives.
  Palette keys from a hand-picked set are **deduplicated** — two entries sharing a key
  collapse into one CSS property and a color vanishes from the export silently.
- **Never assert a gamut-containment claim from reasoning.** Space "widths" do not
  nest (Rec.2020 does not contain Display P3). Query the oracle.
- One predicate — `ColorValue.isGamutMapped(as:options:epsilon:)` — decides both the
  serialized string and the UI's "mapped" badge. Adding a second rule lets the badge
  lie about the value beside it.
- **`ColorSpace.componentRoles` is transcribed from CSS Color 4 §13.2, never derived
  from `componentLabels`.** Same rule as the matrices, for the same reason: three of
  its groupings are not guessable. XYZ shares sRGB's three roles ("super-saturated RGB
  space"), Saturation shares Chroma's, and `b` names Blue in an RGB space and Opponent
  b in Lab — a letter-based derivation conflates the last pair and silently carries a
  missing `b` from `lab()` into sRGB's blue channel. `hueIndex` is *derived* from this
  table, so a mistyped role moves the picker's hue axis too.
- **Carry-forward is an interpolation rule; `converted(to:)` stays numeric.** Missing
  components cross a conversion only through `convertedForInterpolation(to:)` /
  `carriedForwardMissing(to:)` in `Convert/MissingComponents.swift`. Two mechanisms,
  and the second is the one that gets lost: components pair off individually by role,
  *and* whatever is left on each side forms a set that carries only when **every**
  member of it is missing. Turning that `allSatisfy` into a `contains` fails three
  tests; deleting the set rule fails three others and leaves `rgb(none none none)` →
  `oklab(0 0 0)`.
- **Carry-forward runs before `markingPowerlessComponents()`, never after.** The spec
  is explicit, and the two flags mean different things downstream: a carried-forward
  component takes the *other* color's value when interpolated, where a powerless one is
  zero. Marking first destroys the value the spec wants preserved. Powerless marking
  also *blanks* what it flags; carry-forward must not.
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
  It is `ColorCore/Convert/HSV.swift`, a coordinate on the side. `OKLCHComponents` in
  `Transform/Adjustment.swift` is the same idea for the same reason.
- **Harmonies are never gamut-mapped; ramp stops always are.** These look like one
  decision and are opposite ones. A hue rotation that leaves sRGB is the honest answer
  and the badge exists to say so — mapping it returns a "complement" that is not the
  complement. A `ShadeRamp` is a set built to be used together, so every stop is held
  inside `GamutBoundary`'s edge. Both are pinned by tests, including one asserting that
  a constant-chroma ramp really does escape the gamut; if that stops failing, the ramp
  has lost its reason to exist.
- **`ShadeRamp` clamps a stop only when `inGamut` says no.** Not a shortcut: clamping
  unconditionally moves the base off itself by up to a search step (so it no longer
  comes out of its own ramp), and for an unbounded gamut `maxChroma` returns `.infinity`
  and every chroma becomes infinite.
- **Transforms return OKLCH, never the input's space.** A round trip through hex
  quantizes onto the 8-bit grid, so a sub-1/255 nudge returns the original; and results
  that leave sRGB have no honest spelling in a bounded format. `TransformPanel` therefore
  adopts with `preferring: .oklch`.
- **Never bisect the contrast ratio — it is a V, not a monotone curve.** Against a
  mid-tone background contrast falls to 1:1 as the color crosses the background's
  luminance and rises again, so a target has two crossings and bisection lands on
  whichever the bracket straddled. `ContrastSolver` inverts the ratio into a target
  *luminance* (which is monotone in lightness) and bisects that, keeping the passing end
  so the result provably satisfies `meets`. Do not "simplify" this.
- **The contrast ceiling's floor is `√21 ≈ 4.5826`**, so AA body text is reachable
  against every background and only AAA can be impossible. The worst-case background
  falls between 8-bit grays 117 and 118, so a hex sweep cannot find it — the test
  constructs it.
- The picker's axes are the source of truth during interaction, not the store. It
  writes on every change and re-seeds only when the field's text differs from what it
  last wrote — a boolean "am I writing" flag does not work, because observation fires
  after the synchronous reparse. Each mode writes a format that can hold its output:
  `oklch()` at `.lossless`, or hex for HSV.
- **An export `template` and an export `shape` are not the same control** and must not
  be merged back. A template is per color (`border: 1px solid X`); a shape is per
  document (`:root {}`, JSON, a Tailwind config). Exactly one shape consumes a template,
  which is why `usesTemplate` and `usesName` are complements — a bare declaration has
  nowhere to put a family name. Merging them produces `background-color:` eleven times
  and calls it a stylesheet.
- **Palette keys are syntax, not labels.** They become CSS identifiers *and* JavaScript
  object keys, and Tailwind writes shade keys bare — legal for `50:`, fatal for
  `triad-2:`, which parses as a subtraction and stops the config loading. They must also
  be unique: two entries sharing a key silently collapse into one property and a color
  vanishes. `ExportOptions.javaScriptKey` and `cssIdentifier` are the only places that
  decide this; do not format a key inline.
- **`.keyword` is excluded from `CSSOutputFormat.exportable` on purpose.** It names 148
  colors, so an eleven-shade palette would come back part keyword and part something
  else with nothing in the document to say so. Every other catalog format is *total*,
  which is what makes `cssStringOrHex`'s fallback unreachable in the export path rather
  than merely unused — a test pins it. Do not "simplify" by adding keyword back with a
  fallback.
- **Never encode `ColorValue` with `JSONEncoder` for export.** It is `Codable`, so the
  one-liner compiles and emits `space`/`components`/`missing` — the program's internals,
  not the color. Export carries CSS strings, the same ones you would have pasted. M9's
  storage model rejects an opaque blob for the same reason.
- **The tool switcher lives in the window body, not the toolbar.** It was a
  `ToolbarItem(placement: .principal)` until a sixth tool made macOS sweep the entire
  switcher into a *"more toolbar items"* overflow menu — every tool gone, at a window
  745pt wide. Principal placement is *centered*, so its budget is
  `width − 2 × max(leading, trailing)`, and the window title alone spends that twice
  over. Do not move it back — M9 added a seventh segment, and all seven fit in the body.
  **Seven is the tested ceiling at `minWidth: 520`; an eighth is unmeasured risk.** This
  is why M15's mixing folds into `Transform` and M17's import folds into `Projects`
  rather than each taking a `Tool` case. Adding an eighth means budgeting for shorter
  titles, a raised `minWidth`, or a different control — not just one more enum case.
- **A ramp stop on the gamut boundary can round outward at display precision.** The
  printed `oklch(0.97 0.0142 259.81)` is 2.3e-5 of chroma past a boundary at `0.014177`,
  so the *string* is out of sRGB while the `ColorValue` is inside. Worst case across hues
  at four decimals is 1.7e-3 of a channel — 0.43 of an 8-bit step. Known and accepted:
  biasing export rounding inward would make the clipboard disagree with the preview.
- **A SwiftData to-many relationship is unordered — measured, not assumed.** Read an
  eleven-stop ramp off `palette.entries` without sorting and it comes back
  `600, 400, 100, …`, in the same context, right after the save. `SavedColor.sortIndex`
  plus `orderedEntries` / `orderedColors` is the fix; never iterate the raw array where
  order carries meaning, or Tailwind's keys name the wrong colors and the output still
  looks well-formed.
- **Both `@Relationship`s into `SavedColor` declare their `inverse:` explicitly.** It is
  the destination of two to-many relationships, and SwiftData resolves inverses when the
  *container* is built — leave them inferred and everything compiles and the app throws
  on launch. `ProjectStoreTests` opens by asserting the container builds, which is what
  turns that into a test failure.
- **`ColorStore` must not import SwiftData.** `ProjectsPanel` owns the app's only
  `@Query` and `modelContext`; palettes cross the boundary as `[PaletteEntry]`, and the
  selected project is remembered as a plain `UUID` (hence `Project.uuid` alongside
  `PersistentIdentifier`). This is what keeps `ExportStoreTests` free of a
  `ModelContainer` — and what made `ExportSource.saved` one enum case instead of a second
  path through the export layer.
- **Stored colors keep their authored text as well as their components**, for the reason
  `RecentColor` does: re-deriving a spelling canonicalizes, and a saved `rebeccapurple`
  would come back `#663399`. The `missing` mask is stored too — the parser sets it for
  CSS `none`. A test requires that parsing the text reproduces the components, because
  two spellings of one claim will otherwise drift.
- **UI tests that touch projects must launch with `UITestInMemoryStore`** — see
  `ProjectsSmokeTests`. Without it XCUITest writes into the real library and the next run
  finds it. **Both spellings of a launch argument are claimed by something, so it takes
  three strings, not one:** `["-NSTreatUnknownArgumentsAsOpen", "NO", "UITestInMemoryStore"]`.
  A leading hyphen goes to `NSUserDefaults`, which reads the next argument as its value;
  a bare one goes to AppKit, whose `NSTreatUnknownArgumentsAsOpen` defaults to on and
  treats it as a **file to open** — and an app launched to open a document never creates
  its default window. The app still launches and still reaches `.runningForeground`; it
  just has a menu bar and nothing else, so every query fails against a tree with no
  window and it reads as a broken panel rather than a broken launch. This is not
  hypothetical and not specific to projects: adding *any* meaningless argument to
  `ConversionSmokeTests` reproduced it exactly, and the opt-out pair fixed it. macOS
  drifted here — the six projects tests fail this way at pre-M11 commits too, so the
  green runs recorded in the M9 and M11 commit messages no longer reproduce.
- **An in-memory container cannot test persistence.** It proves round tripping inside one
  context and says nothing about surviving a quit, which is what "saved" means — so
  `dataSurvivesAReopen` writes a real store, drops the container and reopens it. Use a
  temp *directory*: SQLite leaves `-wal` and `-shm` beside the file, and removing only
  the `.store` leaves state that can make the next run pass for the wrong reason.
- New tool panels: add a `Tool` case, a folder under `Features/`, and a branch in
  `ContentView`. Keep spec facts in ColorCore and wording in the panel — see
  `RequirementPresentation`.

### Testing

Swift Testing (`@Suite`/`@Test`/`#expect`) for units; XCUITest only for what unit
tests structurally cannot reach — rendering. See the header of
[ConversionSmokeTests.swift](Color%20ToolkitUITests/ConversionSmokeTests.swift) for
the accessibility-tree conventions before writing UI tests.

- A green test is not a test that tests anything. Confirm a new regression test
  **fails against the unfixed code** before trusting it. For a *new* feature with no bug
  to regress against, mutate the feature instead — every load-bearing claim in
  `Transform/` was checked that way, which is what proved the ramp's conditional clamp
  is a correctness rule and not an optimization.
- **Missing-component semantics have no oracle either, and the reason is different.**
  colorjs.io *resolves* `none` on conversion — `hsl(none 50% 50%).to("oklch")` comes
  back with a real hue — so it cannot answer §13.2's question at all. The spec's worked
  examples are the fixtures. Where the spec prints a converted value, assert that our
  value **rounds to it** rather than picking a tolerance: a printed `0.0001` is a
  bucket, the true chroma is `5.9e-5`, and `|x − 0.0001| < 5e-5` passes by 9e-6 while
  reading like agreement to four decimals.
- **`Transform/` and `GamutBoundary` have no oracle, deliberately.** colorjs.io has no
  notion of a harmony, a ramp or a solver, so assert the *property* (a hue exactly 180°
  away, every stop in gamut, the answer passes `meets` and one step back fails) rather
  than recorded output — which stays true if the arithmetic is rewritten. The
  conversions underneath are oracle-validated already; do not re-test them here.
- **`Export/` does have an oracle: this app's own parser.** Its output is CSS, so the
  discriminating test pulls the value back out of the document, parses it with
  `CSSColorParser`, and requires the color to survive. Exact-string assertions are
  correct for the *syntax* (a `:root` block either has its braces or is not one) and
  still wrong for presentation copy. When adding a shape, check it at **both
  cardinalities** — `json` and `tailwindConfig` fork on a lone color versus a scale, and
  a single-entry test happily passed a broken multi-entry branch.
- **Swatch buttons carry their CSS as an `accessibilityLabel`.** A colored rectangle
  says nothing to VoiceOver *or* to XCUITest, so a row of derived colors is otherwise
  untestable — and a harmony that emitted one color three times would pass.
- **Never write a fallback chain of XCUITest queries.** One named query, and dump
  `app.debugDescription` on failure. A chain that silently matches on index is a test
  that cannot fail — one hid a picker announcing its SF Symbol name to VoiceOver.
- **A SwiftUI `Button` is one accessibility element, so nothing layered over it is
  visible.** A control put in a Button's `.overlay` disappears from the tree entirely
  *and* makes the Button's own identifier match twice, which breaks unrelated tests
  querying it. Interactive siblings go in a `ZStack`, not an overlay. Decorative ones
  (a selection ring) are fine inside the label.
- `.draggable`/`.dropDestination` sit on the tile that wraps the swatch Button, not on
  the Button. Whether a Button would consume the press is **not established** — the test
  that would have shown it cannot drive a drag either way (next bullet), and moving the
  modifier changed nothing observable. Recorded as a placement, not a rule.
- **XCUITest cannot drive a drag-and-drop.** `.draggable`/`.dropDestination` open an
  AppKit dragging session, and XCUITest's synthesized events move the pointer without the
  session ever beginning — including with
  `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`. A drag-driven test
  fails whether the feature works or not, so do not write one and do not read its failure
  as a bug. Give the same action a menu or keyboard command, test *that*, and let the two
  share one handler. This is worth doing regardless: a drag-only affordance is unusable
  from the keyboard and from VoiceOver.
- A palette swatch is `app.otherElements[…]`; a saved color is `app.buttons[…]`. Both
  publish their label, but they are different element kinds and the wrong query never
  matches. A palette swatch's label is its **key**, not its CSS.
- **Query the right element kind, and scope dialogs.** A SwiftUI `Picker` is a
  `popUpButton`; a `Menu` is a `menuButton` — the wrong one simply never matches. A
  `confirmationDialog`'s buttons appear more than once app-wide, so query them through
  `app.sheets`; an ambiguous query fails at the click with no tree to read.
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

**Let it exit before cleaning up.** `git worktree remove` or `rm -rf /tmp/dd` while the
run is still alive deletes `Color Toolkit.app` out from under the UI phase, and the
remaining tests fail with *"Could not launch … no such file"* — which reads as a
regression in the commit under test and is nothing of the kind. Check the process is
gone, then check for exactly one `** TEST SUCCEEDED **`, then clean up.

Commit the work **before** running `swiftformat .`, and commit the formatting on its
own afterward — see *Formatting*. That ordering is what makes the pre-formatted state
recoverable if the reformat goes wrong, and it is also the only way to change a
formatter setting safely: `preserve`-style options mean *leave what is there alone*, so
they cannot undo a conversion that is already in the working tree. Restore the sources
first (`git restore -- '*.swift'`), then reformat.
