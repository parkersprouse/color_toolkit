# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A native macOS color toolkit for web development. Built: CSS Color 4 parsing and
conversion across 14 spaces, a menu bar panel, a screen eyedropper with a global
shortcut, WCAG 2.2 / APCA contrast checking, a gamut-aware HSV/OKLCH picker, OKLCH
transforms — adjustment, harmonies, shade ramps and a contrast solver — export to CSS
declarations, custom properties, JSON, both Tailwind generations and a
`@media (color-gamut: p3)` block with a hex fallback, and saved projects
on SwiftData with reordering and hand-picked palettes, CSS Color 4 §13.2's
missing-component carry-forward, a scoped `calc()`, CSS Color 5 relative color syntax
(`rgb(from …)`), `color-mix()` with premultiplied alpha and the four hue arcs, and W3C
design token import.
M0–M18 are built, so the numbered plan is complete — M18 is `colorkit`, a nine-command
CLI over `ColorCore` in its own tool target — and **M8b is done too**, so an export can be
saved to a file as well as copied. Swift 6, SwiftUI, no third-party runtime dependencies.
**M19–M26 are planned and not yet built**; see PLAN.md.

**[PLAN.md](PLAN.md) is the source of truth** for milestone status, what is deferred
and why, and the reasoning behind every decision recorded below. This file is the
operational layer — what to run and what will break. When the two overlap, PLAN.md
has the argument; read it before making a design call.

## Commands

Build (the scheme builds the app **and** `colorkit`):

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' build
```

To build or run just the CLI — much faster, and the right way to check a project-file
change without a mistake masquerading as an app regression:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -target colorkit -destination 'platform=macOS' build && ./build/Release/colorkit --help
```

Full test suite (~9 minutes, nearly all of it UI tests — the 416 + 59 Swift Testing
tests finish in about a second, the 31 XCUITests take seven minutes and up). **There are
two Swift Testing bundles now**: `Color ToolkitTests` (416 tests, 47 suites) and
`ColorToolkitCLITests` (59 tests, 10 suites), and both are in the scheme:

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

**That command names the failing tests; it does not carry the failure text.** Measured in
M17, chasing an assertion that failed on a tolerance: the `tests` view returns node names
and `"result":"Failed"` and no expectation anywhere in it. The values live one command
further down:

```bash
xcrun xcresulttool get test-results test-details --test-id "ProjectStoreTests/importedPalettesExport()" --path /tmp/res.xcresult
```

That prints `Expectation failed: (parsed.deltaEOK(…) → 4.59e-05) < (1e-9 → 1e-09)` —
the actual numbers, which is usually the whole question.

**Two Swift Testing bundles means `-only-testing:` needs the right target prefix.** The
CLI's tests are `ColorToolkitCLITests/...` — no space, no quoting needed — and the app's
are `"Color ToolkitTests/..."`. `-only-testing:ColorToolkitCLITests` alone runs the whole
CLI suite in about a second and is the fast loop while working on it.

**The two identifiers are spelled differently and neither accepts the other's form.**
`-only-testing:` takes the **target prefix** (`Color ToolkitTests/ProjectStoreTests/foo()`);
`--test-id` takes the bare `nodeIdentifier` (`ProjectStoreTests/foo()`) and answers a
target-prefixed one with *"Failed to find test with the provided identifier"*. Both need
the trailing `()`: omit it from `-only-testing:` and the run selects nothing and reports
`Test run with 0 tests … passed`, which reads exactly like a pass.

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
node Tools/generate-mix-fixtures.mjs      # → Fixtures/mix-vectors.json
```

**The mix generator passes `premultiplied: true`, and that is not a preference.**
colorjs.io defaults to *not* premultiplying and CSS always does, so the default returns
a plausible wrong answer rather than an error — `rgb(50% 0% 50%)` where CSS says
`rgb(33.333% 0% 66.667%)`. Same class of trap as the WCAG `0.03928` / `0.04045` split
below. It also **skips any case whose endpoints leave the interpolation space's gamut**,
because colorjs.io's `range()` gamut-maps both endpoints first ("to avoid areas of flat
color") and CSS Color 4 §12 has no such step — those cases would be asking the oracle a
different question. ColorCore's answer for them is pinned from the other side, by a test
asserting the *un*-mapped result.

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
  a lightness and hue have left), `Convert/Interpolation.swift` (the four hue arcs,
  `color-mix()`'s percentage rules, and premultiplied interpolation),
  `Transform/` (relative adjustment, the S-curve,
  harmonies, shade ramps, the contrast solver — all in OKLCH), and `Export/`
  (declaration templates and six document shapes), and `Import/` (W3C design tokens).
- **`ColorToolkitCLI/` and `ColorToolkitCLIMain/`** — the `colorkit` tool (M18), also at
  the **repo root**. Two root groups for one executable: the first holds the logic and is
  compiled by the tool *and* by `ColorToolkitCLITests`, the second holds `main.swift`
  alone and is compiled by the tool only, because top-level code is legal only in an
  executable module. That split exists so no synchronized-group membership exception has
  to be maintained. The tool target also lists `ColorCore`, so `internal` still works, and
  it does **not** set `SWIFT_DEFAULT_ACTOR_ISOLATION` — that is on the app target, so a
  fresh target correctly defaults to `nonisolated` and ColorCore's explicit `nonisolated`
  annotations are simply redundant there.
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
- **One synchronized root group can be listed by any number of targets, and `ColorCore/`
  is listed by three** — the app, `colorkit`, and `ColorToolkitCLITests`. That is what
  M10's move bought. It also means ColorCore compiles into three separate modules, which
  is why a *fourth* target wanting the CLI's types has to list `ColorToolkitCLI/` too
  rather than importing anything: there is no CLI module to import.
- **`ColorToolkitCLITests` cannot be folded into `Color ToolkitTests`, and the reason is
  not tidiness.** The CLI's sources reach ColorCore through their own module, so
  compiling them into a target that reaches ColorCore through
  `@testable import Color_Toolkit` does not build — and adding `ColorCore/` to that
  target as well would *shadow* the import rather than merely duplicate it, breaking
  every existing test. Testing the built binary from `Color ToolkitTests` is worse: the
  test host is the sandboxed app, so a sandbox denial would be indistinguishable from a
  real failure.
- **The CLI writes results to stdout and everything else to stderr, with three exit
  codes** — 0, 1 for a command that ran and failed, 2 for a command line that was wrong.
  A failing run puts *nothing* on stdout; a parse warning goes to stderr and leaves the
  exit code 0. This is a contract with whatever shell script calls it, and it is what
  makes `$(colorkit convert red --format hex)` safe. Four tests pin it and two mutations
  cover it.
- **`ExportShape`'s raw values are not CLI identifiers, so `Names.shapes` is a table.**
  They exist for `Identifiable` and are not uniform — three carry an explicit hyphenated
  string, three fall back to their case names, and one of those, `customProperties`, is
  camelCase. `Harmony`, `ExportTemplate`,
  `ColorVisionDeficiency` and `ColorSpace` stay *derived* from their raw values, which
  genuinely are the CSS identifiers — the same call `ColorGrammar.interpolationSpace(named:)`
  makes. A test requires every shape name to round-trip and to be lowercase.
- **The CLI refuses an option the chosen shape would ignore rather than dropping it.**
  `--format` with `--shape p3-with-fallback`, `--name` without a shape that `usesName`,
  `--spread` on a harmony that is not analogous. The panel hides those controls; a CLI
  has nothing to hide, and a flag that changed nothing looks like it worked.
- **`solve` reads its own printed answer back, and that is not belt-and-braces.**
  `ContrastSolver` keeps its bracket's passing end, so the answer sits a hair above the
  target — exactly the margin four decimals can round away. Measured: the printed value
  meets AA at precision 5, 7, 8 and 10 and misses it at 4 and 6, so it is rounding luck
  and **no default precision fixes it**. Biasing the rounding was rejected for the same
  reason it is for ramp stops. So the command checks the text with the same predicate a
  caller would and says on stderr when it fell short. Do not "simplify" this away — the
  test asserts a disjunction, not that the printed value always passes.
- **The app touches the file system in exactly two places, and one build setting grants
  both.** `ENABLE_USER_SELECTED_FILES = readwrite` — in *both* the Debug and Release
  blocks, with no `.entitlements` file anywhere — covers the token import's read *and*
  M8b's export write. It is only consulted at runtime, so a Release-only omission is
  invisible from a Debug build; verify in the built binary with
  `codesign -d --entitlements -`, which should report
  `com.apple.security.files.user-selected.read-write`.
  - **Reading** (`ProjectsPanel`, token import) additionally claims the URL with
    `startAccessingSecurityScopedResource()` and stops on the way out only `if scoped`,
    which is correct whether or not a powerbox URL turns out to need the claim.
  - **Writing** (`ExportPanel`, `.fileExporter` + `ExportDocument`) needs no such claim:
    `FileDocument` hands the system a `FileWrapper` and the system does the write.
  - **Neither is testable and both are recorded manual checks — and both have now been
    run.** `NSOpenPanel` and `NSSavePanel` are separate processes XCUITest cannot drive,
    and driving them from outside needs assistive access that `osascript` does not have
    here. So an agent cannot verify either one and should say so rather than infer it from
    a green suite. M17's read passed on the built app; M8b's write passed across 34 saves,
    whose 352 exported values all re-parse, with the panel proposing the filename
    `suggestedFilename` builds. See the M8b and M17 entries in PLAN.md.
  - **A file the user hands you may itself be the manual check.** M8b's write was
    confirmed twice over by export files sent for review, and was still asked for a third
    time. If a `.css` in the repo's own export shapes arrives, ask where it came from
    before requesting a check that has already happened.
- **`ExportShape.fileExtension` is in ColorCore; the `UTType` is in the UI layer and is
  derived from it.** The extension is a fact about the shape — what `tailwindConfig`
  writes *is* a JavaScript module — and it is transcribed, because four of the six shapes
  answer `css` (including `p3WithFallback`, whose `@media` block is still a stylesheet).
  `ExportDocument.writableContentTypes` derives from the same table, so a shape cannot
  propose `brand.css` while tagging the file as JSON. The proposed filename comes from
  `ExportOptions.identifier`, the *sanitized* name, so the file is called what the
  properties inside it are called.
- **Beware a test whose two sides derive from one source.** M8b's first
  "every shape's content type is writable" compared `writableContentTypes` against
  `contentType` — but the former is built from the latter, so the claim was true by
  construction and survived a mutation collapsing every shape onto `css`, which is exactly
  the bug it was written for. The fix was a *distinctness* assertion, which no derivation
  can satisfy for free. When a mutation survives, ask whether the assertion can fail at
  all before concluding the rule is safe.
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
- **Three `savePalette` overloads, and merging any of them destroys data.** What differs
  is how each derives the stored *spelling*, which is the one thing a shared door loses.
  The `[PaletteEntry]` one re-derives a spelling because ramp stops and harmony members
  never had one; the `from: [SavedColor]` one copies `ColorRecord` so a user's typed
  `rebeccapurple` survives; the `importing: [DesignToken]` one spells each color in the
  space its token named, because a token's `colorSpace` is authored information too.
  `newPalette(named:kind:in:)` is deliberately the *only* shared part — it carries no
  decision, and extracting it is what keeps three identical-looking preambles from
  inviting the merge. Palette keys from a hand-picked set are **deduplicated**, and so are
  imported ones (against the sanitized key — see below) — two entries sharing a key
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
- **A mix converts with carry-forward and *then* marks powerless components missing —
  and the second step is the one whose absence you can see.** `ColorInterpolation`
  runs `convertedForInterpolation(to:).markingPowerlessComponents()`, in that order.
  Drop the marking and `color-mix(in oklch, white, blue)` averages white's hue of 0°
  with blue's 264° and returns a **green**; keep it and white's hue is absent, so it
  takes blue's and the answer is the light blue anyone would expect. Inside
  interpolation the two kinds of missing behave identically — each takes the other
  color's value — which is *why* the order still matters: marking first would blank a
  value carry-forward is supposed to preserve.
- **Nothing in the mix path gamut-maps, and the reference disagrees.** CSS Color 4 §12
  has no mapping step, so `color-mix(in srgb, color(display-p3 0 1 0), black)` keeps its
  negative red channel and the "outside sRGB" badge reports it. colorjs.io's `range()`
  maps both endpoints in first — a gradient nicety — so the fixture generator skips
  those cases and a Swift test pins the un-mapped answer instead. Adding a map here to
  "fix" a strange-looking swatch would silently make this app disagree with browsers.
- **Every premultiplication exemption is stated against what is missing on *both* sides,
  never against one color's own `missing` flag.** Substitution has already run by the
  time anything is scaled, so a one-sided `none` alpha *has* the other color's value and
  premultiplies like any other — both ends scale by the same number and it cancels,
  which is why the reference answers such a mix with the plain average. Reading the flag
  instead scales one side only and then divides the other side's components by an alpha
  they never gained: `color-mix(in srgb, rgb(255 0 0 / none), rgb(0 0 255 / 0.25))` comes
  back at **200% red**. It is also not symmetric, so it makes an even mix depend on the
  order of its operands — the cheaper thing to assert. This was a real bug, shipped in
  M15's first commit and fixed on first contact with a compiler.
  The three exemptions themselves: a hue is never premultiplied (scaling an angle by
  opacity is meaningless), a component missing on both sides is not (there is no value
  to scale), and un-premultiplying additionally stops at alpha 0, where dividing is a
  NaN rather than a recovery. **Only the hue skip is exercised by the recorded vectors** —
  no fixture endpoint can carry a missing component, since `MixFixture.Endpoint`'s alpha
  is a plain `Double` — so the other two are pinned by hand-written tests, and both of
  those tests exist because the mutation that removed the rule survived without them.
- **`color-mix()`'s percentage shortfall only ever reaches *down*.** Percentages summing
  under 100% re-normalize *and* multiply the result's alpha by the sum — `red 20%,
  blue 20%` is an even mix at 0.4 alpha. Over 100% only re-normalizes, because scaling
  up would hand back a color more opaque than either input. A percentage outside
  `[0, 100]` is **rejected**, unlike alpha, which clamps: `red 150%` carries no
  intention to read.
- **`color-mix()` is deliberately not a `ColorFunction` case.** That enum lists functions
  whose arguments are *components*, and every one of them has a per-component grammar, a
  legacy-comma question and a fixed space. A mix has none of the three, so a case there
  would mean four tables gaining an entry that means nothing. It is a branch in
  `parseFunction` and a `ColorNotation.mix` case carrying the interpolation method.
- **`ColorGrammar.interpolationSpace(named:)` is *derived* from `ColorSpace`'s raw
  values, and that is not a contradiction of the transcription rule above.** The
  transcribed tables state facts the identifiers do not carry — a component's role, its
  channel keyword, and which eight of the fourteen spaces `color()` accepts. This one has
  no such fact: *every* space is a legal interpolation space, and the raw values are the
  CSS identifiers. The discriminating question is the same one as always — is there
  something a derivation can lose?
- **`ColorSpace.channelKeywords` is transcribed from CSS Color 5, never derived** — the
  same rule as `componentRoles` and for a sharper reason. Deriving from `componentLabels`
  works today for all fourteen spaces, which is the trap: those labels are editorial copy
  the UI layer may reword, so renaming "Chroma" would make the parser accept
  `oklch(from red l o h)` and reject the spec's spelling. Deriving from `componentRoles`
  is outright wrong — XYZ shares sRGB's `(.reds, .greens, .blues)` there but spells its
  channels `x y z`.
- **A relative channel keyword carries its *function's* written scale, not its space's.**
  `stored / numberScale`, which diverges only in `rgb()` — stored 0–1, written 0–255. So
  red's `r` is 255 in `rgb(from red …)` and 1 in `color(from red srgb …)`, on one space.
  `ChannelBindings` takes both the function and the space because neither implies the
  other: the function fixes the scale, the space fixes the spelling and is the conversion
  target.
- **In relative syntax `none` means two different things.** Written bare, a missing
  channel stays missing; inside a `calc()`, the spec reads it as zero. `ChannelValue` has
  two cases rather than being a `Double?` precisely so the two cannot be flattened, and
  each half is pinned by a mutation the other survives.
- **The origin color's closing paren is found by depth; a `calc()` body's is not.** These
  look like one problem and are two — a calc body cannot nest, so its first `)` is its
  own, while color functions nest freely. Note that the obvious nesting tests do *not*
  discriminate: "first close paren wins" passes them all, and only an origin containing
  another function (a `calc()` inside it is the cheapest) tells the two apart.
- **Alpha is clamped at parse time and the three components are not.** The spec's rule in
  both directions, not an oversight: an out-of-gamut color has to be writable — the
  "Outside sRGB" badge reports exactly those — while nothing lies beyond fully opaque.
- **A `calc()` body is consumed as a unit, before separator logic sees inside it.**
  `/` is the alpha separator *and* calc's division, so `rgb(0 0 0 / calc(1 / 2))` has
  two slashes meaning different things and which side of the parens they fall on is
  the only thing telling them apart. This is why `scanArguments` iterates by index
  rather than with `for in`. Let a calc body's slash escape to separator logic and
  every test with a slash in its input fails, which is exactly the set that should.
- **The tokenizer's three readings of `-` are ordered, and the order is load-bearing.**
  Number sign (`-0.5`), then identifier start (`--custom`), then subtraction — each
  earlier rule the more specific. Hoisting the operator rules above `isNumberStart`
  breaks `rgb(+128 0 0)` in the *curated fixture*. The ordering also buys CSS's
  whitespace rule for free: `scanNumber` claims `-2`, so `calc(1 -2)` is two adjacent
  values and gets rejected, exactly as the spec intends. `calc(1- 2)` is the leniency
  that costs — invalid CSS, accepted here, because whitespace is already discarded.
- **`calc()`'s type rules are scoped to this parser, not claimed as CSS invalidity.**
  Percentages resolve against a reference in a color component, so CSS Values 4's type
  algebra is more permissive than `CalcExpression` is. Keep error text and test comments
  saying "here" — widening the rules later should not have to retract a claim.
- **A resolved `calc()` is indistinguishable from a written value downstream**, on
  purpose: `Value.init(_ term: CalcTerm)` is the whole bridge, and the per-component
  grammar, the legacy same-type rules and the angle-slot check all run unchanged. So
  `rgb(calc(50%), 0, 0)` passes legacy rgb's same-type rule and
  `hsl(120, calc(25 * 2), 50%)` fails its percentage-required one. Both are pinned.
- `ColorStore` keeps **text** as its source of truth, so an adopted color is
  serialized and immediately re-parsed. Storage precision (`CSSFormatOptions.lossless`)
  and display precision (`store.formatOptions.precision`) are separate settings; a
  panel that rounds re-derives next frame, a stored string that rounds is destroyed.
- ColorCore owns *facts* (the format catalog, gamut predicates); the UI layer owns
  *editorial copy* (format titles, section names in `FormatPresentation.swift`). A
  core test reaching into the UI for a display string is a smell.
- Precision is relative to each component's scale, not a flat decimal count — see
  `CSSFormatOptions.decimals(forFullScale:)`.
- **Every RGB→polar conversion guards its hue with an epsilon, never with `!= 0`.**
  `Conversion.hueFromRGB` is the one implementation for HSL and HSV (and so for HWB, whose
  hue comes straight through `hsvToHWB`), and it returns `0` below
  `achromaticChannelEpsilon` — `1/100000` of a channel, derived exactly the way
  `ColorSpace.polarEpsilon` is, so the RGB-based polar forms and the Lab-based ones agree
  about what grey means. **The exact test is not merely imprecise, it is wrong in a way
  you can read**: a neutral grey that reaches sRGB *through a conversion* has channels
  differing in the last ULP rather than not at all, so `delta` is ~1e-16 and the hue
  becomes a ratio of two pieces of noise — any angle at all. That shipped, and an exported
  greyscale ramp read `hsl(336 0% 96.06%)`, `hsl(350 0% 87.86%)`, `hsl(345 0% 79.79%)`,
  hue wandering across eleven colors that have no hue. A grey *typed* in sRGB was always
  fine, because its channels are bit-identical — which is why no hand-written test caught
  it and why the regression test converts from `oklch()`. **Saturation deliberately keeps
  the exact `delta != 0` test**: a near-grey has a real if minute saturation, and that is
  what holds the round trip once the hue is zeroed.
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
  and calls it a stylesheet. `usesFormat` is the third such flag and the only one that
  hides a control which would be *harmful* rather than merely inert — see the P3 shape
  below.
- **`p3WithFallback` fixes both its formats, and the fallback must stay hex.** It writes
  two blocks where `ExportOptions.format` is one value, so the panel hides the Format
  picker (`usesFormat == false`). Making it live again — or pointing the fallback at
  `options.format` — puts the panel's default `oklch()`, which is unbounded, into the
  block a browser reaches precisely when it *cannot* do wide gamut. Hex is also the only
  choice that `cannotRepresentOutOfGamut`, so the fallback provably falls back. Both
  blocks are built by one `propertyLines` call so they cannot come to name different
  properties: an override that misses its base is a `@media` block with no effect and
  looks perfectly fine. And **the override is emitted for every entry, in gamut or not** —
  a per-entry conditional would make the block's contents depend on the palette's
  contents, so widening one color would silently change which properties exist. Four
  mutations pin all of this.
- **The export badge counts against `ExportOptions.mappedCountFormat`, not `format`.**
  Same one-predicate rule as everywhere else, but a shape writing two spellings needs to
  say *which* one the count is about. For `p3WithFallback` it is the **fallback**: count
  against the P3 block instead and a color outside sRGB reports `0 mapped` while the hex
  line right under the badge has been rounded. The sentence changes with it —
  `ExportShape.mappedNote` is per shape because the generic "the values below were
  brought into gamut" is false of the media block, which is written in a wider gamut.
  The count and the copy are one decision; do not change either alone.
- **The P3 override promises nothing about exactness, and the note must not either.**
  `color(display-p3 …)` is not `cannotRepresentOutOfGamut`, so unlike the hex fallback it
  has no fixed answer: it follows the **app-wide gamut policy**, which is `.map` in the
  panel and `.preserve` under `CSSFormatOptions.lossless`. Under `.map` a color outside
  *P3* is mapped in **both** blocks. The badge counts against hex, so it counts those
  colors too. A first draft of
  the note said the media block "carries them exactly": true of the P3-reachable colors
  that motivate the shape, false of the rest, and printed three lines above the value it
  described. Wording that stops at *which block writes what* is true either way. A
  substring test cannot catch a claim like this — the fact is pinned by an input,
  `p3OverrideIsNotAnExactnessPromise`, which renders a Rec.2020 primary and requires the
  override to have moved.
- **Palette keys are syntax, not labels.** They become CSS identifiers *and* JavaScript
  object keys, and Tailwind writes shade keys bare — legal for `50:`, fatal for
  `triad-2:`, which parses as a subtraction and stops the config loading. They must also
  be unique: two entries sharing a key silently collapse into one property and a color
  vanishes. `ExportOptions.javaScriptKey` and `cssIdentifier` are the only places that
  decide this; do not format a key inline.
- **An imported token's keys are uniqued against the *sanitized* key, never the raw path.**
  Token paths are unique by construction, which makes "so the keys are too" the obvious and
  wrong conclusion: `-` is a legal name character in the token format and `.` is not, so
  `brand.500` and `brand-500` are two legal tokens that `cssIdentifier` maps onto one
  identifier — and then the rule above fires and a color vanishes from the export. The
  `-2` suffix loop in `DesignTokenImport.keyed` is the same one `ProjectLibrary`'s
  hand-picked overload uses, for the same reason.
- **The design token importer performs no arithmetic on a component and must not start.**
  The format's ranges are CSS Color 4's own *number* forms and this app stores number
  forms, so the mapping is the identity for all fourteen spaces. Reaching for
  `ColorGrammar` to "convert" is wrong twice over: those tables are CSS *syntax* and have
  no authority over this format, and `rgb()`'s number form runs 0–255 where the format's
  `srgb` runs 0–1 — scale by it and `[1, 0, 0]` imports as a near-black that still renders
  and still round-trips. PLAN.md's original M17 note said to validate against
  `ComponentGrammar.fullScale`; that is a *precision hint*, not a bound, and the Color
  module leaves both chromas and both a/b pairs unbounded, so it would reject legal
  tokens. A test asserts each space's written scale is 1, so the assumption fails loudly
  rather than quietly.
- **Token aliases resolve *before* the `$type` filter, not after.** The format's precedence
  is explicit `$type` → the **resolved reference's** type → the nearest group's, so a token
  with no type of its own that aliases a color token *is* a color token. Filter first and
  exactly those disappear with nothing said. Cycle detection is load-bearing for a sharper
  reason than usual: removing it does not fail a test, it takes the process down — the
  mutation run reported no failing test at all.
- **In a token file, `hex` is a fallback for an unknown *space* and for nothing else.** A
  known space with unreadable components is a broken token and is reported as one, even
  with a good `hex` sitting beside it — using it would substitute a 6-digit sRGB
  approximation for whatever the components meant and say so nowhere. The unknown-space
  path mirrors `ColorRecord.colorValue` skipping a stored space it does not recognize.
- **Imported colors are stored spelled in the space their token named**, which is why
  `savePalette(importing:)` is a third overload rather than a call into either existing
  one. Same rule as the other two: what differs between them is how a stored *spelling* is
  derived, and merging destroys it. A `display-p3` token comes back
  `color(display-p3 …)`, not canonicalized to `oklch()` — a token's `colorSpace` is
  authored information, exactly like a typed `rebeccapurple`.
- **`JSONSerialization` hands back an unordered dictionary, so an imported palette's order
  is chosen, not preserved.** All-digit names compare numerically and everything else as
  text, which is what puts a shade ramp in `50, 100, 950` rather than the alphabetical
  `100, 1000, 50`. Same class of hazard as the SwiftData to-many relationship below: the
  output looks well-formed either way.
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
  is why M15's mixing folded into `Transform` — a fifth section, not an eighth tool —
  and why M17's import folded into `Projects` — a button beside the save controls, not an
  eighth tool. Adding an eighth means budgeting for shorter
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
- **A mutation that survives means the tests are incomplete, not that the rule is safe.**
  M14 replaced the origin color's paren-depth counting with "first close paren wins" and
  the entire suite passed — because the obvious nesting cases do not discriminate
  (`rgb(from color(display-p3 1 0 0) r g b)` has one paren level, so the first `)` already
  is the right one). The rule was fine; the coverage was not. Treat a green mutation run
  as a finding to chase, and prefer a blunt mutation's *failure set* over its size — M13's
  first attempt at the slash rule simply switched the feature off and failed fifteen
  tests, which proved nothing until it was sharpened to fail only the slash cases.
- **Four parser features have no oracle, each for a different reason** — worth knowing
  before reaching for colorjs.io. It *resolves* `none` on conversion (so it cannot answer
  §13.2 at all, M12), it *rejects* `calc()` outright (M13), it has *no relative color
  syntax* whatsoever — every `rgb(from …)` comes back "Expected 3 coordinates … got 4"
  (M14) — and it cannot *parse* `color-mix()` even though it can compute one, so M15's
  grammar is hand-written while only its numbers are generated. Ask it before assuming
  either way; the answer has differed every time. **M17's importer is a fifth case and the
  simplest**: colorjs.io parses CSS, and a design token's `$value` is a JSON object, so
  there is nothing to ask. The Color module's documented shapes are the fixtures.
- **Where floating point intrudes, assert the discrimination rather than the value.** Not
  a loosened equality — a different claim. White's OKLab lightness is
  `1.0000000000000002`, so M14's "is `l` written 0–1 or 0–100?" is settled by a tolerance
  four orders of magnitude below the ~100 that separates the two readings. Say in the test
  what the competing hypothesis is and by how much it differs, or the tolerance looks
  arbitrary and the next person tightens it.
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
- **`fileImporter` is the same shape: XCUITest cannot drive `NSOpenPanel`.** It is a
  separate process, so a test that clicked Import Tokens… would hang on a panel it cannot
  reach and fail whether the feature worked or not. `ProjectsSmokeTests` therefore stops
  at asserting the control exists and is hittable; the decode is covered by
  `DesignTokenImportTests` and the save by `ProjectStoreTests`, and **the file read itself
  is covered by nothing and is a recorded manual check**. Note this generalizes past
  tests: driving that panel from outside needs assistive access, which `osascript` does
  not have here, and `screencapture` is likewise blocked — so an agent cannot verify this
  one either, and should say so rather than infer it from a green suite.
- **The CLI has no `mix` command on purpose, and a test holds the argument up.** The
  parser already accepts `color-mix(…)` and `rgb(from …)` as *input* to `convert`, so a
  subcommand would be a second door into one room. `theParserIsTheMixCommand` fails if
  that stops being true, so the reasoning stops holding out loud rather than quietly.
- **A CLI test that reads "everything after the first space" as the value is wrong for
  five of the eight output shapes.** JSON and both Tailwind shapes quote and comma their
  values, `declaration` follows each with a `/* key */`, and `solve` puts a ratio in a
  third column — so that reader hands back a value with punctuation attached, which
  reads exactly like a broken serializer. `printedColors` matches structurally instead:
  a `#` run, or a **color function** name immediately followed by a balanced paren
  group. The "color function" qualifier is load-bearing — `tailwind-config` opens with
  `/** @type {import('tailwindcss').Config} */` and `import(…)` satisfies everything else.
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
- **"Never became hittable" plus a tree whose `Application`, `Window` and `Toolbar` all
  read `Disabled` is the host, not the app.** The element is present with real
  coordinates and the app is simply not frontmost — XCUITest cannot click into a macOS
  app it cannot activate, and using the Mac during a run is enough to cause it. Check
  `ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}'` before
  reading it as a regression, and confirm by re-running the one test at an unmodified
  commit in a worktree. Observed in M15: `testASavedRampExportsUnderItsOwnName` failed
  three times running, failed identically at the unmodified commit, and then passed six
  of six once the Mac was idle. Do not "fix" it by loosening the wait — a chain that
  falls back to a non-hittable click is a test that cannot fail.
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
