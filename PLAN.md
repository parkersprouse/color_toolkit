# Color Toolkit — Implementation Plan

> **Status (2026-08-05): M0–M15 and M5b (CVD) complete.** M0–M14 have the full suite
> green — **340 Swift Testing functions across 41 suites plus 27 XCUITests**, both read
> off a run rather than counted by hand. ColorCore is validated against **colorjs.io
> 0.7.0** (pinned exact) — 6,384 conversions, 1,368 gamut mappings, 108 contrast pairs and
> now **1,760 mix vectors** — plus independent definitional anchors, and **405 CVD
> vectors** over Machado's Table 1.
>
> **M15 is the exception to that sentence and should not be read as if it were not.** It
> was written in a Linux container with no Swift toolchain and no Xcode, so **it has never
> been compiled and its tests have never been run** — the counts above are M14's. What
> *was* checked is the arithmetic: the interpolation algorithm was ported line-for-line
> back into JavaScript and run against all 1,760 recorded vectors, where it agrees exactly
> (`Tools/generate-mix-fixtures.mjs` records the oracle's two traps). That validates the
> algorithm and says nothing about whether the Swift compiles. First job on a Mac is
> `xcodebuild … test`, then `swiftformat .` as its own commit — neither could run here.
>
> M0–M9 were each reviewed on the running app. **Three later things were not, and should
> not be read as if they were:** M10 changed no behavior and has no UI to look at, M11's
> *drag* gesture is untestable by XCUITest and unconfirmed by hand — its Move Left/Right
> commands, which share the same handler, are covered end to end — and M12 is core-only,
> reachable from no panel. M13 and M14 are core-only in code but a user reaches both by
> typing, so each is driven against the running app by an XCUITest rather than eyeballed.
>
> **M10–M18 take up what the deferred list had been holding**: three CSS syntaxes the
> parser used to reject, the missing-component semantics all three rest on, a
> `@media (color-gamut)` export shape, design-token import, and a CLI over `ColorCore`.
> **All three now parse** — `calc()` (M13), `rgb(from …)` (M14) and `color-mix()` (M15).
> M10 (relocating `ColorCore`) and M11 (the three items M9 deferred)
> are done, plus the two housekeeping commits recorded after M11 — the exported `UTType`
> declaration M11's drag was missing, and Xcode's recommended build settings. **M12, the
> spine, is done**: `ComponentRole` and carry-forward exist, so every "depends on M12" is
> discharged — M14 was the first milestone to consume it, which is what turned that claim
> into a tested one, and M15 is the one it was written for. **M13 and M14 closed the
> plan's last dependency chain**, and M15 waited on nothing. **M16, M17 and M18 remain,
> and all three are independent**, so they can be taken in any order. What remains beyond
> that is **M8b** (saving an export to a file) and the shorter deferred list at the end.
>
> **M12 is the first milestone with no oracle *and* nothing to look at**, so its standard
> of proof is the spec's own worked examples plus five mutations. Two of its findings are
> worth carrying: analogous *sets* are a second mechanism that an implementation doing only
> individual matching loses entirely and still passes every same-family test, and a
> spec-printed value should be asserted as a rounding rather than with a tolerance.
>
> M9 closes the loop M8 left open, and its screenshots prove it end to end: a shade ramp
> saved into a project as `brand` and exported from the other tool comes back as a
> `:root` block reading `--brand-500: oklch(0.6231 0.188 259.81)` — the same value, to
> the last digit, that M8 recorded against colorjs.io. Nothing was lost crossing the
> store. Its screenshots also caught a banner announcing a failure that had not happened;
> see the milestone.
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
> - **A SwiftData to-many relationship is unordered, and observably so.** Not a caveat
>   from the documentation — a measurement. Read an eleven-stop ramp back off
>   `palette.entries` instead of sorting it and the stops arrive `600, 400, 100, 200,
>   900, 300, 800, 950, 500, 50, 700`, in the same context, immediately after the save
>   that inserted them in order. Order that carries meaning gets an explicit `sortIndex`
>   and a sort on read; otherwise Tailwind's eleven keys name eleven wrong colors and the
>   exported block still looks perfectly well-formed.
> - **SwiftData resolves relationship inverses when the *container* is built, not when
>   the code compiles.** `SavedColor` is the destination of two to-many relationships (a
>   project's loose colors and a palette's entries), and with the inverses left to
>   inference every model still type-checks and the app throws on launch. Hence
>   `@Relationship(inverse:)` on both sides and "the container initializes" as the first
>   assertion in `ProjectStoreTests`.
> - **`@Model` needs no `nonisolated` gymnastics under
>   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.** The macro's generated `PersistentModel`
>   conformance compiles unannotated, which was the one thing worth spiking before
>   designing a schema around it — every other layer in this project needed the
>   annotation.
> - **One flag cannot describe two opposite situations.** The projects store is ephemeral
>   both when the on-disk one fails to open and when a UI test asks for a throwaway, and
>   an `isEphemeral` boolean made the app announce "the store could not be opened" during
>   a run that had requested exactly that store. Three cases, and the banner fires for the
>   failure alone: a warning shown when nothing is wrong is a warning nobody reads.
> - **A component's letter is not its meaning, and CSS Color 4 §13.2's table says so
>   twice.** `b` is Blue in an RGB space and Opponent b in Lab — unrelated quantities
>   sharing a letter — while `r` and `x` are the *same* category, because the spec counts
>   XYZ as a super-saturated RGB space. Deriving analogy from `componentLabels` gets both
>   backwards, which is why the role table is transcribed like a matrix rather than
>   computed. Confirmed by mutation: collapsing Opponent b into Blues carries a missing
>   `lab()` b into sRGB's blue channel, and one test catches it.

## Context

The goal is a native macOS app that serves as a personal, one-stop color toolkit for daily web development: parse and convert every CSS Color 4 format, check accessibility, transform colors, generate harmonies and ramps, export as CSS, and save collections into projects. Scope is expected to grow over time, so this plan optimizes for a **trustworthy core with a stable API** that features can be layered onto indefinitely, rather than a one-shot build.

The single thing that determines whether this tool is worth relying on is **conversion accuracy**. Most color tools are approximately correct — they use blog-post matrices, ignore the D50/D65 distinction between `lab()` and `oklab()`, and clip out-of-gamut colors instead of gamut-mapping them. The plan therefore front-loads a pure, dependency-free color core validated against reference test vectors before any UI is written.

### Current state

M0–M12 are built. The stock SwiftData template (`Item.swift`, the `NavigationSplitView` list) is gone — M9 brought SwiftData back on its own terms rather than the template's, and M11 versioned that schema. `ColorCore/` now sits at the repo root as its own synchronized group rather than inside the app's, which is what makes a second target possible. What stands now is:

| Layer | Files |
|---|---|
| Core model | [ColorValue.swift](ColorCore/ColorValue.swift), [ColorSpace.swift](ColorCore/ColorSpace.swift) |
| Spaces | [Matrices.swift](ColorCore/Spaces/Matrices.swift) and [NamedColors.swift](ColorCore/Spaces/NamedColors.swift) (**generated**), [TransferFunctions.swift](ColorCore/Spaces/TransferFunctions.swift), [ColorMatrix.swift](ColorCore/Spaces/ColorMatrix.swift) |
| Convert | [Conversion.swift](ColorCore/Convert/Conversion.swift), [GamutMapping.swift](ColorCore/Convert/GamutMapping.swift), [GamutBoundary.swift](ColorCore/Convert/GamutBoundary.swift), [HSV.swift](ColorCore/Convert/HSV.swift), [MissingComponents.swift](ColorCore/Convert/MissingComponents.swift) |
| Parse | [CSSTokenizer.swift](ColorCore/Parse/CSSTokenizer.swift), [ColorSyntax.swift](ColorCore/Parse/ColorSyntax.swift), [CSSColorParser.swift](ColorCore/Parse/CSSColorParser.swift) |
| Format | [CSSFormatter.swift](ColorCore/Format/CSSFormatter.swift), [FormatCatalog.swift](ColorCore/Format/FormatCatalog.swift) |
| Shell | [ColorStore.swift](Color%20Toolkit/Features/Shell/ColorStore.swift), [MenuBarPanel.swift](Color%20Toolkit/Features/Shell/MenuBarPanel.swift), [ContentView.swift](Color%20Toolkit/ContentView.swift) |
| Analysis | [WCAGContrast.swift](ColorCore/Analysis/WCAGContrast.swift), [APCAContrast.swift](ColorCore/Analysis/APCAContrast.swift), [CVDSimulation.swift](ColorCore/Analysis/CVDSimulation.swift), [CVDMatrices.swift](ColorCore/Analysis/CVDMatrices.swift) (**generated**) |
| Transform | [Adjustment.swift](ColorCore/Transform/Adjustment.swift), [LightnessCurve.swift](ColorCore/Transform/LightnessCurve.swift), [Harmony.swift](ColorCore/Transform/Harmony.swift), [ShadeRamp.swift](ColorCore/Transform/ShadeRamp.swift), [ContrastSolver.swift](ColorCore/Transform/ContrastSolver.swift) |
| Export | [ExportTemplate.swift](ColorCore/Export/ExportTemplate.swift), [ColorExport.swift](ColorCore/Export/ColorExport.swift) |
| Conversion UI | [ColorInputField.swift](Color%20Toolkit/Features/Conversion/ColorInputField.swift), [ConversionPanel.swift](Color%20Toolkit/Features/Conversion/ConversionPanel.swift), [FormatPresentation.swift](Color%20Toolkit/Features/Conversion/FormatPresentation.swift) |
| Contrast UI | [ContrastPanel.swift](Color%20Toolkit/Features/Contrast/ContrastPanel.swift) |
| Picker UI | [PickerState.swift](Color%20Toolkit/Features/Picker/PickerState.swift), [PickerPlane.swift](Color%20Toolkit/Features/Picker/PickerPlane.swift), [PickerPanel.swift](Color%20Toolkit/Features/Picker/PickerPanel.swift) |
| CVD UI | [CVDPanel.swift](Color%20Toolkit/Features/CVD/CVDPanel.swift) |
| Transform UI | [TransformPanel.swift](Color%20Toolkit/Features/Transform/TransformPanel.swift) |
| Export UI | [ExportPanel.swift](Color%20Toolkit/Features/Export/ExportPanel.swift), [ExportPresentation.swift](Color%20Toolkit/Features/Export/ExportPresentation.swift) |
| Persistence | [ColorRecord.swift](Color%20Toolkit/Persistence/ColorRecord.swift), [ProjectModels.swift](Color%20Toolkit/Persistence/ProjectModels.swift), [ProjectLibrary.swift](Color%20Toolkit/Persistence/ProjectLibrary.swift), [PersistenceStack.swift](Color%20Toolkit/Persistence/PersistenceStack.swift), [SchemaVersions.swift](Color%20Toolkit/Persistence/SchemaVersions.swift) |
| Projects UI | [ProjectsPanel.swift](Color%20Toolkit/Features/Projects/ProjectsPanel.swift) |
| Design system | [ColorSwatch.swift](Color%20Toolkit/DesignSystem/ColorSwatch.swift), [ColorValue+SwiftUI.swift](Color%20Toolkit/DesignSystem/ColorValue+SwiftUI.swift) |
| Services | [Clipboard.swift](Color%20Toolkit/Services/Clipboard.swift), [ScreenSampler.swift](Color%20Toolkit/Services/ScreenSampler.swift), [GlobalHotKey.swift](Color%20Toolkit/Services/GlobalHotKey.swift) |

`Persistence/` exists as of M9 and holds five files, listed above — M11 added
`SchemaVersions.swift`. An earlier revision of this file claimed one existed and was empty
long before that was true; git does not track empty directories, so it never survived a
clone and the claim held only on the machine that made it.

Key facts about the project, established during exploration and still current:

| Fact | Value | Why it matters |
|---|---|---|
| `objectVersion` | `77`, with **two** `PBXFileSystemSynchronizedRootGroup`s | **New `.swift` files are picked up automatically.** No `project.pbxproj` edits needed — write into `ColorCore/` or `Color Toolkit/`, subfolders included. Editing the project file is for adding a *target*, nothing else. |
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

Four layers, strictly one-directional. **`ColorCore` imports nothing but `Foundation`** — no SwiftUI, no AppKit, no SwiftData. Every one of its 27 files, measured rather than assumed. That constraint is what keeps it exhaustively testable and reusable, and M10 turned "reusable in principle" into "addressable by a second target": it now sits beside the app rather than inside it.

```
Color Toolkit/                    ← repo root
├── ColorCore/                    ← its own synchronized root group (M10)
│   ├── ColorValue.swift          canonical model
│   ├── ColorSpace.swift          space enum + component metadata
│   ├── Spaces/                   matrices, transfer functions, white points
│   ├── Convert/                  conversion hub + gamut mapping
│   ├── Parse/                    CSS tokenizer + parser
│   ├── Format/                   CSS serializer + format catalog
│   ├── Analysis/                 WCAG, APCA, CVD, deltaE
│   ├── Transform/                lightness/sat/hue, harmonies, ramps
│   └── Export/                   declaration templates + document shapes
├── Color Toolkit/                ← the app target's own group
│   ├── Services/                 eyedropper, global hotkey, clipboard
│   ├── Persistence/              SwiftData @Models + Codable bridge
│   ├── Features/                 one folder per feature area (SwiftUI)
│   └── DesignSystem/             shared swatch/slider components
├── Color ToolkitTests/
├── Color ToolkitUITests/
└── Tools/                        Node + Python generators (not in any target)
```

Both `ColorCore/` and `Color Toolkit/` are `PBXFileSystemSynchronizedRootGroup`s listed by the app target, so a `.swift` file dropped in either compiles with no project edit. The sources still build **into the app module**, which is why everything in `ColorCore` stays `internal` and the tests reach it with `@testable import`. M18's CLI target lists only the first group.

The boundary runs in one direction only: **ColorCore knows facts, the UI layer owns editorial copy.** `CSSOutputFormat.catalog` lives in core; the section names ("Web", "Perceptual") and the per-format labels live in `Features/`. A core test that reaches into the UI for a display string is the smell that the layering has slipped — and in M3 it also broke a commit's ability to build standalone.

### The core model

Storing everything as RGB is the mistake to avoid — `oklch(70% 0.4 30)` is outside sRGB, and normalizing to RGB on input destroys it permanently. `ColorValue` therefore **retains the color in its authored space**:

```swift
struct ColorValue: Hashable, Sendable, Codable {
    var space: ColorSpace
    var components: SIMD3<Double>
    var alpha: Double
    var missing: ComponentMask   // CSS `none`, set by the parser and honoured by the serializer
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

Serializer needs configurable precision and legacy-vs-modern output. **Deferred at the time:** `calc()`, and relative color syntax (`rgb(from …)`) — a strong later addition, now planned as M13 and M14. `none` *is* parsed and round-trips (`nonePreserved()` pins it); what M2 left undone is the interpolation semantics in §13.2, which is M12.

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

- **WCAG 2.2** — [WCAGContrast.swift](ColorCore/Analysis/WCAGContrast.swift). Spec-literal `0.03928`, AA/AAA × normal/large, plus 1.4.11's 3:1 non-text threshold.
- **APCA** — [APCAContrast.swift](ColorCore/Analysis/APCAContrast.swift). Transcribed from colorjs.io 0.7.0's implementation of **0.0.98G**, matching to 1e-9 across 108 pairs in both polarities.
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

- **[CVDMatrices.swift](ColorCore/Analysis/CVDMatrices.swift)** —
  **generated** (`python3 Tools/generate-cvd-matrices.py`) from a vendored, pinned copy
  of Machado's Table 1; never hand-edited, same rule as `Matrices.swift`. The generator
  is Python because the oracle that carries the table (colour-science, and `daltonlens`
  after it) is Python; it needs only the standard library.
- **[CVDSimulation.swift](ColorCore/Analysis/CVDSimulation.swift)** —
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

- **[GamutBoundary.swift](ColorCore/Convert/GamutBoundary.swift)** —
  `maxChroma(lightness:hue:in:)` and the sampled curve, in ColorCore because it is a
  numeric fact. Bisects the same `inGamut` predicate the badge uses, so the drawn line
  and the badge are one claim. See the blue counterexample and the tolerance note above
  — both are pinned by tests precisely so they are not "fixed".
- **HSV is deliberately not a `ColorSpace` case.** CSS has no `hsv()`, so a case would
  need excluding by hand from the parser, serializer, catalog and every `allCases` loop,
  and the first one missed would offer a format no browser accepts. It is a coordinate
  on the side ([HSV.swift](ColorCore/Convert/HSV.swift)) wrapping the
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

- **[Adjustment.swift](ColorCore/Transform/Adjustment.swift)** —
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
- **[LightnessCurve.swift](ColorCore/Transform/LightnessCurve.swift)** —
  the S-curve: contrast with no second color in it. The pivot is **fixed at `L = 0.5`**
  rather than configurable, and that is what buys the good behavior: exact symmetry,
  fixed points at black/mid-gray/white, and an exact inverse. Opposite strengths cancel
  to 1e-12 because the strength maps *exponentially* onto the exponent (`3^s`), so `+0.5`
  and `−0.5` are reciprocal gammas; a linear mapping would fail to cancel. Its real use
  is on a **set** — it widens a ramp's ends while holding its order and its midpoint,
  which a lightness offset cannot do, because an offset slides a ramp where a curve
  stretches it.
- **[Harmony.swift](ColorCore/Transform/Harmony.swift)** — the six, at
  the classic angles but turned on OKLCH's wheel. That choice is the whole point:
  rotate 180° in HSL and a saturated blue's "complement" comes back a dim mustard,
  because HSL's hue is a raw RGB angle in which equal degrees are wildly unequal steps.
  Monochromatic is the odd one out — one hue, many lightnesses — so it delegates to
  `ShadeRamp` rather than reimplementing a lightness family worse.
- **A gray has no relatives, and the arithmetic says so.** Every hue harmony of
  `#808080` returns the same gray repeated, which is correct — there is no third color
  related to a neutral by 120° — so the panel says it in words rather than showing five
  identical swatches with no explanation.
- **[ShadeRamp.swift](ColorCore/Transform/ShadeRamp.swift)** — the two
  rules do different jobs and both are needed. Tapering chroma toward the ends is the
  *aesthetic* rule (light stops read as tints rather than as the same ink at a higher
  lightness); holding every stop at or inside the `GamutBoundary` edge is the
  *correctness* rule. Because the edge comes from the same predicate the badge uses,
  every stop is in gamut **by construction** rather than by a mapping applied afterwards.
- **[ContrastSolver.swift](ColorCore/Transform/ContrastSolver.swift)** —
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
  recents. There was no `Palette` type at this point, deliberately — it belonged to M9,
  and inventing one here to have something to point at would have been building the next
  milestone early and worse. M9 added it, and adding the saved-palette source afterwards
  cost exactly one enum case, which is the evidence the seam was drawn in the right place.
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
only have deferred it — M9 added the seventh tool, and all seven fit in the body. **Seven
is the tested ceiling, though, not a headroom claim**, which is why M15 and M17 fold their
UI into existing panels rather than each taking a `Tool` case. It also makes the
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
panel whose output is meant to be pasted into a stylesheet you already have open.

**Still the one deferred piece, and M9 did not bring it any closer** — the note here used
to say it was worth revisiting alongside M9 "where a saved project is a file anyway",
which turned out to be wrong on the facts. A SwiftData project is a store *inside the app
container*, written with no entitlement and never shown to the user as a file, so it
shares nothing with `NSSavePanel` but the word "save". This remains its own small
milestone, standing on its own reasons.

### ✅ M9 — Projects (SwiftData)

Built as planned: three `@Model` classes holding space ID plus raw components rather than
a serialized string or a `Data` blob, so saved values stay lossless *and* queryable, with
a small value-type bridge to and from `ColorValue`. `ColorCore` never learns SwiftData
exists — and neither, it turns out, does `ColorStore`.

```swift
@Model final class Project    { uuid, name, colors, palettes, createdAt, modifiedAt }
@Model final class SavedColor { name, notes, sortIndex, spaceID, c0/c1/c2, alpha, missingMask, text }
@Model final class Palette    { name, kindID, sortIndex, entries }
```

**The sketch above was missing two fields, and both are load-bearing.**

- **`missingMask`.** The parser sets `ComponentMask` for CSS `none`, so without it a saved
  `oklch(0.7 0.2 none)` comes back with a hue of exactly zero — a different color, with
  nothing anywhere to say so.
- **`text`, the authored spelling.** `RecentColor` already carries its text because
  re-deriving one canonicalizes, and the same argument applies twice over to something
  saved deliberately: a stored `rebeccapurple` recalled as `#663399` is the app rewriting
  a choice the user made and then kept. Components remain the *value* and text is only how
  it was written, so they are two spellings of one claim — and a test therefore requires
  that parsing the text reproduces the components, which is the check that stops them
  drifting.

Decisions worth recording:

- **`ColorStore` does not import SwiftData, and that is the load-bearing boundary.**
  `ProjectsPanel` owns the app's only `@Query` and only `modelContext`; a palette leaves
  it as `[PaletteEntry]`, the same value type a harmony produces. So `ExportSource.saved`
  is one enum case rather than a second path through the export layer, `ExportStoreTests`
  still needs no `ModelContainer`, and the selected project is remembered as a plain
  `UUID` — which is why `Project` carries one alongside SwiftData's `PersistentIdentifier`.
- **Staging carries the palette's *name*, not just its colors.** A set saved as `brand`
  exports as `--brand-500` however the export panel was last configured. That is the whole
  payoff M8 deferred, and forgetting the name would have made it half a feature.
- **`SavedColor.name` doubles as the export key.** A ramp stop's key *is* the only sensible
  thing to call it — `500` — so a second field would be two names for one string and an
  invitation for them to disagree.
- **`notes` got a UI rather than a deferral.** The sketch listed the field and the first
  draft stored it with nothing anywhere to write it — a column that exists and does
  nothing, which is the sort of thing this file exists to catch. It is a popover off the
  swatch's context menu, because notes are the least-used thing in the panel and a
  permanent text box under every tile would bury the colors it is describing.
- **Mutations live in `ProjectLibrary`, not in the panel.** A thin wrapper over
  `ModelContext` that owns the *rules* — where a position comes from, what counts as
  touching a project, which relationship a color belongs to — so they can be asserted
  against an in-memory container instead of through a rendered view. It saves explicitly
  rather than leaning on autosave, which is fine for an app and useless for a test that
  wants to fetch back what it just wrote.
- **A store that will not open falls back to memory and says so.** Refusing to launch over
  a corrupt file is the wrong trade for a tool opened dozens of times a day; accepting
  saves that silently evaporate is worse than both. Hence a banner — and hence the
  three-case `Status`, after the first version fired it during a UI test that had *asked*
  for a throwaway store. See the finding above.
- **UI tests launch with `UITestInMemoryStore`.** XCUITest drives the shipping app, so
  without it a test that saves would deposit a project in the real library and the next run
  would find it. The launch argument is the only way to reach that decision from outside
  the process, and it carries no leading hyphen because `NSUserDefaults` claims the
  argument domain for anything that starts with one.

  That turned out to be half the story, discovered later: a *bare* argument is claimed
  too, by AppKit, whose `NSTreatUnknownArgumentsAsOpen` defaults to on and reads it as a
  file to open — and an app launched to open a document never creates its default window.
  So the launch is three strings, `["-NSTreatUnknownArgumentsAsOpen", "NO",
  "UITestInMemoryStore"]`. The failure it causes is worth naming because it is unreadable
  from the outside: the app launches, reaches `.runningForeground`, publishes a full menu
  bar, and has no window, so all six tests fail on element queries and look like a broken
  panel. It is not specific to this suite — adding any meaningless argument to
  `ConversionSmokeTests` reproduced it, which is what identified the cause. Nor is it a
  regression: the same six fail at pre-M11 commits, so this is macOS drift and the green
  runs recorded in the M9 and M11 commit messages no longer reproduce on a current host.
- **Schema versioning is deferred, deliberately.** Additive changes migrate on their own
  and this is a personal-scope v1; a `VersionedSchema` would be ceremony around a
  migration that has not happened yet. Worth adding the first time a field is *removed*
  or retyped.

**The seventh tool went in before Export rather than after.** Export is documented as
terminal — every other tool answers a question about the color and this one writes the
answer down — and Projects is the tool that *keeps* things, which happens before you
write them out and is itself one of the things Export now reads. Seven segments still fit
the switcher in the window body, which is the layout M8 moved it there to survive.

**Testing splits along the boundary.** The mapping is a value type, so `ColorRecordTests`
asserts every space's round trip, the `none` mask and the two spellings agreeing, with no
container anywhere. `ProjectStoreTests` takes the things only SwiftData can answer —
inverses, cascades, what comes back from a fetch. `ProjectsSmokeTests` covers what only a
running app can show: clicking a saved swatch returns *your* spelling to the field, and a
ramp saved in one tool exports under its own name in another.

**An in-memory store cannot prove persistence, which is the entire feature.** Every test
above ran on `isStoredInMemoryOnly`, and a container that never touches a disk proves
round tripping *within a context* and nothing whatever about surviving a quit. So one
test leaves memory: it writes to a real SQLite store in a temp **directory** (SQLite puts
`-wal` and `-shm` sidecars beside the file, and cleaning up only the `.store` would leave
state that could make a later run pass for the wrong reason), releases the container,
opens a second one over the same file, and requires both the spelling and the ramp's
order to come back. Separately, launching with no arguments was confirmed to open
`default.store` under
`~/Library/Containers/me.parkersprouse.color-toolkit/Data/Library/Application Support/` —
so the sandbox permits the default location, `.persistent` is the arm actually taken, and
the fallback banner is not quietly the normal case.

Four mutations confirm the tests bite: dropping the `missing` mask fails two, nullifying
the palette cascade fails two, canonicalizing the stored text fails six, and removing the
sort fails thirteen. **The last one is the interesting one** — it did not merely risk
disorder, it produced it on the first run, which is what turned an assumption about
SwiftData into the measurement recorded above.

*Done, and reviewed on the running app from its own screenshots — see the status note for
the ramp that survived a round trip through the store unchanged.*

### ✅ M10 — `ColorCore` to its own group

Preparation, not a feature, and sequenced first for one reason: `ColorCore` sat *inside*
the app target's synchronized group, so no second target could address it, and relocating
26 files only gets more expensive as the milestones below add to them.

It is now a repo-root sibling with its own `PBXFileSystemSynchronizedRootGroup`, listed by
the app target. The sources still compile **into the app module**, so `internal` access is
untouched and no `public` sweep was needed — the alternative, extracting a real SPM
package, would have meant `public` on every type, member and `init` across 26 files and
`import ColorCore` throughout the app. Unit tests were unaffected because they reach the
core through `@testable import Color_Toolkit`, never by listing its sources.

**The path references outside the project file are the part worth remembering.** Three
pointed at the old location and would have written to a stale path in silence: the two
generators' output directories and `.swiftformat`'s exclusion list. The proof they were
updated is that re-running every generator reproduces all three generated Swift files
byte-for-byte.

**A measured host dependency, found on the way and left alone:** regenerating
`cvd-vectors.json` returns 26 of 405 values differing in the last ULP. The generator is
idempotent on a given machine, so this is not nondeterminism — `**` on Python floats calls
libm `pow`, which IEEE-754 does not require to be correctly rounded, so it varies by
platform and libm version. Differences of 1e-16 are far inside every tolerance the CVD
tests use. Do not "fix" it by committing a regenerated fixture; that just moves the churn
to whoever regenerates next.

### ✅ M11 — Projects: schema versioning, reordering, loose sets

The three items M9 deferred, done together because they are all the projects panel.

**The `VersionedSchema` is insurance and is documented as such.** `ColorToolkitSchemaV1`
wraps the three existing models with an empty migration plan. Nothing migrates, and
nothing here asserts that it does — a test over an empty stage list would pass against a
plan that does nothing, which is exactly what it is. The value is having a version to
migrate *from* when the first destructive change lands, rather than writing the version
boundary and the data transformation at the same moment, against a shape no longer in the
source tree. `VersionedSchema` conformance needs `nonisolated` on its statics, per the
project's default actor isolation.

**Reordering renumbers, and that is a correctness rule.** `nextIndex(after:)` leaves gaps
on purpose so an append lands last after a deletion — but a gap is only safe while
positions are append-only. Slotting a moved color *into* one means inventing a value
between two neighbours, and two moves into the same gap collide. So `moveColors` renumbers
densely from zero, which is the one place that happens; appends still read the maximum, so
`newColorsLandLast` is untouched. **No new model field, and therefore no migration** — the
drag lives entirely inside `ProjectsPanel`, which owns the `modelContext`, so the rule that
forced `Project.uuid` (keeping `ColorStore` free of SwiftData) is simply not in play.

**Loose sets needed a second `savePalette`, not a conversion into the first.** The
`PaletteEntry` overload re-derives a spelling because its colors — ramp stops, harmony
members — never had one. A hand-picked set's colors were typed by the user, and sending
them through that door returns `rebeccapurple` as `oklch(…)`, contradicting the panel's own
caption. Copying `SavedColor.record` carries text, components and the `missing` mask
across. Keys come from each color's name, **deduplicated** — not tidiness: two entries
sharing a key collapse into one CSS property and a color leaves the export with nothing
marking its absence. Generated palettes never meet this; two colors named "blue" is an
ordinary thing for a person to have.

**Three UI facts cost real time and each looked like a bug somewhere else:**

- **A SwiftUI `Button` is a single accessibility element.** The selection tick, layered
  over the swatch as an overlay, was swallowed whole — absent from the tree entirely — and
  `savedColor-N` began matching *two* elements, breaking an existing recall test that had
  nothing to do with the change. It is a `ZStack` sibling now.
- **XCUITest cannot start an AppKit dragging session.** Its synthesized events move the
  pointer without the drag beginning, so a drag-driven test fails whether the feature works
  or not — including with `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`.
- `.draggable` ended up on the tile rather than on the swatch Button, on the theory that a
  Button consumes the press a drag needs. **That theory is unverified and should not be
  repeated as fact:** the test failed identically before and after the move, because of the
  point above. It is recorded as a placement, not a finding.

That last one forced a question worth more than the test: **a drag-only reorder is
unusable from the keyboard and from VoiceOver**, which would have made this the one thing
in the panel some people could not do at all. Move Left and Move Right now sit in the
tile's context menu and share `move(from:to:)` with the drop handler. The UI tests drive
those, so the shared path is covered end to end through the store and across a panel
switch; the gesture that opens it is not covered by any automated test and wants a human
to try it once.

Nine store tests, each confirmed against a mutation of the rule it covers — dropping the
offset discount, skipping the renumber, disabling dedup, re-deriving text, and moving
colors instead of copying them all fail the suite. The reorder is checked across a real
store close and reopen, since an in-memory container proves only that the objects in hand
were mutated.

### ✅ Housekeeping after M11

Two commits that belong to no milestone, recorded because both changed something outside
the source tree and neither is visible from a Debug build.

**The drag needed an `Info.plist`, and the app did not have one.** `UTType(exportedAs:)`
returns a working identifier whether or not the type is declared, so M11's reorder drag
functioned — both ends compare the same string — while every launch logged that
`me.parkersprouse.color-toolkit.saved-color-position` "was expected to be declared and
exported in the Info.plist … but it was not found". `GENERATE_INFOPLIST_FILE` covers every
scalar through `INFOPLIST_KEY_*`, and `UTExportedTypeDeclarations` is an array of
dictionaries with no such spelling, so a file is the only way to say it. Setting
`INFOPLIST_FILE` alongside the generator **merges** rather than replaces — measured by
diffing the built plist against a build without it, 24 keys in and the same 24 plus the
declaration out — and it is set in *both* configurations, because the declaration is read
only at runtime and a Release-only omission is invisible from a Debug build. The file sits
at the **repo root**: `Color Toolkit/` is a synchronized root group, so a plist dropped
there becomes the target's `Info.plist` *and* a bundled resource, which builds, warns, and
ships a duplicate in `Contents/Resources`. Confirmed by building it that way first.
`lsregister -dump` now finds the type; before, it did not.

**This registered the type. It did not test the gesture** — that still wants a human to
try it once, exactly as M11 recorded. The commit also corrected the comment above
`.draggable`, which had restated the Button-consumes-the-press theory as fact after
PLAN.md and CLAUDE.md had already walked it back.

**Xcode's recommended build settings, accepted with one real consequence.**
`DEAD_CODE_STRIPPING` was absent from every container and therefore resolved to `NO`, not
the `YES` the templates imply, so the Release link now runs `-dead_strip`. It is written to
the project and all three targets in both configurations, because the validator checks for
the key's *presence* per container rather than its resolved value. Test discovery is
runtime reflection with no static call site, so the check that stripping is safe is the
**count**, not the verdict: 316 cases (291 Swift Testing + 25 XCUITests), unchanged, and
Release links clean. `STRING_CATALOG_GENERATE_SYMBOLS` is inert today — no `.xcstrings`
files exist and all three targets already override it — and is set at the project level
only, to seed the default for M18's CLI target.

### ✅ M12 — Missing-component semantics ⭐ *the spine*

Not user-visible on its own, and three later milestones are wrong without it.

`ColorValue.converted(to:)` drops all three component `missing` flags and carries only
`.alpha`. When two colors are *interpolated*, CSS requires missingness to survive into a
space with **analogous** components — an `h` that is `none` in `hsl` is still `none` in
`oklch` — and nothing in the codebase can express "analogous" today. `componentLabels` is
the closest thing and is display copy, not a fact.

**Two things this milestone was originally scoped to do are wrong, and reading CSS Color 4
§4.4.1 and §13.2 rather than reasoning from the enum is what caught them.** Both are
recorded here because the mistaken version is the intuitive one.

**Carry-forward is an *interpolation* rule, not a conversion rule.** The plan said to carry
missing flags at all three conversion sites. The spec scopes carrying to interpolation, and
says something different about plain conversion: *"if a color is automatically produced by
color space conversion, then any powerless components in the result must instead be set to
missing"* — the result's own powerless components, not the source's missing ones. So
`converted(to:)` stays a pure numeric conversion, and carry-forward becomes an explicit
operation that interpolation asks for. Whether the serializer marks powerless components
stays where it is, behind `noneForPowerlessComponents`, because that is a presentation
choice and printing `none` at people unasked is not an improvement.

**The powerless rules are hue-only, and the existing implementation already covers them.**
The plan invented "HSL saturation at `l == 0` or `100`"; the spec has no such rule — it says
only that such a color *displays* as black or white "due to gamut mapping to the display".
The complete list is HSL hue at `s == 0`, HWB hue when achromatic (`w + b >= 100%`), and
LCH/OKLCH hue at zero chroma, plus a UA rule to treat hue as powerless below an epsilon of
colorfulness. `markingPowerlessComponents()` already decides this with one OKLab-based
`isAchromatic` test, which lands on the correct answer for all four spaces by a different
route — and the epsilon rule is explicitly blessed. **Nothing to add here. Do not
"complete" it.**

What was owed, and what was built:

- **[`ComponentRole`](ColorCore/ColorSpace.swift)**, with `ColorSpace.componentRoles`
  beside `componentLabels` but categorically different from it — copy that may be reworded
  freely versus a fact with behavior hanging off it. `hueIndex` is now *derived* from the
  table (`componentIndex(of: .hue)`) so the two cannot drift, and a test pins the
  derivation against the four answers it gave as a hand-written list, because a mistyped
  role would otherwise move the picker's hue axis with nothing to say so.
  **The table is transcribed from the spec, not derived from the labels** — three of its
  groupings are not guessable. `r` and `x` are the *same* category, because XYZ counts as
  a "super-saturated RGB space" (likewise `g`/`y` and `b`/`z`). Chroma and Saturation are
  one category, "despite Saturation being Lightness-dependent". Whiteness and Blackness
  have **no** analog in any space. And `b` means different things in different spaces —
  Blues in RGB, Opponent b in Lab — so roles are per-space and never read off a letter.
- **Analogous *sets*, which are a second mechanism and easy to miss entirely.** After
  removing individually-analogous components, whatever remains on each side forms a set,
  and if *every* member of the source's set is missing, the whole destination set is
  missing. This is what makes `lab(50% none none)` → `lch(50% none none)` rather than
  `lch(50% 0 0)`, and `rgb(none none none)` → `oklab(none none none)` even though sRGB and
  OKLab share no individual component. Alpha is analogous to alpha.
  **A set travels whole or not at all**, which is the half that is easy to get backwards:
  `lab(50% 0 none)` → `lch` carries *nothing*, because one of the two set members is
  present. Both halves are tested, and swapping the `allSatisfy` for a `contains` fails
  three of them.
- **[`MissingComponents.swift`](ColorCore/Convert/MissingComponents.swift)** —
  `carriedForwardMissing(to:)` returns the mask, `convertedForInterpolation(to:)` is the
  operation M15 calls (and does, unchanged). `converted(to:)` is untouched, so the blast radius is nil and
  no existing test needed revising — `referenceSaysAchromatic` was never approached.
- **`ParseError.noneNotAllowedInLegacy` is gone**, which is the honest resolution rather
  than making it throwable. The parser deliberately *warns* here
  (`ParseWarning.noneInLegacySyntax`) because the intent is unambiguous, so the error case
  was a second, unreachable answer to a question already answered. A note where the warning
  is declared says so, since the tempting fix is to start throwing it.

**The ordering the spec demands is recorded at the API, because M15 will not have the spec
in front of it.** (It did not, and the note did its job — see M15, which adds the step
this one does not mention: powerless marking has to *happen*, after the carry-forward.) Carry-forward runs *before* powerless marking, never after: a
carried-forward missing component takes the **other** color's value when interpolated,
where a powerless one is zero, so marking first would convert a value the spec wants
preserved into a zero. Two tests hold the line — a carried hue keeps the value the
conversion produced, and a plain gray carries *nothing* even though its hue is powerless in
every polar space. Folding the two operations together would pass one and fail the other.

The spec's own worked examples are the tests: the two set cases above, plus
`lch(50% 0.02 none)` and `color(display-p3 0.7 0.5 none)` in OKLCH, where the missing hue
carries and the missing blue does not. The spec also prints what that pair converts to, so
those numbers are asserted too — **as roundings rather than with a tolerance**, because a
printed `0.0001` is a bucket and the true chroma is `5.9e-5`. Asserting `|x − 0.0001| <
5e-5` would have passed by 9e-6 and looked like agreement to four decimals, which it is
not.

**No oracle, and that is measured rather than assumed:** colorjs.io resolves `none` on
conversion (`hsl(none 50% 50%).to('oklch')` returns a real hue), so this is spec-derived
and property-tested like `Transform/`.

**Five mutations confirm the tests bite**, each failing exactly the tests that encode the
rule it breaks: collapsing Opponent b into Blues fails one, deleting the set rule fails
three, reordering HSL's roles fails four (including the `hueIndex` pin), turning the set
rule's `allSatisfy` into `contains` fails three, and dropping alpha's carry fails one.

Storage was safe as predicted: `ColorRecord.missingMask` is an `Int` and the `& 0b1111`
truncation is only on the read path, so this sets existing bits and forces no schema change.

### M13 — `calc()`, scoped ✅

All three predicted layers moved, and each blocked for the predicted reason.
`UnsupportedFunctions` loses `calc` and keeps the rest — `min`/`max`/`clamp`/`round`
because they are the other math functions and none is evaluated, `var`/`env`/`attr` for
the permanent reason that they cannot be resolved from the string at all. The pre-tokenize
check therefore keeps its job and needed only a different worked example; it still fires
for a `var()` nested inside a `calc()`. `CSSTokenizer` gained `.plus`, `.minus`,
`.asterisk` and `.openParen`. And the slash was the real one: `calc()` is consumed **as a
unit** in `scanArguments`, so `rgb(0 0 0 / calc(1 / 2))` has two slashes meaning different
things with only the parens to separate them.

Scope held as drawn — `+ - * /` over numbers, percentages and angles, flat. Two things
inside that scope are more than they look. **Precedence is real**: `calc(1 + 2 * 3)` is 7,
which a left-to-right fold gets wrong, so the grammar is two levels rather than one. And
**the type rules are enforced** — matching types for `±`, a plain number on one side of
`*` and on the right of `/` — but they are phrased as *this parser's scope*, never as CSS
invalidity. Percentages resolve against a reference in a color component, so CSS Values
4's type algebra is more permissive here than these rules are; saying otherwise would be a
claim wider than the evidence, and widening the rules later should not have to retract one.

**A resolved `calc()` becomes an ordinary written `Value`, and that is a decision.**
Everything downstream — the per-component grammar, the legacy same-type rules, the
angle-slot check — then runs unchanged and cannot tell a computed value from a typed one,
which is why the milestone cost so little. It is also why `rgb(calc(50%), 0, 0)` satisfies
legacy rgb's same-type rule and `hsl(120, calc(25 * 2), 50%)` fails its
percentage-required one. Both are pinned rather than left to fall out.

Two findings worth carrying:

- **`calc(1 -2)` is rejected for free, and the reason is the same as CSS's.** The spec
  demands whitespace around `+` and `-` precisely because `-2` is otherwise a signed
  number — and `scanNumber` claims it here before the operator rules run, so the body is
  two adjacent values with no expression in it. The converse does not hold: `calc(1- 2)`
  is invalid CSS and parses here as a subtraction, because whitespace is discarded and
  nothing downstream can tell it from `calc(1 - 2)`. Documented leniency, in the safe
  direction — it accepts a typo rather than misreading a valid expression.
- **`calcUnterminated` needs *every* closing paren missing.** Drop only calc's own and it
  swallows the outer function's, so `rgb(calc(1 + 1 0 0)` fails as a malformed *body*
  rather than an unterminated call. The genuinely unterminated case is `rgb(calc(1 + 1`,
  which is what a field parsing as you type actually sees. Both are pinned; the test was
  written expecting the first to be the unterminated one, and the failure is what taught
  the distinction.

### M14 — Relative color syntax ✅

Both predicted hook points were exactly where the plan said, and both were the dead ends
it described. `ParsedInput` needed no change after all — it wraps `ParseResult` opaquely
and never inspects the notation, so `ColorInputField.describe` and `notationIsReported()`
were the only consumers.

Four rules carry the milestone, and every one came from the spec rather than from reading
the existing code:

- **Channel keywords are a transcribed table on `ColorSpace`, never derived.** Not from
  `componentLabels`, which is display copy the UI layer may reword freely — today every
  label's first letter *is* the right keyword, which makes the derivation tempting and its
  failure silent, because rewording "Chroma" would make the parser accept
  `oklch(from red l o h)` and reject the spec's spelling. And not from `componentRoles`,
  which genuinely disagrees: XYZ counts as a super-saturated RGB space there and shares
  `(.reds, .greens, .blues)`, but its keywords are `x y z`. This is M12's lesson arriving
  a second time, at a different table.
- **A keyword's value is a `<number>` in its own *function's* written scale.** Which is
  `stored / numberScale`, and the two diverge in exactly one place — `rgb()`, stored 0–1
  and written 0–255. So `rgb()` and `color(srgb …)` disagree on the same space: red's `r`
  is 255 in one and 1 in the other. `ChannelBindings` therefore takes the function *and*
  the space, because neither implies the other — the function fixes the scale, the space
  fixes the spelling and is what the origin converts into.
- **The origin converts with M12's carry-forward.** The spec names CSS Color 4 §13.2
  outright, so this is `convertedForInterpolation(to:)` and not the similar-looking
  `converted(to:)`. Substituting the latter fails exactly the two missing-component tests.
- **`none` means two different things, and both are load-bearing.** Written bare a missing
  channel stays missing; inside a `calc()` the spec reads it as zero. Modelling a channel
  as `Double?` flattens them, which is why `ChannelValue` has two cases. Mutating either
  half fails tests the other does not.

Legacy commas with an origin are a **hard error**, unlike this parser's other comma
leniencies — those parse because the intent is unambiguous, and this one the spec rules
out. `ColorNotation.relative` accordingly carries no `legacy:` flag: there is no such
combination, so the type has nowhere to express it.

An origin is a nested color, so `consumeColor` reads one from the token stream and finds
its closing paren **by depth** — the opposite of `consumeCalc`, whose body cannot nest and
whose first `)` is therefore its own.

**Alpha clamping came out of this milestone and is not part of it.** The spec's relative
section states that alpha is clamped while components are not; measuring showed this
parser clamped neither, and had not since M2. Fixed in `assemble` for *every* syntax
rather than only the relative one, in its own commit — clamping just the relative path
would have made `rgb(0 0 0 / 2)` and `rgb(from black r g b / 2)` disagree for no
reconstructible reason. The asymmetry is the part worth keeping: components must stay
unclamped or an out-of-gamut color could not be written at all, and the "Outside sRGB"
badge exists to report exactly those; alpha has no equivalent story.

**Out of scope, deliberately:** the spec's `alpha()` function, which has its own grammar
row and its own processing-space rule (the *origin's* space, not the output's). Recorded
in the deferred list rather than left implied by a ✅.

### M15 — `color-mix()` ✅

The milestone M12 was written for, and it consumed it exactly as planned: each side goes
through `convertedForInterpolation(to:)` rather than `converted(to:)`. Nothing else was
reusable — `ShadeRamp` interpolates one scalar from one color, `Harmony` rotates a hue,
and `CVDSimulation`'s `lerp` is over matrix coefficients — so
[`Convert/Interpolation.swift`](ColorCore/Convert/Interpolation.swift) is new: the four
hue arcs, the percentage rules, and premultiplied interpolation.

**Both predicted oracle traps were real, and a third rule was not predicted at all.**

1. **`premultiplied: true`**, as planned. colorjs.io's default is not premultiplied and
   CSS is; the default returns `rgb(50% 0% 50%)` where the answer is
   `rgb(33.333% 0% 66.667%)` — a plausible wrong color rather than an error, which is
   what makes it the same class of trap as the WCAG `0.03928`/`0.04045` split.
2. **colorjs.io gamut-maps both endpoints before interpolating** — `range()` calls
   `toGamut()` on each, "to avoid areas of flat color". CSS Color 4 §12 has no such step.
   So for endpoints outside the interpolation space's gamut the oracle is answering a
   *different question*, and the generator skips those combinations (26 of them) rather
   than recording them. ColorCore's answer is pinned from the other side, by a test
   asserting that `color-mix(in srgb, color(display-p3 0 1 0), black)` keeps its negative
   red channel. **This was found by reading the reference's source, not by a failing
   test** — the fixture would simply have encoded the wrong behavior and passed.
3. **Powerless components must be marked missing before interpolating, and that step was
   not in the plan.** It is also the one with the most visible failure: white's OKLCH hue
   is 0° by convention, so `color-mix(in oklch, white, blue)` without it averages 0° and
   264° into 132° and returns a **green**. Marking it gives the light blue anyone expects.
   The ordering M12 recorded still holds — carry-forward first, marking second — and the
   reason it matters is now sharper: *inside* interpolation both kinds of missing behave
   identically (each takes the other color's value), so the order is about not blanking a
   value carry-forward is supposed to preserve.

**Percentages are their own small specification**, and are handled in `MixWeights` rather
than in the parser, so they are testable without a string. Both omitted is 50/50; one
omitted is the complement of the other; both given re-normalize — and if they sum to
*under* 100% the result's alpha is multiplied by the shortfall, so `red 20%, blue 20%` is
an even mix at 0.4 alpha. Over 100% only re-normalizes, because scaling up would hand back
a color more opaque than either input. Both at 0% is invalid, which is the one input with
no answer and hence the failable initializer. A percentage outside `[0, 100]` is
**rejected rather than clamped**, which is the opposite of alpha's rule two milestones
back and deliberately so: an out-of-range alpha has an obvious intention to read, where
`red 150%` has none.

**`color-mix()` is not a `ColorFunction` case**, and that is the shape decision worth
recording. Every member of that enum takes *components*: each has a per-component grammar,
a legacy-comma question and a fixed space. A mix has none of the three, so a case there
would have meant four tables gaining an entry that means nothing. It is a branch at the
top of `parseFunction` — which is what makes nesting free in both directions, since
`consumeColor` routes through the same function — plus a `ColorNotation.mix` case carrying
the interpolation method.

**The space table is *derived*, and that is not a contradiction of M12's and M14's
transcription rule.** Those tables carry facts the identifiers do not: a component's role,
its channel keyword, and which eight of the fourteen spaces `color()` accepts. Every space
is a legal interpolation space and the raw values are the CSS identifiers, so there is
nothing for a derivation to lose. The discriminating question is not "is this a table" but
"can a derivation drop a fact".

**Not compiled, not run — see the status block.** This was built in a Linux container
with no Swift toolchain, so the standard of proof is one step short of every milestone
above it. What is checked: the interpolation algorithm was ported line-for-line back into
JavaScript and run against all 1,760 vectors with zero divergences, and the powerless
verdicts (`isAchromatic` against colorjs.io's `null` hue) were confirmed to agree on every
endpoint and space in the fixture. What is not: that the Swift compiles, and that the
XCUITest added to `TransformSmokeTests` finds its elements.

UI folded into `TransformPanel` as a fifth section. **No eighth `Tool` case** — see the
note in `ContentView`. The second color is the *background*, not a third field of the
panel's own, because the app already edits a pair and a mix needs two colors; the section
says so and points at the contrast tool when there is no background, exactly as the
legibility section below it does. The five-stop strip is the live preview and the amount
slider is the pending edit — the same split as the contrast push, and reset by `apply` for
the same reason, since repeated application converges on the background. The
`color-mix()` expression is printed under the result, which is now something you can paste
back into the field.

### M16 — `@media (color-gamut)` export shape

One `ExportShape` case and one private generator at `ExportOptions.render`: a hex fallback
block, then `@media (color-gamut: p3)` re-declaring the same properties in
`color(display-p3 …)`.

**The shape needs two spellings where `ExportOptions.format` is one value.** Leaving the
panel's format picker live would let a user choose `.oklch` — the default, and unbounded —
filling the "fallback" block with out-of-sRGB values and defeating the point. So
`usesFormat` joins `usesTemplate` and `usesName` as a shape-capability flag and returns
`false` here. The fallback is hex on principle rather than laziness: that block's job is to
be what a browser without P3 support gets, and hex is the most broadly compatible spelling
there is. The override is emitted for every entry, including colors already inside sRGB —
a per-entry conditional would make the media block's contents depend on the palette's
contents, so editing one color would silently change which properties exist.

### M17 — W3C Design Tokens import

Depended on M12, which is done: DTCG `components` accept `"none"`, and a decoded token now
has somewhere honest to put one.

**Checked against the Color Module rather than assumed, and the first assumption was
wrong.** `$value` is an **object** — `{colorSpace, components, alpha?, hex?}`, the first
two required — not a CSS string, so `CSSColorParser` is the wrong entry point and this is
component-based construction. But the payoff is large: the **14 `colorSpace` identifiers
are byte-identical to `ColorSpace`'s raw values**, because both follow CSS Color 4 naming —
the same reason `ColorRecord.spaceID` stores CSS names rather than enum ordering. There is
no mapping table to write; `ColorSpace(rawValue:)` is the decoder, and an unknown space is
skipped exactly as `ColorRecord.colorValue` already skips one. Component ranges are
per-space, so reuse `ColorGrammar.components(for:)`'s `fullScale` rather than writing a
second table. `hex` is a fallback, not the value.

The sandbox already permits it — `ENABLE_USER_SELECTED_FILES = readonly` is set, so
`fileImporter` needs no project change. This would be the app's first file-reading
affordance of any kind. Note that `ColorStore.stage(_:named:)` flips `tool = .export` while
an import should land in **Projects**, so it needs a sibling path rather than a changed one
(`stagingCarriesTheName` pins the existing behavior). And record the honest limitation:
`ExportOptions.cssIdentifier` is lossy, so a name that leaves through export does not
return through import unchanged.

UI lives in `ProjectsPanel`. No eighth `Tool` case.

### M18 — CLI front-end

Last, so it exposes a finished `ColorCore` rather than being revised by every milestone
above. M10 did the hard part; this adds a `com.apple.product-type.tool` target listing only
the `ColorCore` root group, so `internal` still works. It must **not** inherit
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — that is set per-target on the app, so a fresh
target correctly defaults to `nonisolated`.

Every ColorCore file imports `Foundation` and nothing else, which is what makes this cheap.
`ParsedInput` is not part of it — that wrapper lives in `ColorStore.swift`, which is
`@MainActor` and AppKit-bound, so the CLI reimplements that thin orchestration. A
Raycast/Alfred wrapper is then a shell call rather than code.

---

## Verification

**A feature reached through a system loupe or a global chord has links no test can touch**, and they fail independently — so check them separately rather than as one gesture. For M4 that was: (1) does the menu bar show the chord, proving the OS accepted the registration and a scene's `.task` fired; (2) does the chord raise the loupe from *another* app, proving the key is captured and the C callback reaches the main actor; (3) does the picked color reach the field and the clipboard, proving the sandbox and the bridge. All three passed. Everything either side of them is covered by [ScreenSamplerTests](Color%20ToolkitTests/ScreenSamplerTests.swift) and [GlobalHotKeyTests](Color%20ToolkitTests/GlobalHotKeyTests.swift).

Per milestone:

- **M1/M2 (core):** `xcodebuild test` — parameterized tests against the colorjs.io fixture; round-trip idempotency; gamut-mapping boundary cases (`L≥1` → white, `L≤0` → black, in-gamut colors unchanged).
- **M5:** two different standards of proof, because the oracle only covers one of them. **APCA** is validated against colorjs.io directly (`node Tools/generate-contrast-fixtures.mjs`) at 1e-9, both polarities — real external validation, since the Swift is transcribed from that package. **WCAG** cannot be, because colorjs.io implements a different definition; correctness there comes from anchors that hold under any variant (`#000` on `#fff` = 21:1, a color against itself = 1:1) plus one pair chosen to *disagree* between the definitions, asserted both ways round.
- **M6:** the plane is a `Canvas`, so nothing about the pixels reaches the accessibility tree — the numeric readout is the assertable surface, and the boundary figures it prints were checked against the oracle from the panel's own screenshots. See [PickerSmokeTests](Color%20ToolkitUITests/PickerSmokeTests.swift).
- **M7:** the transforms have no oracle, so ColorCore asserts their defining properties and every load-bearing one was confirmed by mutation (see the milestone above). What *can* be cross-checked is the pipeline end to end, and was: the OKLCH string the panel wrote after adopting a triad member agrees with colorjs.io to ten decimals. See [TransformSmokeTests](Color%20ToolkitUITests/TransformSmokeTests.swift), where each derived swatch is a button labelled with its own CSS — the only handle a test has on a row of colored rectangles, and the thing a bare swatch owes VoiceOver anyway.
- **M8:** the only milestone whose output is *text a machine will read*, so the parser is the oracle — [ExportTests](Color%20ToolkitTests/ExportTests.swift) round-trips every exportable format back through `CSSColorParser` and requires the color to survive. Syntax is pinned with exact strings, and the identifier rules (JavaScript key quoting, CSS sanitizing) have their own parameterized cases, because a config that will not load is the failure mode and it is invisible from inside Swift. The source-to-entries mapping is asserted on `ColorStore` rather than through the UI — see [ExportStoreTests](Color%20ToolkitTests/ExportStoreTests.swift) — which is why that mapping lives on the store. [ExportSmokeTests](Color%20ToolkitUITests/ExportSmokeTests.swift) covers only what a running app can show: that the controls reach the document. It never clicks Copy, for the reason no test here touches the pasteboard.
- **M9:** three levels, split on what each can actually answer. [ColorRecordTests](Color%20ToolkitTests/ColorRecordTests.swift) takes the mapping with no container in sight — every space, the `none` mask, and the stored components agreeing with the stored spelling. [ProjectStoreTests](Color%20ToolkitTests/ProjectStoreTests.swift) takes what only SwiftData can answer, opening with the assertion that the container builds at all, because inverses are resolved there rather than at compile time. [ProjectsSmokeTests](Color%20ToolkitUITests/ProjectsSmokeTests.swift) takes the round trip through a running app — and launches every one with `UITestInMemoryStore`, because the alternative is writing into the real library. The end-to-end cross-check is the ramp in the status note: saved, reloaded, exported, and identical to the value M8 checked against colorjs.io.
- **M10:** the milestone has no behavior to test, so the test suite proves nothing beyond "still compiles". The real check is that **re-running all four generators reproduces every generated Swift file byte-for-byte** — that is what shows the output paths moved with the sources rather than quietly writing somewhere stale. (`cvd-vectors.json` is the exception and stays as committed; see the libm note in CLAUDE.md.)
- **M11:** the store rules are in [ProjectStoreTests](Color%20ToolkitTests/ProjectStoreTests.swift), each confirmed against a mutation of the rule it covers — dropping the move's offset discount, skipping the dense renumber, disabling key dedup, re-deriving stored text, and moving colors instead of copying them all fail the suite. Reordering is checked across a real store close and reopen, since an in-memory container proves only that the objects in hand were mutated. [ProjectsSmokeTests](Color%20ToolkitUITests/ProjectsSmokeTests.swift) covers the wiring — **through the menu commands, not the drag**, because XCUITest cannot start a dragging session and a drag-driven test would fail whether the feature worked or not. **The drag gesture itself is not covered by any automated test and wants a human to try it once.**
- **M12:** [MissingComponentTests](Color%20ToolkitTests/MissingComponentTests.swift), and the standard of proof is the spec rather than a reference implementation — colorjs.io resolves `none` on conversion, so it cannot answer this at all. Each test names the spec example or role-table property it encodes, and all five load-bearing rules were confirmed by mutation (see the milestone). The spec's *printed* conversions are asserted as roundings, not with a tolerance, because that is the claim actually available from a displayed figure.
- **M13:** [CalcTests](Color%20ToolkitTests/CalcTests.swift), hand-written throughout because there is no oracle — colorjs.io rejects `rgb(calc(10 + 20) 0 0)` outright with "Expected 3 coordinates … got 5", so `parse-vectors.json` is untouched. The arithmetic is checkable by inspection; what is not obvious from reading the code is pinned by five mutations, each failing only what it should. Stripping precedence fails one test, dropping the `±` type check one, ignoring leftover tokens two, and hoisting the tokenizer's operator rules above the number scanner fails the *curated fixture* — `rgb(+128 0 0)` — plus the numeric-edge-forms test. The fifth is the discriminating one: letting a calc body's slash escape to separator logic fails every test whose input contains a slash and **no test without one**, which is the sharpest available statement that consuming the body as a unit is what resolves the ambiguity. A first, blunter version of that mutation (not consuming the body at all) failed fifteen tests and proved nothing except that the feature was off. A sixth mutation covers the seam the other five do not touch: dropping `min` from `UnsupportedFunctions.names` makes `rgb(calc(min(1, 2) * 2) 0 0)` come back `calcUnsupportedSyntax("min(")` instead of naming the function, which is the observable proof that the pre-tokenize check still runs *before* calc consumption. `firstCalled` scans its own list rather than the input, so the case is checked with a first-listed name (`var`) and a later one (`min`) both.
- **M14:** [RelativeColorTests](Color%20ToolkitTests/RelativeColorTests.swift), hand-written for a *third* distinct no-oracle reason — colorjs.io 0.7.0 has no relative color syntax at all, so every form comes back "Expected 3 coordinates … got 4". (M13's reason was that it rejects `calc()`; M12's was that it resolves `none` on conversion and so cannot be asked the question.) The conversions underneath are oracle-validated already and are deliberately not re-tested. **Eight mutations, and the most useful one passed.** Seven failed exactly what they should — deriving the keyword table from roles, ignoring `numberScale`, dropping carry-forward, collapsing either half of the `none` rule, allowing legacy commas, and removing the alpha clamp. The eighth, replacing the origin's depth counting with "first close paren wins", **passed the entire suite**, which is the finding worth carrying: *a mutation that survives means the test set is incomplete, not that the rule is safe.* The obvious nesting cases do not discriminate — in `rgb(from color(display-p3 1 0 0) r g b)` the first `)` already is the right one, and `rgb(from rgb(from red r g b) r g b)` is still one level deep because `from red` opens nothing. Depth counting only earns its keep when the origin's function contains another function, so a case was added for the cheapest one, a `calc()` inside the origin, and the mutation now fails with `wrongComponentCount(got: 1)`. Two assertions are deliberately loose and say so in place: white's OKLab lightness is `1.0000000000000002` and an sRGB → OKLCh → sRGB round trip returns red as the same, so both claims are checked by discrimination — the competing readings are off by ~100× and ~1 — rather than by an equality the conversion never promised.
- **M15:** [ColorMixTests](Color%20ToolkitTests/ColorMixTests.swift), split on what each half can be held to. The **numbers** are generated — 1,760 vectors over fifteen color pairs, all fourteen interpolation spaces, four hue arcs and five positions along each mix — with the two oracle corrections above baked into the generator. The **grammar and the percentage rules** are hand-written, because colorjs.io can compute a mix and cannot parse one, which is the fourth distinct no-oracle reason this plan has recorded. Three assertions carry more than their length suggests: `null` in a recorded component is checked against our *missing mask* rather than against a number, which is a claim about §12.2's substitution rather than about arithmetic; the hue-arc test runs the same pair in both directions, because for any pair the four methods only ever produce two answers and it is *which method gets which* that proves direction is honoured rather than length; and the premultiplication case is stated as the wrong answer it discriminates against, `rgb(50% 0% 50%)` versus `rgb(33.3% 0% 66.7%)`. The tolerance is 1e-8 rather than the conversions' 1e-9, and says why in place: un-premultiplying divides by an interpolated alpha as low as 0.1, multiplying any upstream difference by up to ten. **None of it has been run** — see the status block — so the algorithm's proof is the JavaScript mirror, and the Swift's proof is still owed.
- **M3/M4 (UI):** run the app and verify interactively. Spot-check conversions against a browser's DevTools color picker, which implements the same spec — a fast, honest end-to-end sanity check.

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

**Most of what stood here is now planned as M10–M18 above**, with the decisions that were
open at the time settled: `@media (color-gamut)` is an export shape rather than display
detection (there is no `NSScreen` usage anywhere in the app, and the badge's meaning is not
worth changing); palette import reads **W3C Design Tokens** rather than Figma's Variables
API or Tokens Studio; `ColorCore` moved to a repo-root group rather than becoming an SPM
package; and `calc()` is scoped to flat arithmetic over numbers, percentages and angles.

What remains genuinely deferred:

- **Saving to a file** rather than the clipboard — still M8b above, still standing on its
  own reasons.
- **Full `calc()`**: arbitrary nesting, parenthesized sub-expressions, `min()`/`max()`/
  `clamp()`. M13 deliberately stops short and now says so in its own errors rather than
  failing with a raw tokenizer complaint — `calc((1 + 2) * 3)` and `calc(1 + calc(2))`
  each name what is outside the subset. Going further wants real precedence climbing over
  a paren depth, at which point the flat two-level grammar in `CalcExpression` is replaced
  rather than extended. Also worth revisiting then: M13's `±` type rules are narrower than
  CSS Values 4, deliberately, and loosening them is a separate decision from nesting.
- **`var()` and `env()`** in parsing. Unlike `calc()`, these cannot be resolved from the
  string alone — they need a cascade the app does not have and should not invent.
- **The `alpha()` function** from CSS Color 5, which M14 scoped out. It has its own
  grammar row and, unlike every other relative form, its processing space is the
  *origin's* rather than the output's — so it is a genuinely separate rule and not one
  more case in the same switch.
- **Figma Variables API and Tokens Studio import.** M17 covers the vendor-neutral format;
  these are two more parsers with materially different shapes, worth adding only if a real
  file arrives that needs one.
- **Display-gamut detection** (`NSScreen.colorSpace`) driving the "mapped" badge. A
  different feature from M16 that happened to share its name.

*Note for later:* the APCA algorithm has carried usage/attribution terms. Irrelevant for personal use, but worth checking before ever distributing the app publicly.
