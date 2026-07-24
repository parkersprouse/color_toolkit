//
//  PickerPanel.swift
//  Color Toolkit
//

import SwiftUI

/// Choosing a color by eye instead of by typing one.
///
/// Two sets of axes over the same plane. **HSV** is the square every design tool
/// shows, and it is here because muscle memory is worth more than novelty. **OKLCH**
/// is the one this app exists to offer: perceptually even, and with the sRGB edge
/// drawn on the plane so the moment a color stops being expressible on the web is
/// visible rather than inferred from a badge after the fact.
///
/// The panel writes to the shared field on every change and reads back only when
/// something else has written there — see ``PickerState/syncing(with:color:)`` for why
/// the two directions cannot be the same code path.
struct PickerPanel: View {
    @Environment(ColorStore.self) private var store

    @State private var state = PickerState()
    @State private var plane: PickerPlane?
    @State private var strip: CGImage?
    @State private var planeSide: CGFloat = 320
    @State private var planeRender: Task<PickerPlane?, Never>?
    @State private var stripRender: Task<CGImage?, Never>?
    @State private var rememberSoon: Task<Void, Never>?

    /// What the plane's pixels depend on. Only a change here is worth re-rendering
    /// sixty thousand conversions for — moving the cursor around a plane does not
    /// change the plane.
    private struct PlaneKey: Equatable {
        let mode: PickerMode
        let hue: Double
    }

    /// The strip shows hues *at the current position*, so it follows the cursor. It is
    /// one-dimensional and correspondingly cheap.
    private struct StripKey: Equatable {
        let mode: PickerMode
        let first: Double
        let second: Double
    }

    private var planeKey: PlaneKey {
        PlaneKey(mode: state.mode, hue: state.mode == .hsv ? state.hsvHue : state.oklchHue)
    }

    private var stripKey: StripKey {
        switch state.mode {
        case .hsv: StripKey(mode: .hsv, first: state.saturation, second: state.value)
        case .oklch: StripKey(mode: .oklch, first: state.lightness, second: state.chroma)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modeSwitcher
                planeAndStrip
                alphaSlider
                readout
            }
            .padding(16)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                planeSide = squareSide(forPanelWidth: width)
            }
        }
        .task { seedFromStore() }
        .onChange(of: store.inputText) { state.syncing(with: store.inputText, color: store.color) }
        // `.task(id:)` restarts when the id moves, which discards the stale result.
        // Stopping the *work* takes an explicit cancel — see `renderPlane()`.
        .task(id: planeKey) { await renderPlane() }
        .task(id: stripKey) { await renderStrip() }
    }

    // MARK: - Mode

    private var modeSwitcher: some View {
        Picker(
            "Axes",
            selection: Binding(
                get: { state.mode },
                // The field's color, not the panel's: see ``PickerState/setMode(_:carrying:)``.
                // Switching tabs deliberately does not *write* — looking at a color in
                // other axes is not editing it, and rewriting `#3b82f6` as `oklch(…)`
                // for having glanced at the OKLCH tab would be presumptuous.
                set: { newMode in
                    state.setMode(newMode, carrying: store.color)
                    store.pickerMode = newMode
                }
            )
        ) {
            ForEach(PickerMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("pickerMode")
    }

    // MARK: - Plane

    /// The row's height is set from the panel's **width**, never inferred from the
    /// space available.
    ///
    /// The plane is a `GeometryReader` inside a `ScrollView`, which proposes unbounded
    /// height — so a square asked to fit that proposal takes all of it, and the window
    /// opens nearly a thousand points tall. Worse, the resize that follows moves
    /// controls out from under a click that was already on its way. Width is bounded,
    /// measuring it cannot feed back into itself, and a square is as wide as it is
    /// tall — so width is the one dimension worth asking about.
    private func squareSide(forPanelWidth width: CGFloat) -> CGFloat {
        // Panel padding, the strip, and the gap between them.
        min(max(width - 72, 240), 460)
    }

    private var planeAndStrip: some View {
        HStack(alignment: .top, spacing: 12) {
            planeView
            stripView
        }
        .frame(height: planeSide)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planeView: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                if let plane {
                    Image(decorative: plane.image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Rectangle().fill(.quaternary)
                }

                Canvas { context, canvasSize in
                    if state.mode == .oklch, let plane, plane.rows > 1 {
                        // Dashed first so the solid sRGB line wins where they overlap
                        // at the pinched ends.
                        strokeEdge(
                            plane.displayEdge, in: canvasSize, context: &context,
                            dash: [4, 3], width: 1
                        )
                        strokeEdge(plane.srgbEdge, in: canvasSize, context: &context, width: 1.5)
                    }
                    drawCursor(in: canvasSize, context: &context)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { moveCursor(to: $0.location, in: size) }
                    // Never mid-drag, and not even on release — see
                    // `rememberWhenSettled()`. A drag crosses hundreds of colors on the
                    // way to the one that was wanted.
                    .onEnded { _ in rememberWhenSettled() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        // One element rather than a container: a plane has no children worth landing
        // on, and XCUITest cannot drag something that is not an element.
        .accessibilityElement()
        .accessibilityIdentifier("pickerPlane")
        .accessibilityLabel(state.mode == .hsv ? "Saturation and value" : "Chroma and lightness")
    }

    /// Two passes: a dark line under a light one, so the curve stays visible whether it
    /// crosses a pale yellow or a deep blue. A single stroke in either color disappears
    /// somewhere along its own length.
    private func strokeEdge(
        _ edge: [Double],
        in size: CGSize,
        context: inout GraphicsContext,
        dash: [CGFloat] = [],
        width: CGFloat
    ) {
        guard edge.count > 1 else { return }

        var path = Path()
        for (row, chroma) in edge.enumerated() {
            let point = CGPoint(
                x: CGFloat(chroma / PickerState.chromaAxisMaximum) * size.width,
                y: CGFloat(row) / CGFloat(edge.count - 1) * size.height
            )
            if row == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        let style = StrokeStyle(lineWidth: width + 1.5, lineCap: .round, dash: dash)
        context.stroke(path, with: .color(.black.opacity(0.45)), style: style)
        context.stroke(
            path,
            with: .color(.white.opacity(0.95)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash)
        )
    }

    private func drawCursor(in size: CGSize, context: inout GraphicsContext) {
        let position = CGPoint(
            x: cursorFraction.x * size.width,
            y: cursorFraction.y * size.height
        )
        let ring = Path(ellipseIn: CGRect(x: position.x - 7, y: position.y - 7, width: 14, height: 14))
        context.stroke(ring, with: .color(.black.opacity(0.55)), lineWidth: 3)
        context.stroke(ring, with: .color(.white), lineWidth: 1.5)
    }

    /// Where the cursor sits, as a fraction of the plane.
    ///
    /// Clamped, because a typed color can be off the plane entirely — `oklch(0.7 0.5
    /// 30)` has more chroma than the axis carries. Parking the ring on the edge is
    /// better than drawing it out of bounds, and the readout below states the real
    /// number either way.
    private var cursorFraction: CGPoint {
        switch state.mode {
        case .hsv:
            CGPoint(x: state.saturation / 100, y: 1 - state.value / 100)
        case .oklch:
            CGPoint(
                x: min(state.chroma / PickerState.chromaAxisMaximum, 1),
                y: 1 - min(max(state.lightness, 0), 1)
            )
        }
    }

    private func moveCursor(to point: CGPoint, in size: CGSize) {
        let x = clampedFraction(point.x, over: size.width)
        let y = clampedFraction(point.y, over: size.height)

        apply { state in
            switch state.mode {
            case .hsv:
                state.saturation = x * 100
                state.value = (1 - y) * 100
            case .oklch:
                state.chroma = x * PickerState.chromaAxisMaximum
                state.lightness = 1 - y
            }
        }
    }

    // MARK: - Hue strip

    private var stripView: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                if let strip {
                    Image(decorative: strip, scale: 1)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Rectangle().fill(.quaternary)
                }

                Canvas { context, canvasSize in
                    let y = CGFloat(currentHue / 360) * canvasSize.height
                    let marker = Path(
                        roundedRect: CGRect(x: -1, y: y - 3, width: canvasSize.width + 2, height: 6),
                        cornerRadius: 3
                    )
                    context.stroke(marker, with: .color(.black.opacity(0.55)), lineWidth: 3)
                    context.stroke(marker, with: .color(.white), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = clampedFraction(value.location.y, over: size.height)
                        apply { state in
                            switch state.mode {
                            case .hsv: state.hsvHue = fraction * 360
                            case .oklch: state.oklchHue = fraction * 360
                            }
                        }
                    }
                    .onEnded { _ in rememberWhenSettled() }
            )
        }
        .frame(width: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .accessibilityElement()
        .accessibilityIdentifier("pickerHue")
        .accessibilityLabel("Hue")
    }

    private var currentHue: Double {
        state.mode == .hsv ? state.hsvHue : state.oklchHue
    }

    // MARK: - Alpha

    private var alphaSlider: some View {
        let opaque = ColorValue(
            space: state.color.space,
            components: state.color.components,
            alpha: 1
        )

        return GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Checkerboard(squareSize: 6)
                LinearGradient(
                    colors: [opaque.displayColor.opacity(0), opaque.displayColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                Canvas { context, canvasSize in
                    let x = CGFloat(state.alpha) * canvasSize.width
                    let marker = Path(
                        roundedRect: CGRect(x: x - 3, y: -1, width: 6, height: canvasSize.height + 2),
                        cornerRadius: 3
                    )
                    context.stroke(marker, with: .color(.black.opacity(0.55)), lineWidth: 3)
                    context.stroke(marker, with: .color(.white), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = clampedFraction(value.location.x, over: size.width)
                        apply { $0.alpha = fraction }
                    }
                    .onEnded { _ in rememberWhenSettled() }
            )
        }
        .frame(height: 24)
        .clipShape(Capsule())
        .overlay { Capsule().strokeBorder(.separator, lineWidth: 1) }
        .accessibilityElement()
        .accessibilityIdentifier("pickerAlpha")
        .accessibilityLabel("Alpha")
    }

    // MARK: - Readout

    /// The numbers behind the cursor.
    ///
    /// Not redundant with the field above, which shows one CSS string: HSV has no CSS
    /// spelling at all, and in OKLCH mode the chroma still available at this lightness
    /// and hue is the panel's actual payload — it is what turns "this looks vivid" into
    /// "this is 0.19 of a possible 0.21".
    @ViewBuilder
    private var readout: some View {
        switch state.mode {
        case .hsv:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 18) {
                    figure("H", String(format: "%.1f°", state.hsvHue), id: "readoutFirst")
                    figure("S", String(format: "%.1f%%", state.saturation), id: "readoutSecond")
                    figure("V", String(format: "%.1f%%", state.value), id: "readoutThird")
                    figure("A", String(format: "%.2f", state.alpha), id: "readoutAlpha")
                    Spacer()
                }

                // Keyed off the *field's* color rather than the panel's, because in
                // this mode they can differ: HSV has no way to hold a wide color, so
                // the square shows the nearest one it can. Saying so is the same move
                // the conversion panel makes when it badges a mapped row — show the
                // closest honest thing, and admit the compromise beside it.
                if store.color?.exceedsSRGB == true {
                    HStack(spacing: 10) {
                        ColorBadge(text: "Outside sRGB")
                        Text("HSV describes the sRGB cube, so the square is showing the nearest color it can hold. Switch to OKLCH to keep the original.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        case .oklch:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 18) {
                    figure("L", String(format: "%.4f", state.lightness), id: "readoutFirst")
                    figure("C", String(format: "%.4f", state.chroma), id: "readoutSecond")
                    figure("H", String(format: "%.1f°", state.oklchHue), id: "readoutThird")
                    figure("A", String(format: "%.2f", state.alpha), id: "readoutAlpha")
                    Spacer()
                }
                gamutLine
            }
        }
    }

    private func figure(_ label: String, _ value: String, id: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))
                // Nothing in this app is dimmer than secondary — the rule the contrast
                // panel set, applied everywhere since.
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .accessibilityIdentifier(id)
        }
    }

    private var gamutLine: some View {
        let available = GamutBoundary.maxChroma(
            lightness: state.lightness,
            hue: state.oklchHue,
            in: .srgb
        )

        return HStack(spacing: 10) {
            Text(String(format: "sRGB allows %.4f here", available))
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("readoutLimit")

            if state.color.exceedsSRGB {
                ColorBadge(text: "Outside sRGB")
            }

            Spacer()
        }
    }

    // MARK: - Plumbing

    /// Every axis change goes through here: mutate, then push the result to the field.
    private func apply(_ change: (inout PickerState) -> Void) {
        change(&state)
        store.inputText = state.cssToWrite()
    }

    /// Re-entering the tool rebuilds this panel's `@State` from scratch, which is right
    /// for the axes — the field's color may have moved while the tool was away — and
    /// wrong for the mode, which is a preference rather than a view of anything. So the
    /// axes come from the color and the mode comes from the store.
    private func seedFromStore() {
        if let color = store.color { state.seed(from: color) }
        state.setMode(store.pickerMode, carrying: store.color)
    }

    private func clampedFraction(_ position: CGFloat, over extent: CGFloat) -> Double {
        guard extent > 0 else { return 0 }
        return min(max(Double(position / extent), 0), 1)
    }

    /// Renders off the main actor, and **cancels the render it replaces**.
    ///
    /// The cancellation has to be explicit. A detached task does not inherit its
    /// parent's — that is what "detached" means — so `.task(id:)` tearing down the
    /// wrapper leaves the render itself running to completion on a background thread.
    /// Dropping its stale result afterwards would still look correct and would still
    /// burn a full plane's worth of conversions per frame of a hue drag.
    private func renderPlane() async {
        let snapshot = state
        planeRender?.cancel()
        let render = Task.detached(priority: .userInitiated) {
            PickerPlaneRenderer.plane(mode: snapshot.mode, state: snapshot)
        }
        planeRender = render

        let rendered = await render.value
        guard !Task.isCancelled, let rendered else { return }
        plane = rendered
    }

    private func renderStrip() async {
        let snapshot = state
        stripRender?.cancel()
        let render = Task.detached(priority: .userInitiated) {
            PickerPlaneRenderer.hueStrip(mode: snapshot.mode, state: snapshot)
        }
        stripRender = render

        let rendered = await render.value
        guard !Task.isCancelled, let rendered else { return }
        strip = rendered
    }

    /// Files the current color under recents once the user has stopped moving.
    ///
    /// Three controls feed this — plane, strip, alpha — and dialing in one color
    /// touches all three. Filing on each release would deposit three *different*
    /// way-points, which is the same noise the store avoids by not remembering on every
    /// keystroke: the colors between `#f` and `#f0a` are not colors anyone chose.
    /// Waiting for the movement to stop files the one that was.
    private func rememberWhenSettled() {
        rememberSoon?.cancel()
        rememberSoon = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            store.remember()
        }
    }
}

#Preview {
    PickerPanel()
        .environment(ColorStore(initialInput: "oklch(0.62 0.19 260)"))
        .frame(width: 520, height: 520)
}
