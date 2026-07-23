# Color Toolkit — Implementation Plan

> **Status (2026-07-23): M0–M3 built and reviewed.** 137 test cases green.
> ColorCore is validated against **colorjs.io 0.7.0** (pinned exact) — 6,384
> conversions and 1,368 gamut mappings — plus independent definitional anchors. The
> CSS parser, serializer, and app shell are done. Next up: **M4 (eyedropper + global
> hotkey)**.
>
> The UI has now been seen, and two things came out of it — a fix to how precision
> works, and the note on orphaned instances under **Running the app** below.
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

## Context

The goal is a native macOS app that serves as a personal, one-stop color toolkit for daily web development: parse and convert every CSS Color 4 format, check accessibility, transform colors, generate harmonies and ramps, export as CSS, and save collections into projects. Scope is expected to grow over time, so this plan optimizes for a **trustworthy core with a stable API** that features can be layered onto indefinitely, rather than a one-shot build.

The single thing that determines whether this tool is worth relying on is **conversion accuracy**. Most color tools are approximately correct — they use blog-post matrices, ignore the D50/D65 distinction between `lab()` and `oklab()`, and clip out-of-gamut colors instead of gamut-mapping them. The plan therefore front-loads a pure, dependency-free color core validated against reference test vectors before any UI is written.

### Current state

M0–M3 are built. The stock SwiftData template (`Item.swift`, the `NavigationSplitView` list) is gone; what stands now is:

| Layer | Files |
|---|---|
| Core model | [ColorValue.swift](Color%20Toolkit/ColorCore/ColorValue.swift), [ColorSpace.swift](Color%20Toolkit/ColorCore/ColorSpace.swift) |
| Spaces | [Matrices.swift](Color%20Toolkit/ColorCore/Spaces/Matrices.swift) and [NamedColors.swift](Color%20Toolkit/ColorCore/Spaces/NamedColors.swift) (**generated**), [TransferFunctions.swift](Color%20Toolkit/ColorCore/Spaces/TransferFunctions.swift), [ColorMatrix.swift](Color%20Toolkit/ColorCore/Spaces/ColorMatrix.swift) |
| Convert | [Conversion.swift](Color%20Toolkit/ColorCore/Convert/Conversion.swift), [GamutMapping.swift](Color%20Toolkit/ColorCore/Convert/GamutMapping.swift) |
| Parse | [CSSTokenizer.swift](Color%20Toolkit/ColorCore/Parse/CSSTokenizer.swift), [ColorSyntax.swift](Color%20Toolkit/ColorCore/Parse/ColorSyntax.swift), [CSSColorParser.swift](Color%20Toolkit/ColorCore/Parse/CSSColorParser.swift) |
| Format | [CSSFormatter.swift](Color%20Toolkit/ColorCore/Format/CSSFormatter.swift), [FormatCatalog.swift](Color%20Toolkit/ColorCore/Format/FormatCatalog.swift) |
| Shell | [ColorStore.swift](Color%20Toolkit/Features/Shell/ColorStore.swift), [MenuBarPanel.swift](Color%20Toolkit/Features/Shell/MenuBarPanel.swift), [ContentView.swift](Color%20Toolkit/ContentView.swift) |
| Conversion UI | [ColorInputField.swift](Color%20Toolkit/Features/Conversion/ColorInputField.swift), [ConversionPanel.swift](Color%20Toolkit/Features/Conversion/ConversionPanel.swift), [FormatPresentation.swift](Color%20Toolkit/Features/Conversion/FormatPresentation.swift) |
| Design system | [ColorSwatch.swift](Color%20Toolkit/DesignSystem/ColorSwatch.swift), [ColorValue+SwiftUI.swift](Color%20Toolkit/DesignSystem/ColorValue+SwiftUI.swift) |
| Services | [Clipboard.swift](Color%20Toolkit/Services/Clipboard.swift) |

`ColorCore/Analysis/`, `ColorCore/Transform/`, and `Persistence/` exist as empty folders awaiting M5, M7, and M9.

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

*Built, but see the UI caveat at the top — nothing has visually verified it.*

### M4 — Eyedropper + global hotkey

- **Eyedropper:** `NSColorSampler.sample()`. Sandbox-safe, no permission prompt.
  - *Caveat to handle explicitly:* the returned `NSColor` is in the **display's** color space. On a P3 display, naively calling `usingColorSpace(.sRGB)` clips wide-gamut pixels. Read in Display P3 / extended sRGB and let the user choose the interpretation — for an accuracy tool this is a feature, not a detail.
- **Global hotkey:** use Carbon `RegisterEventHotKey`. It works in a sandboxed app **without** any permission prompt, whereas `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` requires the user to grant Input Monitoring/Accessibility in System Settings. A `MenuBarExtra` keyboard shortcut alone only fires when the app is frontmost, which defeats the purpose.
  - *Budget concurrency time here.* This is the one spot where Swift 6 strict concurrency costs real effort: Carbon's event handler is a C callback with a context pointer and no async boundary, so getting it back onto `@MainActor` safely takes care. `NSColorSampler`'s completion handler is main-actor too. Isolate both behind a small `Sendable` service facade so the friction stays in one file.

Sampled colors land in [ColorStore](Color%20Toolkit/Features/Shell/ColorStore.swift) via `adopt(_:as:)`, which already exists for exactly this.

### M5 — Accessibility

- **WCAG 2.2:** relative luminance (`0.2126R + 0.7152G + 0.0722B` on linearized sRGB), ratio `(L₁+0.05)/(L₂+0.05)`. Use WCAG's linearization threshold **`0.03928`**, not sRGB's `0.04045` — a known spec discrepancy; matching WCAG is what makes results agree with compliance tools. Report AA/AAA × normal/large, plus the 3:1 non-text threshold (1.4.11).
- **APCA:** the W3-published algorithm. Note it is **polarity-dependent** (dark-on-light ≠ light-on-dark) and returns a signed `Lc`; pair with the font-size/weight lookup table.
- **CVD simulation:** Machado et al. (2009) severity-parameterized LMS matrices for protan/deutan/tritan, applied as a live preview filter over any swatch or palette.

### M6 — Full-spectrum picker

Its own milestone — a gamut-aware perceptual picker is substantial work. Canvas-rendered, with **two modes**: a familiar HSV square+hue-strip, and an **OKLCH mode** (L/C/h) that draws the sRGB gamut boundary so it's visible when chroma is being clipped. Alpha slider over a checkerboard.

### M7 — Transform + harmony tools

All computed in **OKLCH** for perceptual evenness. Every tool follows one pattern: *view → operates on a `ColorValue` → emits a `ColorValue` or `[ColorValue]` → feeds the shared export sheet.* Adding a tool later means one file, no plumbing.

- Lightness / saturation (chroma) / hue adjustment
- **Contrast — two separate tools**, per your answer:
  - *Paired solver:* pin a second color, slide to push apart/together with the live WCAG ratio, plus auto-fix ("nearest color hitting 4.5:1")
  - *S-curve:* standalone punchiness around mid-gray, no second color
- Harmonies: complementary (h+180), split-complementary (h±150/210), triad (h±120), tetrad (h+90/180/270), analogous (h±30, configurable), monochromatic
- **Shade ramp** (chosen color as the middle stop): *a naive constant-chroma lightness ramp pushes the light and dark ends out of gamut.* Taper chroma toward the extremes and gamut-map every step — this is exactly what makes Tailwind-style ramps look right.

### M8 — Export

Template-driven: `color`, `background-color`, `border`, `outline`, `box-shadow`, `text-shadow`, `fill`/`stroke`, plus custom-property blocks. Applies to a single color or a whole palette. Output-format picker (hex / rgb / hsl / oklch / …) and precision control. Also JSON and Tailwind config export.

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

**Do this first, before building picker UI on top of it:** empirically confirm `NSColorSampler` works under the sandbox on this machine — a throwaway button calling `sample()`, verifying no permission prompt appears and that a known on-screen pixel returns the expected value on both an sRGB and a P3 display. Everything in M4 depends on that assumption holding.

Per milestone:

- **M1/M2 (core):** `xcodebuild test` — parameterized tests against the colorjs.io fixture; round-trip idempotency; gamut-mapping boundary cases (`L≥1` → white, `L≤0` → black, in-gamut colors unchanged).
- **M5:** assert known pairs against published values — e.g. `#000` on `#fff` = 21:1, and WCAG's own worked examples. APCA against the reference implementation's test table.
- **M3/M4/M6–M9 (UI):** run the app and verify interactively. Spot-check conversions against a browser's DevTools color picker, which implements the same spec — a fast, honest end-to-end sanity check.

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

### Commit discipline

Commits follow milestone seams, and **each one must build and test on its own** — a green suite at HEAD says nothing about whether an intermediate commit is bisectable. Verify in a throwaway worktree with isolated DerivedData before stacking the next commit on top:

```bash
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt && xcodebuild -project "Color Toolkit.xcodeproj" -scheme "Color Toolkit" -destination 'platform=macOS' -derivedDataPath /tmp/dd test
```

## Deferred (worth revisiting)

Relative color syntax (`rgb(from …)`), `calc()` in parsing, full `none`/powerless-component semantics, color interpolation & mixing (`color-mix()`), CSS `@media (color-gamut)` awareness, Raycast/Alfred or CLI front-end reusing `ColorCore`, palette import from Figma/Tailwind configs.

*Note for later:* the APCA algorithm has carried usage/attribution terms. Irrelevant for personal use, but worth checking before ever distributing the app publicly.
