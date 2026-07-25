# Color Toolkit — Implementation Plan

> **Status (2026-07-24): M0–M8 and M5b (CVD) complete, every milestone reviewed on the
> running app and the full suite green** — **257 Swift Testing functions across 31
> suites plus 19 XCUITests**, which expand to 485 individual cases once parameterized
> arguments are counted (the figure `xcresulttool` reports).
> ColorCore is validated against **colorjs.io 0.7.0** (pinned exact) — 6,384
> conversions, 1,368 gamut mappings and 108 contrast pairs — plus independent
> definitional anchors, and **405 CVD vectors** over Machado's Table 1. Next up:
> **M9 (projects)**.
>
> M8's exports were checked against the reference from the panel's own screenshots:
> exporting `#3b82f6` as a shade ramp writes `--brand-500: oklch(0.6231 0.188 259.81)`,
> and colorjs.io agrees to six decimals. Its **tool switcher moved out of the toolbar**
> in the process — a sixth segment made macOS sweep the whole switcher into an overflow
> menu, taking every tool with it. See the milestone below.
>
> M7's harmonies were checked against the reference from the panel's own screenshots:
> adopting the triad member of `#3b82f6` writes
> `oklch(0.6230830326 0.1880147345 19.81452853)`, and colorjs.io agrees to ten decimals
> — lightness and chroma preserved exactly, hue rotated 120° and wrapped past 360. Its
> hex, `#e24956`, matches the panel's own readout. The transforms themselves have **no
> oracle** (colorjs.io has no notion of a harmony, a ramp or a solver), so they are
> tested definitionally, the way the gamut boundary is.
>
> M5b's matrices were confirmed against three independent copies of Machado's Table 1
> (see the finding below), and the panel was reviewed on the running app: pure red
> simulates to olive under protanomaly and green to yellow under deuteranomaly — the
> signature of a correct linear-RGB pipeline, which a gamma-space application would miss
> by ~0.26.
>
> M6's boundary readouts were checked against the reference from the panel's own
> screenshots: at `L 0.7 h 140` the panel says sRGB allows `0.2253` and the oracle
> agrees exactly; at `L 0.6231 h 259.8` it says `0.2037` against the oracle's `0.2038`
> — one search step, and deliberately on the inside, since the search returns a chroma
> that *is* in gamut rather than one merely near it.
>
> The contrast panel was checked against the reference from its own screenshots:
> `#ffffff` on `#3b82f6` renders 3.68:1 / Lc −69.4, and swapped, 3.68:1 / Lc +63.9 —
> all four exact. That pair is also the clearest demonstration of why both algorithms
> are shown at once. WCAG returns the *same* ratio and the *same* five pass/fail
> verdicts for both directions; APCA separates them by 5.5 points, because white on
> blue genuinely reads better than blue on white.
>
> **M4's three untestable links are confirmed by hand**, each verified separately
> because they fail independently: the menu bar shows ⌃⌥⌘C beside "Pick Color from
> Screen" (so the OS accepted the registration and a scene's `.task` fired), the chord
> raises the loupe from another app (so the key is captured and the C callback reaches
> the main actor), and the picked color lands in both the field and the clipboard (so
> the sandbox permits the sampler and the bridge works end to end). No permission
> prompt appeared at any point — `NSColorSampler` and Carbon hot keys are both
> confirmed sandbox-safe on macOS 26.5.
>
> Three things came out of looking at the running app: precision is now relative to
> each component's scale, long values wrap instead of truncating mid-number, and the
> note on orphaned instances under **Running the app** below.
>
> M2 note: colorjs.io is the oracle for *conversions* but **not** for *parsing* — its
> parser accepts `rgb(a b c)` as `rgb(none none none)` and tolerates commas in
> modern-only functions. The parser targets the CSS grammar itself; the parse fixture
> is a hand-curated valid-CSS-only list, and rejection cases are asserted in Swift.
>
> Findings worth carrying forward:
> - Matrices and the named-color table are **generated**, not transcribed
>   (`node Tools/generate-constants.mjs`). A recalled Bradford D50→D65 matrix diverged
>   from the real one at the 7th decimal — generation eliminated that class of bug.
> - `gamut_mapping` defaults to `"css"` in both 0.6.0 and 0.7.0, but the fixture
>   generator passes it explicitly anyway, so a version bump can't silently change it.
> - The 0.6.0 → 0.7.0 upgrade produced **byte-identical** generated Swift and
>   **zero** differences across all 7,752 fixture values; `toGamutCSS` is unchanged.
>   0.7.0 exports each space's matrices as `M`, so the generator now imports them
>   instead of scraping source — it requires >= 0.7 as a result.
> - The app target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so every
>   ColorCore file needs an explicit `nonisolated` or it gets stranded on the main
>   thread. Plain data in the UI layer needs it too, or non-`@MainActor` tests can't
>   read it.
> - Rec.2020 does **not** contain Display P3 — gamut checks must be per-color, never a
>   ranking of space "widths". Confirmed again in M3: `oklch(0.9 0.3 140)` is outside
>   sRGB, P3, Rec.2020 *and* A98, but inside ProPhoto; P3 green is outside A98 yet
>   inside Rec.2020. Verify every containment claim against the reference.
> - The gamut badge and the serialized string come from **one** predicate
>   (`ColorValue.isGamutMapped(as:options:epsilon:)`), differing only in tolerance.
>   Computing them separately would let the badge lie about the value beside it.
> - Hex is 8-bit quantized, so round-trip tests need a per-format tolerance: exact for
>   decimal formats, ~0.005 ΔEOK for hex, one JND for anything gamut-mapped.
> - **Precision is relative to each component's scale, not a flat decimal count.**
>   Four decimals is right for an OKLCH lightness of `0.6231` and absurd for a hue of
>   `217.2193`. `CSSFormatOptions.decimals(forFullScale:)` drops one decimal per power
>   of ten above unit scale, so every component carries about the same number of
>   meaningful digits.
> - SwiftUI merges a `Button`'s children into one accessibility element, so conversion
>   rows are reachable in XCUITest as **buttons** labeled `"hsl(), hsl(217.22 …)"` —
>   there is no `StaticText` for the value.
> - Each commit must build and test **standalone**, verified in a `git worktree` — a
>   green run at HEAD does not prove the intermediate commits are bisectable.
> - **`NSColor.usingColorSpace(.sRGB)` clips, silently.** Handed Display P3 red it
>   returns `1, 0, 0` — identical to plain sRGB red, no error, no signal. That one call
>   is why most Mac eyedroppers lie about vivid colors. Sampled colors are read into
>   **linear extended sRGB** instead (sRGB primaries, no transfer function, components
>   free to leave 0–1), which lands directly on `ColorSpace.srgbLinear`.
> - **ColorSync is not the CSS spec, and falls short in two different ways.** Measured
>   against colorjs.io 0.7.0: same-primaries (sRGB → linear sRGB) agrees to ΔEOK
>   **3.3e-8**, cross-primaries (P3 → sRGB) only to **3.4e-5** — a thousandfold gap.
>   The small one is just ColorSync's **float32** pipeline (components differ by 1.1e-7
>   at a value of 0.92, exactly one `Float` ulp); the large one is the display's ICC
>   primaries genuinely differing from CSS Color 4's idealized matrices. Both sit far
>   under a 0.02 JND, but a sampled color is only ever as exact as the system's color
>   management — assert a tolerance, never equality.
> - **Storage precision and display precision are different settings.** `ColorStore`
>   keeps *text* as its source of truth, so an adopted color is serialized and
>   immediately re-parsed; anything the spelling rounds or gamut-maps is gone for good.
>   `adopt` therefore uses `CSSFormatOptions.lossless` and
>   `ColorValue.spelling(preferring:)` — never the user's chosen precision, which
>   governs only what panels show. Writing a P3 sample as hex would have re-introduced
>   the clipping bug one layer below the bridge that just prevented it.
> - Carbon `RegisterEventHotKey` / `InstallEventHandler` still compile, link, and
>   return `noErr` on macOS 26.5 under `-swift-version 6`. The C callback reaches
>   `@MainActor` via `MainActor.assumeIsolated` and needs no `userData` round trip,
>   because a `shared` singleton is the same indirection without the unsafety.
> - **colorjs.io is an oracle for APCA but only a cross-check for WCAG.** It does not
>   implement WCAG's definition: luminance comes from XYZ-D65 Y, which uses the
>   full-precision matrix row where WCAG's text specifies rounded coefficients, and it
>   linearizes at 0.04045 where WCAG says 0.03928. Measured divergence is up to
>   **1.97e-4 relative** over 20,000 random 8-bit pairs. WCAG correctness therefore
>   rests on published anchors (21:1, 1:1) that hold under either definition, plus one
>   discriminating pair that asserts the WCAG answer *and* asserts a mismatch with
>   colorjs's — so silently adopting the reference's definition fails rather than passes.
> - Two near-identical linearizations that must **never** be merged:
>   `TransferFunctions` uses **0.04045** (sRGB, and what every conversion is validated
>   against), `wcagRelativeLuminance` uses **0.03928**. They look like the same function
>   with a typo. Note the famous discrepancy is *unobservable* on hex colors — no
>   `k/255` lands between the thresholds — while the coefficient rounding nobody talks
>   about affects every color including hex.
> - Contrast maths gamut-maps before measuring. Not cosmetic: an out-of-sRGB color has
>   negative components and `pow` of a negative is NaN, which propagates silently and
>   surfaces as "nan:1". colorjs.io leaves this case explicitly unspecified.
> - **A forgiving XCUITest selector is a test that cannot fail.** The first contrast UI
>   test tried three queries and clicked whichever existed; it passed via an
>   index-based fallback while the named query never matched. Replacing the chain with
>   one named query plus a tree dump on failure exposed a real defect: a segmented
>   `Picker` renders a `Label` icon-only and hands VoiceOver the **SF Symbol name**, so
>   the switcher announced "arrow.left.arrow.right" instead of "Convert".
> - **The sRGB gamut is not star-shaped about the neutral axis in OKLCH, and blue is
>   the counterexample.** Walking chroma outward at blue's own lightness and hue, sRGB
>   red goes negative at `0.2656`, bottoms out at **−0.009** near `0.29` — three orders
>   of magnitude past float noise, so this is the shape of the gamut and not rounding —
>   and returns to zero only as the ray grazes the blue vertex at `0.3132`. The in-gamut
>   set is genuinely two pieces. Bisection reports the first exit and misses the far
>   sliver, which is what to want: the band between is outside sRGB, and drawing the
>   second island would present a stripe of unreachable colors as reachable. 3,420
>   lightness/hue pairs found no other disconnected ray.
> - **"Where does the gamut end" and "where does gamut mapping land" are different
>   questions.** §13 takes a clipped result whenever clipping costs under a JND, and at
>   a cube corner it costs nothing — so it maps blue's coordinates to `#0000ff` at full
>   chroma `0.3132` while the boundary sits at `0.2656`. Deriving the picker's curve
>   from the mapper would put the cursor inside the line for colors the badge calls out
>   of gamut. The curve must agree with the **badge**, and does.
> - **A channel tolerance is not a chroma tolerance.** `gamutNoiseTolerance` is 7.5e-5
>   *of a channel*; OKLab's cube root turns that into **0.041 of chroma at `L = 0`**, so
>   handing the badge's constant to the boundary search looks like consistency and is a
>   unit error — the curve bulges to a visible width at pure black, which has no chroma
>   at all. The curve is strict, the badge stays forgiving, and they differ only over
>   colors indistinguishable from black.
> - **A picker cannot read its own writes.** The store keeps text as its source of
>   truth, so every drag tick would serialize and re-parse — and the round trip loses
>   exactly what a picker must not: a gray comes back with no hue, so the strip snaps to
>   red one frame after saturation reaches zero. The axes lead and the store follows,
>   guarded by comparing the returned text against the last text written. A boolean "I
>   am writing" flag is the tempting version and the wrong one: the store reparses
>   synchronously but observation fires later, so the flag is already clear by the time
>   the callback lands.
> - **`.task(id:)` restarting does not stop a `Task.detached` it started.** Detached is
>   exactly what it says: no parent, so no inherited cancellation. Discarding the stale
>   *result* afterwards still looks correct and still burns a full plane of conversions
>   per frame of a drag — a throttle that isn't one. The render task is held and
>   cancelled explicitly, and the loops check `Task.isCancelled` so the cancel has
>   somewhere to land.
> - **A `GeometryReader` square inside a `ScrollView` takes the whole unbounded height
>   proposal.** The window opened 948pt tall, and the resize moved the mode switcher out
>   from under a click already in flight — surfacing as "Not hittable", which reads like
>   an accessibility problem and is a layout one. Size such a thing from *width*, which
>   is bounded and cannot feed back into itself.
> - **`.accessibilityIdentifier` on a SwiftUI `Text` publishes the string as the
>   element's `value`, leaving `label` empty.** XCUITest assertions on `.label` then
>   compare against `""` and report a mismatch with nothing, which points at the panel
>   rather than at the query. Only `app.debugDescription` says so.
> - A test that passes is not necessarily a test that tests anything. Both new `adopt`
>   assertions were confirmed by **mutating `adopt` back to the old implementation and
>   watching them fail** — which caught that the first draft of the precision test used
>   a P3 color that happened to be exactly `#3b82f6`, so hex round-tripped it perfectly
>   and the test proved nothing.
> - **Machado's Table 1 is not 33 numbers to recall — it is 33 numbers to pin.** The
>   matrices are generated (`python3 Tools/generate-cvd-matrices.py`) from a vendored
>   copy of colour-science 0.4.7's `CVD_MATRICES_MACHADO2010`, the same table the
>   reference `daltonlens` library uses. Before generating, all 33 were confirmed to
>   agree **exactly** (0.0 diff) with three independent copies: `daltonlens` 0.1.5, the
>   severity-1.0 rows in `opticquiz-cvd` 1.1.0, and the paper's own Table 1 from a
>   screenshot. The generator vendors the dataset rather than installing the 200 MB
>   colour+scipy stack, and re-asserts the identity-at-0.0 and the three published
>   endpoints as guards so a wrong swap fails loudly — the Bradford failure mode, headed
>   off the same way.
> - **The CVD matrices are linear-RGB → linear-RGB, and applying them to gamma-encoded
>   sRGB is the trap.** Confirmed three ways: `daltonlens` runs them in
>   `_simulate_cvd_linear_rgb` (decode sRGB → matrix → re-encode), and both npm
>   implementations linearize first. The difference is not subtle — on `#cc00ff` seen as
>   a protanope the linear pipeline gives `[0, 0.447, 1]` while a gamma-space application
>   lands ~0.26 away — so a discriminating test asserts the linear answer *and* asserts a
>   mismatch with the gamma-space one, exactly the shape of the WCAG-coefficient test.
> - **PLAN said "LMS matrices"; Table 1 is RGB.** Machado derives the transform through
>   LMS cone fundamentals, but tabulates it as a 3×3 that maps linear RGB to linear RGB.
>   The app never touches an LMS space for CVD — colorjs.io exposes none that is the
>   Hunt-Pointer-Estevez basis anyway, which is what made this look hard. Resolving the
>   source resolved the difficulty with it.
> - **Rows of every Table 1 matrix sum to ~1 (to 1e-6), so grays are invariant.** A
>   neutral confuses no cones, and the matrices encode that — a useful free invariant
>   the tests pin, and a quick check that the right numbers loaded.
> - **Contrast is not monotonic in lightness — it is a V — so a solver must not bisect
>   it.** Walking OKLCH lightness upward against a mid-tone background, the ratio *falls*
>   to 1:1 as the color passes through the background's own luminance and rises again
>   beyond it. Every target therefore has **two** crossings, and a bisection on the ratio
>   converges on whichever branch its initial bracket happened to straddle — silently
>   returning the further answer half the time. Measured over 215,000 samples: every one
>   of the 216 multi-crossing cases had a mid-tone background, and none had white or
>   black. Relative *luminance* is monotonic in lightness (the only backwards steps were
>   5e-5 of gamut-mapper jitter), so the solver inverts the target ratio into the two
>   luminances that produce it and bisects each. The inversion is algebraically exact, so
>   keeping the bracket's passing end returns a color that provably satisfies `meets`.
> - **The contrast ceiling has a floor, and it is exactly `√21 ≈ 4.5826`.** Against any
>   background the best available ratio is the better of black and white — `(l+0.05)/0.05`
>   rising, `1.05/(l+0.05)` falling — and they cross where `(l+0.05)² = 0.0525`, at
>   luminance `0.1791`. So **AA body text (4.5:1) is reachable against every background
>   that exists**, by a margin of 0.08, and only AAA's 7:1 can be genuinely impossible.
>   Against a mid-gray `#808080` nothing beats 5.32:1. The worst-case background sits at
>   channel `0.4604`, between the 8-bit grays 117 and 118 — so a sweep over hex colors
>   cannot land on it, and the test constructs it instead. A corollary the UI uses: the
>   band where AA is solvable in *both* directions is the sliver of luminance `0.175`
>   to `0.1833` either side of that crossover.
> - **Harmonies must not be gamut-mapped; ramps must be.** They look like the same
>   decision and are opposite ones. Rotating a vivid hue routinely leaves sRGB — the
>   gamut is nothing like a cylinder, so a chroma that fits at one hue may not fit at
>   another — and pulling the result in hands back a "complement" that is not the
>   complement, so harmonies stay exact and the badge does its job. A ramp is the other
>   case: it is a set built to be *used together*, and a constant-chroma one leaves the
>   gamut at both ends (asserted, so the premise cannot rot), gets clipped on the way to
>   the screen, and clipping shifts hue.
> - **Clamping a ramp stop only when it needs it is not an optimization.** Clamping
>   unconditionally moves the chosen color off itself by up to one search step — so it
>   would no longer come out of its own ramp bit-for-bit — and in an unbounded gamut,
>   where `maxChroma` correctly answers `.infinity`, it would set every chroma to
>   infinity. Both failure modes were confirmed by mutation.

## Context

The goal is a native macOS app that serves as a personal, one-stop color toolkit for daily web development: parse and convert every CSS Color 4 format, check accessibility, transform colors, generate harmonies and ramps, export as CSS, and save collections into projects. Scope is expected to grow over time, so this plan optimizes for a **trustworthy core with a stable API** that features can be layered onto indefinitely, rather than a one-shot build.

The single thing that determines whether this tool is worth relying on is **conversion accuracy**. Most color tools are approximately correct — they use blog-post matrices, ignore the D50/D65 distinction between `lab()` and `oklab()`, and clip out-of-gamut colors instead of gamut-mapping them. The plan therefore front-loads a pure, dependency-free color core validated against reference test vectors before any UI is written.

### Current state

M0–M8 are built. The stock SwiftData template (`Item.swift`, the `NavigationSplitView` list) is gone; what stands now is:

| Layer | Files |
|---|---|
| Core model | [ColorValue.swift](Color%20Toolkit/ColorCore/ColorValue.swift), [ColorSpace.swift](Color%20Toolkit/ColorCore/ColorSpace.swift) |
| Spaces | [Matrices.swift](Color%20Toolkit/ColorCore/Spaces/Matrices.swift) and [NamedColors.swift](Color%20Toolkit/ColorCore/Spaces/NamedColors.swift) (**generated**), [TransferFunctions.swift](Color%20Toolkit/ColorCore/Spaces/TransferFunctions.swift), [ColorMatrix.swift](Color%20Toolkit/ColorCore/Spaces/ColorMatrix.swift) |
| Convert | [Conversion.swift](Color%20Toolkit/ColorCore/Convert/Conversion.swift), [GamutMapping.swift](Color%20Toolkit/ColorCore/Convert/GamutMapping.swift), [GamutBoundary.swift](Color%20Toolkit/ColorCore/Convert/GamutBoundary.swift), [HSV.swift](Color%20Toolkit/ColorCore/Convert/HSV.swift) |
| Parse | [CSSTokenizer.swift](Color%20Toolkit/ColorCore/Parse/CSSTokenizer.swift), [ColorSyntax.swift](Color%20Toolkit/ColorCore/Parse/ColorSyntax.swift), [CSSColorParser.swift](Color%20Toolkit/ColorCore/Parse/CSSColorParser.swift) |
| Format | [CSSFormatter.swift](Color%20Toolkit/ColorCore/Format/CSSFormatter.swift), [FormatCatalog.swift](Color%20Toolkit/ColorCore/Format/FormatCatalog.swift) |
| Shell | [ColorStore.swift](Color%20Toolkit/Features/Shell/ColorStore.swift), [MenuBarPanel.swift](Color%20Toolkit/Features/Shell/MenuBarPanel.swift), [ContentView.swift](Color%20Toolkit/ContentView.swift) |
| Analysis | [WCAGContrast.swift](Color%20Toolkit/ColorCore/Analysis/WCAGContrast.swift), [APCAContrast.swift](Color%20Toolkit/ColorCore/Analysis/APCAContrast.swift), [CVDSimulation.swift](Color%20Toolkit/ColorCore/Analysis/CVDSimulation.swift), [CVDMatrices.swift](Color%20Toolkit/ColorCore/Analysis/CVDMatrices.swift) (**generated**) |
| Transform | [Adjustment.swift](Color%20Toolkit/ColorCore/Transform/Adjustment.swift), [LightnessCurve.swift](Color%20Toolkit/ColorCore/Transform/LightnessCurve.swift), [Harmony.swift](Color%20Toolkit/ColorCore/Transform/Harmony.swift), [ShadeRamp.swift](Color%20Toolkit/ColorCore/Transform/ShadeRamp.swift), [ContrastSolver.swift](Color%20Toolkit/ColorCore/Transform/ContrastSolver.swift) |
| Export | [ExportTemplate.swift](Color%20Toolkit/ColorCore/Export/ExportTemplate.swift), [ColorExport.swift](Color%20Toolkit/ColorCore/Export/ColorExport.swift) |
| Conversion UI | [ColorInputField.swift](Color%20Toolkit/Features/Conversion/ColorInputField.swift), [ConversionPanel.swift](Color%20Toolkit/Features/Conversion/ConversionPanel.swift), [FormatPresentation.swift](Color%20Toolkit/Features/Conversion/FormatPresentation.swift) |
| Contrast UI | [ContrastPanel.swift](Color%20Toolkit/Features/Contrast/ContrastPanel.swift) |
| Picker UI | [PickerState.swift](Color%20Toolkit/Features/Picker/PickerState.swift), [PickerPlane.swift](Color%20Toolkit/Features/Picker/PickerPlane.swift), [PickerPanel.swift](Color%20Toolkit/Features/Picker/PickerPanel.swift) |
| CVD UI | [CVDPanel.swift](Color%20Toolkit/Features/CVD/CVDPanel.swift) |
| Transform UI | [TransformPanel.swift](Color%20Toolkit/Features/Transform/TransformPanel.swift) |
| Export UI | [ExportPanel.swift](Color%20Toolkit/Features/Export/ExportPanel.swift), [ExportPresentation.swift](Color%20Toolkit/Features/Export/ExportPresentation.swift) |
| Design system | [ColorSwatch.swift](Color%20Toolkit/DesignSystem/ColorSwatch.swift), [ColorValue+SwiftUI.swift](Color%20Toolkit/DesignSystem/ColorValue+SwiftUI.swift) |
| Services | [Clipboard.swift](Color%20Toolkit/Services/Clipboard.swift), [ScreenSampler.swift](Color%20Toolkit/Services/ScreenSampler.swift), [GlobalHotKey.swift](Color%20Toolkit/Services/GlobalHotKey.swift) |

There is **no `Persistence/` folder** — M9 will create it. An earlier revision of this
file said one existed and was empty; git does not track empty directories, so it never
survived a clone and the claim was true only on the machine that made it.

Key facts about the project, established during exploration and still current:

| Fact | Value | Why it matters |
|---|---|---|
| `objectVersion` | `77`, with `PBXFileSystemSynchronizedRootGroup` | **New `.swift` files are picked up automatically.** No `project.pbxproj` edits needed — just write files into `Color Toolkit/`, subfolders included. |
| `SDKROOT` / target | `macosx`, deploy `26.5` | macOS-only. Every modern API is available; no availability guards needed. |
| `ENABLE_APP_SANDBOX` | `YES` (no `.entitlements` file yet; Xcode auto-generates) | Constrains the eyedropper and global-hotkey design. |
| `SWIFT_VERSION` | `6.0` (raised in M0) | Strict concurrency throughout. |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | Everything is main-actor unless marked `nonisolated`. See the ColorCore note above. |
| `NSColorSampler` | Present in SDK, `sample()` async | Confirmed available. Runs **out-of-process**, so the eyedropper needs **no Screen Recording permission**. |

### Decisions confirmed with the user

1. **Contrast tools** — build *both*, as separate controls: a paired-color solver (with auto-fix to a target ratio) and a standalone S-curve around mid-gray.
2. **App shape** — `MenuBarExtra` + main window, with a global hotkey for instant screen-sampling.
3. **Persistence** — SwiftData library (keeps the bootstrapped stack) plus JSON / CSS / Tailwind export.
4. **Accessibility** — WCAG 2.2 **and** APCA **and** color-vision-deficiency simulation.

---

## Architecture

Four layers, strictly one-directional. **`ColorCore` imports nothing but `Foundation`** — no SwiftUI, no AppKit, no SwiftData. That constraint is what keeps it exhaustively testable and reusable (a future CLI or Raycast extension can link it unchanged).

```
Color Toolkit/
├── ColorCore/                    ← pure value types, Sendable, zero UI deps
│   ├── ColorValue.swift          canonical model
│   ├── ColorSpace.swift          space enum + component metadata
│   ├── Spaces/                   matrices, transfer functions, white points
│   ├── Convert/                  conversion hub + gamut mapping
│   ├── Parse/                    CSS tokenizer + parser
│   ├── Format/                   CSS serializer + format catalog
│   ├── Analysis/                 WCAG, APCA, CVD, deltaE
│   └── Transform/                lightness/sat/hue, harmonies, ramps
├── Services/                     eyedropper, global hotkey, clipboard
├── Persistence/                  SwiftData @Models + Codable bridge
├── Features/                     one folder per feature area (SwiftUI)
└── DesignSystem/                 shared swatch/slider components
```

The boundary runs in one direction only: **ColorCore knows facts, the UI layer owns editorial copy.** `CSSOutputFormat.catalog` lives in core; the section names ("Web", "Perceptual") and the per-format labels live in `Features/`. A core test that reaches into the UI for a display string is the smell that the layering has slipped — and in M3 it also broke a commit's ability to build standalone.

### The core model

Storing everything as RGB is the mistake to avoid — `oklch(70% 0.4 30)` is outside sRGB, and normalizing to RGB on input destroys it permanently. `ColorValue` therefore **retains the color in its authored space**:

```swift
struct ColorValue: Hashable, Sendable, Codable {
    var space: ColorSpace
    var components: SIMD3<Double>
    var alpha: Double
    var missing: ComponentMask   // CSS `none` — carried, not fully parsed in v1
}
```

### The conversion hub

Rather than N² conversions, everything pivots through a connection space: **XYZ D65**. Each space implements `toXYZD65` / `fromXYZD65`, so adding a space later is one file and one enum case.

Two refinements matter for correctness:

- **Intra-family conversions stay direct.** `rgb`/`hsl`/`hwb`/named are alternate parameterizations of the *same* sRGB values; `lab`↔`lch` and `oklab`↔`oklch` are rectangular↔polar of the same space. Routing these through XYZ would add float error and destroy hue on achromatic colors. Convert them directly.
- **The D50/D65 split is the #1 accuracy trap.** CSS `lab()`/`lch()` are **D50**-referenced; `oklab()`/`oklch()` are **D65**. Converting sRGB → `lab()` requires sRGB → linear → XYZ D65 → **Bradford adaptation to D50** → Lab. Getting this wrong yields values that look plausible but are visibly off, and it is why many web tools disagree with browsers.

### Sourcing the matrices — do not derive or recall these

Matrices are **generated** by [generate-constants.mjs](Tools/generate-constants.mjs) from a pinned colorjs.io, never transcribed by hand. The original guidance below still explains *why*, and remains the rule for anything the generator does not cover:

| Matrix | Source |
|---|---|
| linear-sRGB ↔ XYZ D65 | CSS Color 4 §17 sample code / `spaces/srgb-linear.js` |
| Bradford D65 ↔ D50 | CSS Color 4 §17 / `adapt.js` |
| XYZ D65 ↔ LMS, LMS ↔ OKLab | `spaces/oklab.js` |
| Display P3, A98, ProPhoto, Rec2020 | corresponding `spaces/*.js` |

**Do not copy the OKLab matrices from Ottosson's original blog post** — CSS Color 4 and colorjs.io use values computed at higher precision. Mixing sources produces small deltas against the reference tests and sends you chasing phantom bugs.

### Gamut mapping is a first-class core function

`oklch()` and `lab()` colors land outside sRGB constantly, so how they're mapped is user-visible and must not be an afterthought. Implement **CSS Color 4 §13**: binary-search OKLCH chroma downward, comparing each candidate against its clipped version with `deltaEOK`, stopping at JND `0.02`. The UI should always show *both* the mapped value and an "out of sRGB gamut" badge rather than silently clipping.

---

## Milestones

Sequenced so the app becomes genuinely useful at M4, then grows. Each milestone is independently shippable.

### ✅ M0 — Project hygiene

- Delete `Item.swift`; strip the template body from [ContentView.swift](Color%20Toolkit/ContentView.swift) and the `Item` schema from [Color_ToolkitApp.swift](Color%20Toolkit/Color_ToolkitApp.swift).
- Raise `SWIFT_VERSION` to `6.0`. Do this **now**, while the codebase is tiny, and migrating later is far more expensive. Strict concurrency is genuinely free across the value-type core; the one place it costs real work is the Carbon hot-key bridge in M4 — expect it there and nowhere else.
- Create the folder skeleton above.
- Add a `.gitignore` and `git init` (the directory is not yet a repo).

### ✅ M1 — ColorCore: model + conversions ⭐ *the foundation*

- `ColorValue`, `ColorSpace`, per-space metadata (component ranges, units, whether hue is present).
- All spaces: sRGB, linear sRGB, HSL, HWB, Lab/LCH (D50), OKLab/OKLCH (D65), Display P3, A98 RGB, ProPhoto RGB, Rec2020, XYZ D50/D65 — plus the full CSS named-color table (~148 entries incl. `rebeccapurple`) and `transparent`.
- Conversion hub, Bradford adaptation, `deltaEOK`, CSS Color 4 §13 gamut mapping.

**Validation gate — this is what makes the tool trustworthy.** Write a small Node script using `colorjs.io` that emits a JSON fixture of a few thousand conversions across a grid of colors and every space pair. Check the fixture into the repo and drive **parameterized Swift Testing** tests from it. Nothing proceeds to UI until conversions match the reference within tolerance and round-trips are stable.

Two things to get right in the fixture, or you will chase phantom bugs:

- **Pin the colorjs.io version** in the generator script, and check the version into the repo alongside the fixture.
- **Match the gamut-mapping *method*, and use two tolerances.** colorjs.io's `toGamut()` default has changed across versions and is not always the CSS Color 4 §13 algorithm being implemented here. Generate the fixture explicitly using its CSS-algorithm gamut method, and split tolerances: **tight** for ordinary in-gamut conversions, **looser and method-matched** for gamut-mapped ones. A mismatch here produces disagreements that look exactly like bugs but aren't — the same trap as mixing matrix sources.

### ✅ M2 — Parser + serializer

Hand-written recursive-descent tokenizer, no dependencies. Must handle:

- Hex `#rgb` / `#rgba` / `#rrggbb` / `#rrggbbaa`
- Legacy comma syntax (`rgb(255, 0, 0)`, `rgba(...)`, `hsl(120, 50%, 50%)`) **and** modern space syntax with `/` alpha (`rgb(255 0 0 / 50%)`)
- Percentage-vs-number forms per component, per space
- Hue units: bare, `deg`, `rad`, `grad`, `turn`
- `color(display-p3 1 0 0 / 50%)` and all predefined spaces
- Named colors, case-insensitive

Serializer needs configurable precision and legacy-vs-modern output. **Deferred:** `calc()`, and relative color syntax (`rgb(from …)`) — a strong later addition. `none` is carried in the model but not fully parsed in v1.

Round-trip tests: parse → serialize → parse must be idempotent.

### ✅ M3 — App shell

`MenuBarExtra` + main window. Text input that live-parses any supported format, and a conversion panel rendering the color in **all** formats simultaneously with per-format copy buttons and out-of-gamut badges. Menu bar shows recent colors and a "copy as ▸" submenu.

*Done and visually reviewed at every precision level.*

### ✅ M4 — Eyedropper + global hotkey

- **Eyedropper:** [ScreenSampler](Color%20Toolkit/Services/ScreenSampler.swift) wraps `NSColorSampler`. Colors are read in **linear extended sRGB**, never `.sRGB` — see the finding above; the bridge is pure and `nonisolated` so it can be tested without the loupe.
- **Global hotkey:** [GlobalHotKey](Color%20Toolkit/Services/GlobalHotKey.swift) — Carbon `RegisterEventHotKey`, ⌃⌥⌘C. Three modifiers deliberately: ⇧⌘C and ⌥⌘C are already claimed (Digital Color Meter, Finder's "Copy as Pathname"), and a global hot key *wins* over the frontmost app's, so a collision silently breaks something the user relies on.
- **The two entry points do different things.** The in-app button fills the field and leaves the clipboard alone. The hot key also **copies**, because its whole point is capturing a color while another app is frontmost — filling an invisible text field would accomplish nothing. The menu bar icon flashes a checkmark, which is the only feedback a global capture can get without a notification permission.
- The shortcut is claimed from whichever scene appears first (`activateGlobalShortcut` is idempotent). Neither scene is guaranteed: the window can be closed, the menu bar item can be hidden.

*Done, and confirmed on the running app.* The app is sandboxed (`com.apple.security.app-sandbox`) with **no** screen-recording entitlement, and the loupe works anyway with no permission prompt — confirming `NSColorSampler` runs out of process rather than capturing the screen itself. Carbon hot keys likewise prompt for nothing.

### ✅ M5 — Accessibility (contrast)

- **WCAG 2.2** — [WCAGContrast.swift](Color%20Toolkit/ColorCore/Analysis/WCAGContrast.swift). Spec-literal `0.03928`, AA/AAA × normal/large, plus 1.4.11's 3:1 non-text threshold.
- **APCA** — [APCAContrast.swift](Color%20Toolkit/ColorCore/Analysis/APCAContrast.swift). Transcribed from colorjs.io 0.7.0's implementation of **0.0.98G**, matching to 1e-9 across 108 pairs in both polarities.
- **UI** — [ContrastPanel.swift](Color%20Toolkit/Features/Contrast/ContrastPanel.swift), reached by the tool switcher (which sat in the toolbar until M8 moved it into the window body — see that milestone). The store now holds a *pair* of colors via `ColorField`, so the background gets the foreground's editing behavior rather than a second implementation of it.

**No APCA pass/fail badges.** Its readability levels (Lc 90/75/60/45/30) could not be verified against a pinned source the way the algorithm was, and a threshold this app cannot stand behind has no business wearing a checkmark next to WCAG's, which it can. The panel shows the signed `Lc` and its polarity, nothing more.

Two things came out of reviewing the screenshots. Nothing in this panel is dimmer than `.secondary` — `.tertiary` explanatory text is dim enough to fail the very check running inches above it, and a contrast tool that ships low-contrast text has undermined its own advice. And APCA's polarity is described comparatively ("lighter text on a darker background") rather than absolutely, because calling `#3b82f6` a dark background out loud reads as a bug even though the sign is right.

### ✅ M5b — Accessibility (CVD simulation)

Machado et al. (2009) severity-parameterized simulation matrices for protan / deutan /
tritan, as a live preview filter over any swatch or palette: the current color shown
original-vs-simulated, all three deficiencies at the chosen severity side by side, the
foreground/background pair as a CVD viewer sees it (the other half of the contrast
question), and the recents strip filtered. Deficiency and severity live on `ColorStore`
so they outlast the panel, exactly like `pickerMode`.

- **[CVDMatrices.swift](Color%20Toolkit/ColorCore/Analysis/CVDMatrices.swift)** —
  **generated** (`python3 Tools/generate-cvd-matrices.py`) from a vendored, pinned copy
  of Machado's Table 1; never hand-edited, same rule as `Matrices.swift`. The generator
  is Python because the oracle that carries the table (colour-science, and `daltonlens`
  after it) is Python; it needs only the standard library.
- **[CVDSimulation.swift](Color%20Toolkit/ColorCore/Analysis/CVDSimulation.swift)** —
  `ColorValue.simulating(_:severity:)`. Gamut-maps into sRGB, decodes to **linear**
  light, applies the severity-interpolated matrix, clamps, re-encodes. Exact 0.1 steps
  are Table 1 verbatim; between them the two nearest matrices are blended, matching the
  reference libraries.
- **The block was always provenance, and it is now pinned** — see the two findings
  above on the source and the linear-RGB trap. It turned out to be a short milestone
  once the numbers were trustworthy, exactly as predicted.

**What is deliberately absent: no pass/fail verdict.** Like the APCA panel, this shows
rather than judges — there is no threshold for "distinguishable enough", and inventing
one would be the same overreach the contrast panel refuses. Tritanomaly additionally
carries an honest caveat in its blurb, because the paper's authors flag it as an
approximation via the shift paradigm rather than a fit to data.

### ✅ M6 — Full-spectrum picker

Canvas-rendered, with **two modes**: a familiar HSV square + hue strip, and an **OKLCH
mode** (L/C/h) that draws the sRGB gamut boundary so it's visible when chroma is being
clipped. Alpha slider over a checkerboard. The display's own edge is drawn dashed
beside sRGB's — nested, and verified nested: 20,000 random sRGB colors all fall inside
Display P3 while 9,626 of 20,000 P3 colors fall outside sRGB.

- **[GamutBoundary.swift](Color%20Toolkit/ColorCore/Convert/GamutBoundary.swift)** —
  `maxChroma(lightness:hue:in:)` and the sampled curve, in ColorCore because it is a
  numeric fact. Bisects the same `inGamut` predicate the badge uses, so the drawn line
  and the badge are one claim. See the blue counterexample and the tolerance note above
  — both are pinned by tests precisely so they are not "fixed".
- **HSV is deliberately not a `ColorSpace` case.** CSS has no `hsv()`, so a case would
  need excluding by hand from the parser, serializer, catalog and every `allCases` loop,
  and the first one missed would offer a format no browser accepts. It is a coordinate
  on the side ([HSV.swift](Color%20Toolkit/ColorCore/Convert/HSV.swift)) wrapping the
  sRGB↔HSV conversions that already existed to route HWB.
- **[PickerState.swift](Color%20Toolkit/Features/Picker/PickerState.swift)** holds the
  axes as a plain value type, testable without SwiftUI — which is what let the write
  loop, the hue-preservation rule and the format choice all be asserted directly.
- **Each mode writes in a format that can hold what it produced**: `oklch()` at
  `.lossless` for OKLCH, hex for HSV. Mutating the format to hex fails seven
  assertions, including two chroma values `1e-4` apart collapsing to the same
  `#3b82f6`.
- **Switching modes does not write.** Looking at a color in other axes is not editing
  it; rewriting `#3b82f6` as `oklch(…)` for having glanced at the other tab would be
  presumptuous. It does *carry* the field's color across, which is what stops HSV from
  narrowing a wide color merely by having been the tab the panel opened on.

**Recents are filed on a debounce, not on release.** Plane, strip and alpha are three
controls that dialing in one color touches in turn, so remembering on each gesture end
deposits three different way-points — the same noise the store already avoids by not
remembering on every keystroke. A second of stillness is the signal that a color was
chosen rather than passed through.

**The mode outlives the panel** (it lives on `ColorStore`), because re-entering the
tool tears the panel's state down. The axes *should* be rebuilt from the field, which
may have moved; the choice of which axes to use should not be.

**No numeric entry fields.** The shared input field above already accepts any CSS
color, so L/C/h boxes would be a second way to type the same thing. The readout is
read-only and earns its place differently: HSV has no CSS spelling anywhere else in the
app, and the sRGB chroma still available at this lightness and hue is the panel's
actual payload — it turns "this looks vivid" into "this is 0.19 of a possible 0.21".
It is also the only assertable surface a `Canvas` can offer a UI test.

*Done, and reviewed on the running app from its own screenshots.*

### ✅ M7 — Transform + harmony tools

All computed in **OKLCH** for perceptual evenness. One panel rather than five entries in
the tool switcher, four sections, and the pattern the plan predicted: *view → operates on
a `ColorValue` → emits a `ColorValue` or `[ColorValue]`.* Every emitted swatch is a button
that adopts it, so the sections compose — adopt a triad's red and its own triad contains
the original blue.

The export sheet is deferred to M8 as planned; until then the output is adopt-into-the-
field plus the Convert panel's existing copy rows, which is the same destination reached
one click later.

- **[Adjustment.swift](Color%20Toolkit/ColorCore/Transform/Adjustment.swift)** —
  `OKLCHComponents` (the coordinate every transform works in, mirroring `HSVComponents`)
  and `OKLCHAdjustment`. **Relative, not absolute**, which is what stops it being the M6
  picker twice: the picker already sets L, C and h outright, and what it cannot do is
  *transform* — a little lighter, a little less saturated, thirty degrees round. Each
  axis gets the operator it deserves, and they are not interchangeable: lightness **adds**
  (it is perceptually uniform on a fixed `0…1` scale), chroma **multiplies** (no upper
  bound, and its useful range depends on both lightness and hue, so `+0.05` would be
  noise on a vivid color and a doubling on a muted one), hue **adds and wraps** (it is an
  angle).
- **Results stay in OKLCH rather than returning to the input's space.** A round trip back
  to `#3b82f6` would quantize onto the 8-bit grid — a nudge finer than 1/255 would return
  the color you started with — and half of these transforms leave sRGB anyway, where a
  bounded format has no honest spelling. The picker learned the same lesson in M6, and
  the panel writes at `.lossless` for the same reason the eyedropper does.
- **[LightnessCurve.swift](Color%20Toolkit/ColorCore/Transform/LightnessCurve.swift)** —
  the S-curve: contrast with no second color in it. The pivot is **fixed at `L = 0.5`**
  rather than configurable, and that is what buys the good behavior: exact symmetry,
  fixed points at black/mid-gray/white, and an exact inverse. Opposite strengths cancel
  to 1e-12 because the strength maps *exponentially* onto the exponent (`3^s`), so `+0.5`
  and `−0.5` are reciprocal gammas; a linear mapping would fail to cancel. Its real use
  is on a **set** — it widens a ramp's ends while holding its order and its midpoint,
  which a lightness offset cannot do, because an offset slides a ramp where a curve
  stretches it.
- **[Harmony.swift](Color%20Toolkit/ColorCore/Transform/Harmony.swift)** — the six, at
  the classic angles but turned on OKLCH's wheel. That choice is the whole point:
  rotate 180° in HSL and a saturated blue's "complement" comes back a dim mustard,
  because HSL's hue is a raw RGB angle in which equal degrees are wildly unequal steps.
  Monochromatic is the odd one out — one hue, many lightnesses — so it delegates to
  `ShadeRamp` rather than reimplementing a lightness family worse.
- **A gray has no relatives, and the arithmetic says so.** Every hue harmony of
  `#808080` returns the same gray repeated, which is correct — there is no third color
  related to a neutral by 120° — so the panel says it in words rather than showing five
  identical swatches with no explanation.
- **[ShadeRamp.swift](Color%20Toolkit/ColorCore/Transform/ShadeRamp.swift)** — the two
  rules do different jobs and both are needed. Tapering chroma toward the ends is the
  *aesthetic* rule (light stops read as tints rather than as the same ink at a higher
  lightness); holding every stop at or inside the `GamutBoundary` edge is the
  *correctness* rule. Because the edge comes from the same predicate the badge uses,
  every stop is in gamut **by construction** rather than by a mapping applied afterwards.
- **[ContrastSolver.swift](Color%20Toolkit/ColorCore/Transform/ContrastSolver.swift)** —
  both halves the plan asked for, sharing one set of machinery. The **auto-fix** is "the
  nearest color hitting 4.5:1"; the **manual push** is a slider that moves the color and
  reports the ratio live. Both move **lightness alone**: hue and chroma are what make a
  color that color, and a solver free to move them turns "nearest" into a
  two-dimensional search with no obvious metric. See the two findings above — the V-shape
  that rules out bisecting the ratio, and the `√21` floor that decides when to say
  "impossible" instead of searching.
- **"Push apart" has to decide its own sign**, or it means opposite things in the two
  polarities. `awayFromBackground(for:on:)` reads the direction off the pair — a color
  already lighter than its background gets more legible by getting lighter still — so
  dragging right raises the ratio whether the text is dark on light or light on dark. On
  an exact luminance tie there is no side, and the direction with more headroom wins.
  Those headrooms are wildly asymmetric away from mid-luminance and are their own
  question: against `#1a1a2e`, going lighter reaches 16:1 while going darker manages
  1.3:1, hence a per-direction `ceiling(against:going:)` alongside the overall one.
- **The S-curve is a slider in the Adjust section rather than a fifth tool.** The plan
  framed it as one of "two separate contrast tools", which was right about the *maths* —
  it takes no second color — and wrong about the *furniture*: as its own panel it would
  be one slider on an empty page, and it composes with the other three adjustments, which
  is where its value actually shows. The separation the plan cared about is preserved
  where it matters: it is its own type, with no reference to a background anywhere.

**Testing has no oracle here, and that is an advantage.** colorjs.io converts and maps
but has no notion of a harmony, a ramp or a solver, so — exactly as with
`GamutBoundary` — the tests assert the *properties* the results must have rather than
recorded output: a hue exactly 180° away, a chroma preserved to the last bit, every ramp
stop in gamut, and, for the solver, that the answer passes `meets` **and** that stepping
back toward the original fails. Every load-bearing claim was confirmed by mutation:
removing the ramp's clamp fails three tests, dropping its exact fast path fails two,
gamut-mapping harmonies fails four, and keeping the solver's failing bracket end fails
five.

*Done, and reviewed on the running app from its own screenshots — see the status note
above for the colorjs.io cross-check of an adopted triad member.*

### ✅ M8 — Export

Template-driven, as planned: `color`, `background-color`, `border`, `outline`,
`box-shadow`, `text-shadow`, `fill`/`stroke`, plus custom-property blocks, JSON and
Tailwind — applied to a single color or to a whole palette, with a format picker and a
precision control.

**The plan's one word for two different things was "template".** Splitting them is the
decision the rest of the milestone hangs off. A *template* is per color — how one value
is spelled inside a declaration. A *shape* is per document — what wraps the set. They
look like one control and are not: `background-color:` repeated eleven times is not a
stylesheet, and a `:root` block holding a single `border` shorthand is not a custom
property. So `ExportTemplate` has the eight declarations and `ExportShape` has the five
documents, and exactly one shape consumes a template. The panel hides the control that
does not apply rather than leaving it there doing nothing — `usesTemplate` and `usesName`
are complements, and a test pins that.

Decisions worth recording:

- **"A whole palette" means the sets the app already has**: the harmony, the ramp, and
  recents. There is no `Palette` type, deliberately — that is M9's, and inventing one
  here to have something to point at would be building the next milestone early and
  worse.
- **Keys are a correctness problem, not a naming one.** A palette entry's key becomes a
  CSS identifier *and* a JavaScript object key, and the two have different rules:
  Tailwind writes shade keys bare because `50:` is a legal numeric key, but a bare
  `triad-2:` parses as a subtraction and the config fails to load. Keys must also be
  unique, since two entries sharing one silently collapse into a single property and a
  color disappears with nothing to show for it.
- **Tailwind's scale was checked, not recalled.** Eleven keys, `50` through `950`; the
  `950` step is a later addition than the rest, so a list ending at `900` looks right and
  is a version out of date. That `ShadeRamp` defaults to eleven stops is not a
  coincidence — its `lightest` was chosen to sit where Tailwind's `50` does — but it is
  not a guarantee either, so `PaletteNaming.rampKeys(count:)` falls back to indices.
  `Harmony.monochromatic` asks for five, so that path is live, not hypothetical.
- **Both Tailwind versions ship.** v4 configures colors in CSS (`@theme`, with the
  load-bearing `--color-` namespace prefix — `--brand-500` generates no utility at all)
  and v3 in JavaScript. Which you want is decided by your project's major version and by
  nothing else, so picking one and being wrong for half of them is not a simplification.
- **`.keyword` is excluded from the format picker structurally**, not by a fallback. It
  names 148 colors, so a palette of eleven shades would come back with two spelled as
  keywords and nine as something else, and nothing in the file would say a substitution
  happened. That is fine in the conversion panel, where a format that cannot name the
  color simply has no row. Every remaining format is *total*, which is what makes
  `cssStringOrHex`'s fallback unreachable rather than merely unused.
- **JSON is hand-shaped.** `ColorValue` is `Codable`, so `JSONEncoder` is one line away —
  and it would emit a `space` string, a `components` array and a `missing` bitmask. That
  is a serialization of the program, not of the color, and it is the same reasoning that
  made M9 reject an opaque blob. What a consumer wants is the CSS string they would have
  pasted.
- **Precision is one setting shown twice**, not two settings. The toolbar's output menu
  already owns `formatOptions`, and the panel writes through to the same property — so
  raising precision in either place moves the export. Two knobs where one silently wins
  was the alternative.

**The tool switcher moved out of the toolbar**, which was not planned and was not
optional. A sixth segment made macOS sweep the entire switcher into a *"more toolbar
items"* overflow menu — taking every tool with it, not just Export — at a window 745pt
wide, well above the 520pt minimum. `ToolbarItem(placement: .principal)` is *centered*,
so its width budget is not the toolbar's spare room but `width − 2 × max(leading,
trailing)`, and the window title alone spends that twice over. Raising the minimum would
only defer it, since M9 adds a seventh tool. In the window body it also makes the
hierarchy `ContentView` already described in its comment literal rather than implied:
field, then switcher, then panel. Every existing UI test kept passing unchanged, because
they query `radioButtons` by label and never cared where it lived.

**A measured characteristic, not a defect:** a ramp stop sitting exactly on the gamut
boundary can round *outward* at display precision. `--brand-50` for `#3b82f6` prints
`oklch(0.97 0.0142 259.81)`, and the true boundary at that lightness and hue is
`0.014177` — so the printed value is 2.3e-5 of chroma past it and colorjs.io calls the
string out of gamut, while the `ColorValue` it came from is inside. Swept across hues at
four decimals the worst excursion is **1.7e-3 of a channel, 0.43 of an 8-bit step**, so a
browser clamping it lands on the same pixel or one adjacent. It is not worth engineering
around: biasing export rounding inward would make the clipboard disagree with the
preview, which is a worse property than the one it fixes, and `Fine` or `Maximum`
precision removes it entirely.

**Testing has an oracle here for the first time since M5 — this app's own parser.**
`Transform/` had none, because colorjs.io has no notion of a harmony or a ramp. An
exported declaration is different: it is CSS, and CSS is what `CSSColorParser` reads. So
the discriminating test pulls the value back out of the document, parses it, and requires
the color that comes back to be the color that went in, for every exportable format. The
syntax assertions are exact strings, which is the right standard here and the wrong one
in `HarmonyPresentation` — a `:root` block either has its braces or is not one.

Three mutations confirm the tests bite: a shape ignoring its `formatting` argument,
unquoted JavaScript keys, and a ramp claiming Tailwind's scale at every stop count. **The
first initially passed**, and that is the useful part — the plumbing test rendered only a
single entry, while `json` and `tailwindConfig` fork on cardinality, so the broken
multi-entry branch was never reached. It now asserts at both.

**One defect survived into a commit and was caught in review**: the Name field prompted
`brand` while an emptied field exported `--color`. The placeholder was a literal in the
panel and the fallback came from `cssIdentifier`'s own default, so nothing tied them
together and clearing the field produced a property the user had never been shown.
`ExportOptions.defaultName` is now the starting value, the fallback *and* the
placeholder, and `json` reaches it through `identifier` like every other shape rather
than calling `cssIdentifier` itself — which is how CSS and JSON could have disagreed
about the same emptied name. The regression test fails three ways against the old code.
The general lesson is the one this file keeps relearning: a constant duplicated across a
layer boundary is a claim nothing checks.

*Done, and reviewed on the running app from its own screenshots — see the status note
above for the colorjs.io cross-check of an exported ramp stop.*

### M8b — Deferred from export

Saving to a file rather than the clipboard. It needs a sandbox entitlement plus an
`NSSavePanel` wrapper in `Services/`, and clipboard-only is the coherent scope for a
panel whose output is meant to be pasted into a stylesheet you already have open. Worth
revisiting alongside M9, where a saved project is a file anyway.

### M9 — Projects (SwiftData)

Keep `ColorCore` free of SwiftData; persist an explicit, queryable representation rather than an opaque blob:

```swift
@Model final class Project   { name, colors, palettes, createdAt, modifiedAt }
@Model final class SavedColor { name, spaceID: String, c0/c1/c2: Double, alpha: Double, notes }
@Model final class Palette    { name, kind: String, entries: [SavedColor] }
```

Storing the space ID + raw components (instead of a serialized CSS string or `Data`) keeps values lossless *and* inspectable/queryable. A small `Codable` bridge maps to/from `ColorValue`.

---

## Verification

**A feature reached through a system loupe or a global chord has links no test can touch**, and they fail independently — so check them separately rather than as one gesture. For M4 that was: (1) does the menu bar show the chord, proving the OS accepted the registration and a scene's `.task` fired; (2) does the chord raise the loupe from *another* app, proving the key is captured and the C callback reaches the main actor; (3) does the picked color reach the field and the clipboard, proving the sandbox and the bridge. All three passed. Everything either side of them is covered by [ScreenSamplerTests](Color%20ToolkitTests/ScreenSamplerTests.swift) and [GlobalHotKeyTests](Color%20ToolkitTests/GlobalHotKeyTests.swift).

Per milestone:

- **M1/M2 (core):** `xcodebuild test` — parameterized tests against the colorjs.io fixture; round-trip idempotency; gamut-mapping boundary cases (`L≥1` → white, `L≤0` → black, in-gamut colors unchanged).
- **M5:** two different standards of proof, because the oracle only covers one of them. **APCA** is validated against colorjs.io directly (`node Tools/generate-contrast-fixtures.mjs`) at 1e-9, both polarities — real external validation, since the Swift is transcribed from that package. **WCAG** cannot be, because colorjs.io implements a different definition; correctness there comes from anchors that hold under any variant (`#000` on `#fff` = 21:1, a color against itself = 1:1) plus one pair chosen to *disagree* between the definitions, asserted both ways round.
- **M6:** the plane is a `Canvas`, so nothing about the pixels reaches the accessibility tree — the numeric readout is the assertable surface, and the boundary figures it prints were checked against the oracle from the panel's own screenshots. See [PickerSmokeTests](Color%20ToolkitUITests/PickerSmokeTests.swift).
- **M7:** the transforms have no oracle, so ColorCore asserts their defining properties and every load-bearing one was confirmed by mutation (see the milestone above). What *can* be cross-checked is the pipeline end to end, and was: the OKLCH string the panel wrote after adopting a triad member agrees with colorjs.io to ten decimals. See [TransformSmokeTests](Color%20ToolkitUITests/TransformSmokeTests.swift), where each derived swatch is a button labelled with its own CSS — the only handle a test has on a row of colored rectangles, and the thing a bare swatch owes VoiceOver anyway.
- **M8:** the only milestone whose output is *text a machine will read*, so the parser is the oracle — [ExportTests](Color%20ToolkitTests/ExportTests.swift) round-trips every exportable format back through `CSSColorParser` and requires the color to survive. Syntax is pinned with exact strings, and the identifier rules (JavaScript key quoting, CSS sanitizing) have their own parameterized cases, because a config that will not load is the failure mode and it is invisible from inside Swift. The source-to-entries mapping is asserted on `ColorStore` rather than through the UI — see [ExportStoreTests](Color%20ToolkitTests/ExportStoreTests.swift) — which is why that mapping lives on the store. [ExportSmokeTests](Color%20ToolkitUITests/ExportSmokeTests.swift) covers only what a running app can show: that the controls reach the document. It never clicks Copy, for the reason no test here touches the pasteboard.
- **M3/M4/M9 (UI):** run the app and verify interactively. Spot-check conversions against a browser's DevTools color picker, which implements the same spec — a fast, honest end-to-end sanity check.

The scheme is shared and works from the command line:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' test
```

`xcodebuild` does **not** print Swift Testing failure text — a failed run tells you which test failed and nothing about why. Capture a result bundle and read the `Failure Message` nodes out of it:

```bash
xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -resultBundlePath /tmp/res.xcresult test
```

```bash
xcrun xcresulttool get test-results tests --path /tmp/res.xcresult --compact
```

Before asserting any gamut-containment claim, ask the reference rather than reasoning about which space is "wider":

```bash
cd Tools && node -e "import('colorjs.io').then(({default:C}) => console.log(new C('oklch(0.9 0.3 140)').inGamut('rec2020')))"
```

### Running the app

The app owns a `MenuBarExtra`, so **every running instance puts an icon in the menu
bar** — including one left behind by Xcode or by a UI test that did not terminate
cleanly. The symptom is a second, identical menu bar icon that does not respond to
clicks and survives quitting the app, because the app you quit was not the one that
owns it. There is no ghost to clear; there is a process to find:

```bash
ps -Ao pid,lstart,command | grep "Color Toolkit.app" | grep -v grep
```

Kill the stale pid and the icon goes with it. The UI tests in
[Color ToolkitUITests](Color%20ToolkitUITests/ConversionSmokeTests.swift) call
`app.terminate()` in `tearDown` specifically so they cannot be the cause.

**If `kill -9` does not work**, the instance is held by a debugger — a leftover test
host still attached to `debugserver`. `ps` shows it as state `SX`, where `X` means
traced. Seen once during M4: a UI test failed at `app.launch()` with *"Failed to
terminate me.parkersprouse.color-toolkit"*, and `sample` on the stuck process showed
its main thread frozen mid-`_AXXMIGAddNotification`. That stack is a red herring — a
traced process shows identical frames in every sample because it is not running at
all. Find the debugger and kill that first:

```bash
ps -Ao pid,ppid,stat,command | grep -E "debugserver|Color Toolkit.app" | grep -v grep
```

The run was clean on retry, so this is a flake in the unit-test-host → UI-test
handoff rather than anything in the app. Re-run before investigating.

**One cause of these is now established, and it is self-inflicted: two `xcodebuild test`
runs at once.** Found during M8. The symptoms are *"The test runner hung before
establishing connection"* and *"Lost connection to the application"* mid-test, and they
were reproduced twice by starting a second suite while the first was still alive — both
runs share the same DerivedData and the same test host and fight over them. Worse, the
loser leaves orphaned `UITests-Runner` and `Color Toolkit.app` processes reparented to
`init`, which then poison the *next* run too. So before blaming the host:

```bash
ps -Ao pid,ppid,command | grep -E "xcodebuild|UITests-Runner|Color Toolkit.app/Contents" | grep -v grep
```

Anything with `ppid 1` is an orphan. Kill it, and any second `xcodebuild`, then re-run.

**Two more ways to read a false pass**, both hit in the same session:

- **Never delete the worktree or its `-derivedDataPath` while the run is still alive.**
  Doing so removed `Color Toolkit.app` out from under the UI phase, and three tests
  failed with *"Could not launch … no such file"* — a failure that looks like a
  regression and is nothing but housekeeping. Confirm the process has exited first.
- **`Test run with N tests in M suites passed` is the Swift Testing line, not the
  verdict.** It prints minutes before the UI phase finishes. The only authoritative
  markers are `** TEST SUCCEEDED **` and `** TEST FAILED **`, and there should be exactly
  one; grep for those rather than for the word "passed". Note also that `Executed N
  tests` counts *XCTest* only and reads `0` on a Swift-Testing-only run, which is why
  the counts in the status note above are given per framework.

### Commit discipline

Commits follow milestone seams, and **each one must build and test on its own** — a green suite at HEAD says nothing about whether an intermediate commit is bisectable. Verify in a throwaway worktree with isolated DerivedData before stacking the next commit on top:

```bash
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt && xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -derivedDataPath /tmp/dd test
```

## Deferred (worth revisiting)

Relative color syntax (`rgb(from …)`), `calc()` in parsing, full `none`/powerless-component semantics, color interpolation & mixing (`color-mix()`), CSS `@media (color-gamut)` awareness, Raycast/Alfred or CLI front-end reusing `ColorCore`, palette import from Figma/Tailwind configs.

*Note for later:* the APCA algorithm has carried usage/attribution terms. Irrelevant for personal use, but worth checking before ever distributing the app publicly.
