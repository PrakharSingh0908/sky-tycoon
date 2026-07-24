//
//  Components.swift
//  SkyTycoon — Design system component library (DESIGN_SYSTEM.md §3)
//
//  Dumb, reusable pieces. Components take plain values — never the engine —
//  so they stay previewable and portable.
//

import SwiftUI

// ── GameCard — the universal surface ─────────────────────────────────────

struct GameCard<Content: View>: View {
    /// v2.1: borders are hierarchy. A highlight color adds a gradient
    /// hairline + tinted glow — reserved for the FEW surfaces that deserve
    /// attention (hero, event, celebration). Nil = the ordinary borderless card.
    var highlight: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        // Blueprint: carbon panel, 8px, flat — separation is tone, never
        // shadow. A highlight adds the accent hairline (active state).
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner)
                .strokeBorder(highlight == nil ? Color.clear : Theme.cornflower.opacity(0.8),
                              lineWidth: 1))
    }
}

/// Gradient mask fading one edge — the soft cut for scrolling or collapsed
/// content (v2.1: gradients only ever shade existing geometry).
/// A soft fade at one edge — used to hint that a row scrolls. It is drawn
/// as a NON-INTERACTIVE overlay in the surface color, NOT a `.mask`: a mask
/// clips hit-testing as well as rendering, which silently kills any control
/// living under the faded strip (GDD §31 — the Service button was the
/// trailing-most chip and stopped responding). This version fades the look
/// without ever eating a tap.
struct FadeEdgeModifier: ViewModifier {
    var edge: Edge = .bottom
    var length: CGFloat = 24
    /// The surface the content sits on, so the fade dissolves INTO it.
    var color: Color = Theme.card

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            LinearGradient(colors: colors, startPoint: start, endPoint: end)
                .frame(width: isHorizontal ? length : nil,
                       height: isHorizontal ? nil : length)
                .allowsHitTesting(false)   // the whole point: never gate touches
        }
    }

    private var isHorizontal: Bool { edge == .leading || edge == .trailing }
    private var alignment: Alignment {
        switch edge {
        case .top: .top; case .bottom: .bottom
        case .leading: .leading; case .trailing: .trailing
        }
    }
    private var colors: [Color] {
        switch edge {
        case .top, .leading: [color, .clear]
        case .bottom, .trailing: [.clear, color]
        }
    }
    private var start: UnitPoint { isHorizontal ? .leading : .top }
    private var end: UnitPoint { isHorizontal ? .trailing : .bottom }
}

extension View {
    func fadeEdge(_ edge: Edge = .bottom, length: CGFloat = 24,
                  color: Color = Theme.card) -> some View {
        modifier(FadeEdgeModifier(edge: edge, length: length, color: color))
    }
}

// ── TicketShape — boarding-pass silhouette (DESIGN_SYSTEM.md v1.1) ───────
// A rounded card with punched notches on both sides; fill with
// `FillStyle(eoFill: true)` so the notch circles become cutouts.

struct TicketShape: Shape {
    var cornerRadius: CGFloat = Theme.corner
    var notchRadius: CGFloat = 9
    /// Distance of the perforation line from the BOTTOM edge (the stub height).
    var notchFromBottom: CGFloat = 56

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        let y = rect.maxY - notchFromBottom
        path.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius,
                                   width: notchRadius * 2, height: notchRadius * 2))
        path.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius,
                                   width: notchRadius * 2, height: notchRadius * 2))
        return path
    }
}

/// The dashed perforation line inside a ticket.
struct PerforationLine: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(Theme.hairline)
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

// ── SectionHeader ────────────────────────────────────────────────────────

/// Placard-style: label, then a hairline rule running to the card edge —
/// instrument-panel labeling, drawn, never an image.
/// The polished-silver icon treatment (v3.1.3): silver gradient face with
/// a soft white glow — instruments on the console, not accent stickers.
extension View {
    func polishedSilver() -> some View {
        foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.58)],
                                       startPoint: .top, endPoint: .bottom))
            .shadow(color: .white.opacity(0.6), radius: 4)
    }
}

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var accent: Color = Theme.sky

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    // Header icons are polished silver with a soft glow —
                    // instruments on the console, not accent stickers.
                    Image(systemName: icon).font(.caption2.weight(.medium))
                        .polishedSilver()
                }
                Text(title.uppercased())
                    .font(.data(.caption2))                  // mono eyebrow
                    .tracking(0.9)
                    .foregroundStyle(Theme.textSecondary)
            }
            .layoutPriority(1)
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .padding(.horizontal, 4)
    }
}

// ── TickerText — the departure-board number roll ─────────────────────────

struct TickerText: View {
    let text: String
    var font: Font = .game(.title3, weight: .bold)
    var color: Color = Theme.textPrimary

    var body: some View {
        Text(text)
            .font(font)
            // Warm Paper: sans values with monospaced DIGITS — stable while
            // ticking, without the terminal voice.
            .monospacedDigit()
            // Readouts never wrap; they scale down before they break.
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.snappy, value: text)
    }
}

// ── StatTile — hero stat with caption ────────────────────────────────────

struct StatTile: View {
    let label: String
    let value: String
    var color: Color = Theme.textPrimary
    var font: Font = .game(.title3, weight: .bold)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            TickerText(text: value, font: font, color: color)
            Text(label).font(.game(.caption)).foregroundStyle(Theme.textSecondary)
        }
    }
}

// ── InstrumentGauge — a cockpit dial for a 0...1 reading ────────────────

/// A machined 270° dial for a fraction (load factor, punctuality): a
/// recessed arc track ringed with graduation ticks, a glowing milled arc in
/// the semantic color sweeping to the value, and a mono readout at the hub
/// under a polished icon. It sweeps when the value changes — an instrument
/// reading a live machine, not a flat percentage.
struct InstrumentGauge: View {
    let value: Double              // 0...1
    let label: String
    var icon: String = "gauge.with.dots.needle.bottom.50percent"
    var display: String? = nil     // defaults to a percentage
    var tint: Color? = nil         // override; else the health color

    private let sweep = 0.75        // 270° of the circle
    private let diameter: CGFloat = 78

    var body: some View {
        let v = max(0, min(1, value))
        let color = tint ?? Theme.health(v)
        VStack(spacing: 7) {
            ZStack {
                // Recessed arc track, cut into the panel.
                Circle().trim(from: 0, to: sweep)
                    .stroke(LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.26)],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(135))
                // Graduation ticks along the arc. A top-pinned tick sits at
                // 12 o'clock (270° clockwise from the trim's 3 o'clock zero),
                // so to land it on the arc angle (135° + f·270°) it rotates by
                // 225° + f·270° — the +90° that keeps ticks ON the track.
                ForEach(0..<11, id: \.self) { i in
                    Capsule().fill(Color.white.opacity(0.16))
                        .frame(width: 1.5, height: 4)
                        .frame(width: diameter, height: diameter, alignment: .top)
                        .rotationEffect(.degrees(225 + Double(i) / 10 * 270))
                }
                // Milled value arc + light bleed.
                Circle().trim(from: 0, to: sweep * v)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .shadow(color: color.opacity(0.6), radius: 4)
                // Hub readout.
                VStack(spacing: 0) {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                        .polishedSilver()
                    TickerText(text: display ?? "\(Int(v * 100))%",
                               font: .data(.title3, weight: .semibold),
                               color: Theme.textPrimary)
                }
            }
            .frame(width: diameter, height: diameter)
            .animation(.snappy, value: v)
            Text(label.uppercased())
                .font(.data(.caption2)).tracking(0.9)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(label) \(Int(v * 100)) percent")
    }
}

// ── MeterBar — any 0...1 quantity (v3.1.4 machined) ─────────────────────

/// A machined instrument channel: a recessed groove engraved into the
/// panel (dark cut above, catch-light below, quarter graduations) holding
/// a milled metal slug of the semantic color — specular top edge, shaded
/// underside, polished end cap, and a faint light bleed out of the groove.
struct MeterBar: View {
    let value: Double          // 0...1
    var color: Color = Theme.profit
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let fraction = min(1, max(0, value))
            // The slug rides 1pt inside the channel so the groove's lip
            // stays visible around the metal even at 100%.
            let slugWidth = max(height - 2, (geo.size.width - 2) * fraction)
            ZStack(alignment: .leading) {
                // The channel: milled into the panel, darkest at the top
                // lip where the cut shadows itself.
                Capsule()
                    .fill(LinearGradient(colors: [.black.opacity(0.55),
                                                  .black.opacity(0.30)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule()
                        .strokeBorder(LinearGradient(
                            colors: [.black.opacity(0.8), .white.opacity(0.14)],
                            startPoint: .top, endPoint: .bottom),
                            lineWidth: 1))
                // Quarter graduations, engraved faint in the channel floor.
                ForEach(1..<4) { quarter in
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1, height: height - 3)
                        .offset(x: geo.size.width * Double(quarter) / 4)
                }
                // The slug: milled bar of the semantic metal — bright
                // rolled top, shaded underside, its light bleeding out.
                Capsule()
                    .fill(color)
                    .overlay(Capsule()
                        .fill(LinearGradient(stops: [
                            .init(color: .white.opacity(0.42), location: 0),
                            .init(color: .white.opacity(0.06), location: 0.45),
                            .init(color: .black.opacity(0.28), location: 1),
                        ], startPoint: .top, endPoint: .bottom)))
                    // Polished bevel where the metal ends.
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 1.5)
                            .padding(.trailing, 1.5)
                            .padding(.vertical, 1.5)
                            .blur(radius: 0.3)
                    }
                    .overlay(Capsule()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                    .frame(width: slugWidth, height: height - 2)
                    .padding(.leading, 1)
                    .shadow(color: color.opacity(0.55), radius: 2.5)
            }
        }
        .frame(height: height)
        .animation(.snappy, value: value)
    }
}

/// A labeled meter row: caption + value on top, bar underneath.
struct MeterRow: View {
    let label: String
    let value: Double          // 0...1
    var display: String? = nil // defaults to a percentage
    var color: Color = Theme.profit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                Spacer()
                TickerText(text: display ?? "\(Int(value * 100))%",
                           font: .game(.caption, weight: .semibold), color: color)
            }
            MeterBar(value: value, color: color)
        }
    }
}

// ── PersonAvatar — the face on the roster ────────────────────────────────

/// Staff/applicant portrait from Resources/StaffAvatars; monogram fallback
/// for pre-avatar saves.
struct PersonAvatar: View {
    let avatar: String?
    let name: String
    var size: CGFloat = 36

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    var body: some View {
        // Portraits sit open on the surface — no clipping, no ring. Only
        // the monogram fallback keeps a quiet disc (bare initials float).
        if let avatar, let image = UIImage(named: avatar) {
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(initials)
                .font(.data(.caption2, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: size, height: size)
                .background(Theme.bg, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}

// ── StarRating ───────────────────────────────────────────────────────────

/// Gold-star photo rating (Resources/Icons/gold_star.png): each star is
/// the metallic asset, filled fractionally — bright gold over a dimmed
/// base — so 3.4★ literally shows 40% of the fourth star.
struct StarRating: View {
    let rating: Double         // 0...5
    var size: CGFloat = 12
    var color: Color = Theme.warn   // kept for call-site compatibility

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                star(fill: min(1, max(0, rating - Double(i))))
            }
        }
    }

    @ViewBuilder private func star(fill: Double) -> some View {
        if let image = UIImage(named: "gold_star") {
            ZStack {
                Image(uiImage: image).resizable().scaledToFit()
                    .grayscale(1).opacity(0.22)          // the empty socket
                Image(uiImage: image).resizable().scaledToFit()
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * fill)
                        }
                    }
            }
            .frame(width: size + 2, height: size + 2)
        } else {
            Image(systemName: fill >= 0.75 ? "star.fill"
                  : fill >= 0.25 ? "star.leadinghalf.filled" : "star")
                .font(.system(size: size))
                .foregroundStyle(color)
        }
    }
}

// ── StatusBadge ──────────────────────────────────────────────────────────

struct StatusBadge: View {
    let text: String
    var color: Color = Theme.sky

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.tagCorner) }

    var body: some View {
        // v3.1.2: a stamped silver metal tag — punched hole, debossed mono
        // lettering, the semantic color as a thin anodized wash on the plate.
        HStack(spacing: 5) {
            // The punched hole the tag would wire onto.
            Circle()
                .fill(Theme.bg)
                .frame(width: 4.5, height: 4.5)
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [.black.opacity(0.6), .white.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.8))
            Text(text.uppercased())
                .font(.data(.caption2, weight: .semibold)).tracking(0.85)
                // Debossed: dark strike with the light catching the cut below.
                .foregroundStyle(Color(white: 0.13))
                .shadow(color: .white.opacity(0.30), radius: 0, y: 0.8)
        }
        .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 3)
        .background {
            shape.fill(LinearGradient(colors: [Color(white: 0.80), Color(white: 0.52)],
                                      startPoint: .top, endPoint: .bottom))
            if color != Theme.ink {
                shape.fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.14)],
                                          startPoint: .top, endPoint: .bottom))
            }
        }
        .overlay(shape.strokeBorder(
            LinearGradient(colors: [.white.opacity(0.75), .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom),
            lineWidth: 0.8))
        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
    }
}

// ── GameButtonStyle — every tappable action ──────────────────────────────

struct GameButtonStyle: ButtonStyle {
    var color: Color = Theme.sky
    var prominent = false
    /// Explicit material override; when set, `color`/`prominent` are ignored
    /// (e.g. `.bronze` confirm / `.obsidian` cancel pairs).
    var finish: MetalFinish? = nil
    /// Label lines before scaling kicks in — event cards pass 2 so long
    /// option labels wrap instead of truncating.
    var lines: Int = 1

    func makeBody(configuration: Configuration) -> some View {
        // A nested view so we can read @Environment(\.isEnabled): a
        // ButtonStyle's makeBody can't. WITHOUT this, a .disabled() key looked
        // identical to a live one and silently ate taps (GDD §35 — the dead
        // "Post job ad" button was just disabled on low cash).
        KeyBody(configuration: configuration, color: color,
                prominent: prominent, finish: finish, lines: lines)
    }

    private struct KeyBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        let prominent: Bool
        let finish: MetalFinish?
        let lines: Int
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let material = finish ?? (prominent ? .chrome : .gunmetal)
            configuration.label
                .font(.game(.subheadline, weight: .medium))
                .lineLimit(lines)
                .multilineTextAlignment(.center)
                // Long labels scale down inside the key — never overflow it.
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(minHeight: 36)
                .foregroundStyle(material.ink)
                .metalKey(material, pressed: configuration.isPressed && isEnabled,
                          tint: finish == nil && !prominent ? color : nil)
                // Disabled reads as disabled: dimmed and desaturated so a
                // dead key never masquerades as a live one.
                .opacity(isEnabled ? 1 : 0.4)
                .saturation(isEnabled ? 1 : 0)
                .sensoryFeedback(.impact(weight: .light),
                                 trigger: configuration.isPressed) { old, new in
                    isEnabled && !old && new
                }
        }
    }
}

// ── MetalKey — the machined console key surface (v3.1.1) ─────────────────
// Blueprint's one sanctioned elevation: a console's buttons are physical.
// Gradient face, light-catching top rim, extruded base lip, and 2.5pt
// press-travel. Sized by its CONTENT (the lip is a background, never a
// greedy sibling). Reused by GameButtonStyle and PillStepper.

/// The stock of metal a key is machined from. Each finish owns its face
/// gradient, rim, base lip, and legible label ink.
enum MetalFinish {
    case chrome     // white primary key (the one bright CTA per screen)
    case gunmetal   // quiet dark key; accepts an anodized tint wash
    case bronze     // warm machined bronze — the gold-star family; confirms
    case obsidian   // polished near-black; cancels and destructive exits

    func face(pressed: Bool) -> [Color] {
        switch self {
        case .chrome:
            pressed ? [Color(white: 0.80), Color(white: 0.68)]
                    : [Color(white: 1.00), Color(white: 0.80)]
        case .gunmetal:
            pressed ? [Color(white: 0.16), Color(white: 0.11)]
                    : [Color(white: 0.30), Color(white: 0.15)]
        case .bronze:
            pressed ? [Color(red: 0.60, green: 0.42, blue: 0.23),
                       Color(red: 0.40, green: 0.26, blue: 0.12)]
                    : [Color(red: 0.83, green: 0.61, blue: 0.36),
                       Color(red: 0.53, green: 0.35, blue: 0.16)]
        case .obsidian:
            pressed ? [Color(white: 0.07), Color(white: 0.02)]
                    : [Color(white: 0.14), Color(white: 0.04)]
        }
    }

    var rim: [Color] {
        switch self {
        case .chrome:   [Color.white, Color(white: 0.45)]
        case .gunmetal: [Color.white.opacity(0.35), Color.black.opacity(0.55)]
        case .bronze:   [Color(red: 1.0, green: 0.88, blue: 0.66),
                         Color(red: 0.30, green: 0.18, blue: 0.06)]
        case .obsidian: [Color.white.opacity(0.28), Color.black.opacity(0.70)]
        }
    }

    /// The base the key travels onto.
    var lip: Color {
        switch self {
        case .chrome:   Color(white: 0.30)
        case .gunmetal: Color.black.opacity(0.85)
        case .bronze:   Color(red: 0.26, green: 0.16, blue: 0.06)
        case .obsidian: Color.black
        }
    }

    /// Label color that reads on this face.
    var ink: Color {
        switch self {
        case .chrome: Theme.bg
        case .bronze: Color(red: 0.13, green: 0.07, blue: 0.01)
        case .gunmetal, .obsidian: Color.white
        }
    }
}

struct MetalKeyModifier: ViewModifier {
    var finish: MetalFinish
    var pressed: Bool
    var cornerRadius: CGFloat = Theme.corner
    /// Anodized wash: a colored tint over the gunmetal face (gunmetal only —
    /// chrome, bronze, and obsidian are already their own material).
    var tint: Color? = nil

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius) }
    private let travel: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(LinearGradient(colors: finish.face(pressed: pressed),
                                          startPoint: .top, endPoint: .bottom))
                if let tint, finish == .gunmetal {
                    shape.fill(LinearGradient(
                        colors: [tint.opacity(pressed ? 0.30 : 0.45),
                                 tint.opacity(pressed ? 0.14 : 0.22)],
                        startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay(shape.strokeBorder(
                LinearGradient(colors: finish.rim,
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            .offset(y: pressed ? travel : 0)
            // The base the key travels onto — a background, so it takes the
            // key's own size instead of stretching the row.
            .background(shape.fill(finish.lip).offset(y: travel))
            .compositingGroup()
            .scaleEffect(pressed ? 0.97 : 1)   // subtle give under the finger
            .shadow(color: .black.opacity(pressed ? 0.15 : 0.35),
                    radius: pressed ? 2 : 5, y: pressed ? 1 : 4)
            .animation(.snappy(duration: 0.12), value: pressed)
    }
}

extension View {
    func metalKey(_ finish: MetalFinish, pressed: Bool,
                  cornerRadius: CGFloat = Theme.corner,
                  tint: Color? = nil) -> some View {
        modifier(MetalKeyModifier(finish: finish, pressed: pressed,
                                  cornerRadius: cornerRadius, tint: tint))
    }

    /// Legacy entry point (v3.1.1): prominent → chrome, quiet → gunmetal.
    func metalKey(prominent: Bool, pressed: Bool,
                  cornerRadius: CGFloat = Theme.corner,
                  tint: Color? = nil) -> some View {
        metalKey(prominent ? .chrome : .gunmetal, pressed: pressed,
                 cornerRadius: cornerRadius, tint: tint)
    }
}

// ── MetalPanel — the machined instrument panel (v3.1.2) ──────────────────
// MetalKey's language at panel scale: a dark metal face with a diagonal
// sheen, a light-catching top rim, and an extruded base. Reserved for the
// ONE hero surface per screen — everything else stays a flat GameCard.

struct MetalPanel<Content: View>: View {
    /// Tints the rim's light catch (hero accent; settle flash).
    var highlight: Color? = nil
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.corner) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // Dark machined face (departure-board housing): near-black
                // falloff plus a faint diagonal light sweep.
                shape.fill(LinearGradient(
                    colors: [Color(white: 0.16), Color(white: 0.07)],
                    startPoint: .top, endPoint: .bottom))
                shape.fill(LinearGradient(
                    stops: [.init(color: .white.opacity(0.07), location: 0),
                            .init(color: .clear, location: 0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(shape.strokeBorder(
                LinearGradient(
                    colors: [(highlight ?? .white).opacity(highlight == nil ? 0.35 : 0.85),
                             Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            // Inner frame: the board's second border, machined into the face.
            .overlay(RoundedRectangle(cornerRadius: Theme.corner - 3)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                .padding(4))
            // The slab the panel sits proud of.
            .background(shape.fill(Color.black.opacity(0.9)).offset(y: 3))
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 9, y: 5)
    }
}

/// A recessed cutout in a MetalPanel — inverted rim (shadow on top, light
/// catch on the bottom edge) over a darker inset floor, the way gauges sit
/// IN a console rather than on it.
struct InstrumentWell<Content: View>: View {
    var alignment: Alignment = .leading
    /// Anodized floor: a colored wash in the well (semantic hue — profit,
    /// loss, cornflower, gold) so the console pops instead of reading gray.
    var tint: Color? = nil
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 6) }

    var body: some View {
        content
            .padding(.horizontal, 10).padding(.vertical, 8)
            // maxHeight fills the row so sibling tiles machine to ONE height.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .background {
                // Board-tile floor: black, so the glyphs carry the color.
                shape.fill(Color.black.opacity(0.48))
                if let tint {
                    shape.fill(LinearGradient(
                        colors: [tint.opacity(0.20), tint.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom))
                }
                // Inner top shadow: the wall the well is sunk behind.
                shape.fill(LinearGradient(
                    stops: [.init(color: .black.opacity(0.40), location: 0),
                            .init(color: .clear, location: 0.35)],
                    startPoint: .top, endPoint: .bottom))
            }
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [Color.black.opacity(0.65),
                                        (tint ?? .white).opacity(tint == nil ? 0.12 : 0.30)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
    }
}

// ── SlideKey — slide-to-commit (v3.1.3) ──────────────────────────────────
// Signing a lease is a contract, not a tap: a bronze key travels a
// recessed groove and the deal executes only at the end of the throw.

struct SlideKey: View {
    let label: String
    var enabled = true
    let onCommit: () -> Void

    @State private var offset: CGFloat = 0
    @State private var committed = false
    // Haptics while swiping: a light tick per notch of travel, and a firmer
    // bump the moment the slide arms past the commit threshold.
    @State private var detent = 0
    @State private var armed = false

    private let thumbWidth: CGFloat = 60
    private let height: CGFloat = 46
    private let bronzeTop = Color(red: 0.83, green: 0.61, blue: 0.36)
    private let bronzeBottom = Color(red: 0.53, green: 0.35, blue: 0.16)

    var body: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.width - thumbWidth - 4)
            ZStack(alignment: .leading) {
                // The groove: a recessed instrument track.
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(LinearGradient(
                            colors: [.black.opacity(0.65), .white.opacity(0.12)],
                            startPoint: .top, endPoint: .bottom), lineWidth: 1))
                // Bronze trail fills behind the key.
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [bronzeTop.opacity(0.30),
                                                  bronzeBottom.opacity(0.16)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: offset + thumbWidth + 2)
                Text(label)
                    .font(.game(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .opacity(max(0, 1 - (offset / travel) * 1.8))
                // The key itself: bronze metal, chevrons pointing the way.
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [bronzeTop, bronzeBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.88, blue: 0.66),
                                     Color(red: 0.30, green: 0.18, blue: 0.06)],
                            startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .overlay(
                        HStack(spacing: -3) {
                            Image(systemName: "chevron.right")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.13, green: 0.07, blue: 0.01))
                    )
                    .frame(width: thumbWidth, height: height - 8)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .offset(x: 2 + offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard enabled, !committed else { return }
                                offset = min(max(0, value.translation.width), travel)
                                let p = offset / travel
                                detent = Int(p * 10)     // ten notches of travel
                                armed = p > 0.85
                            }
                            .onEnded { _ in
                                guard enabled, !committed else { return }
                                if offset > travel * 0.85 {
                                    committed = true
                                    withAnimation(.snappy(duration: 0.15)) { offset = travel }
                                    onCommit()
                                    // Re-arm after the receipt moment.
                                    Task {
                                        try? await Task.sleep(for: .seconds(0.8))
                                        withAnimation(.spring(duration: 0.4)) { offset = 0 }
                                        committed = false
                                        detent = 0; armed = false
                                    }
                                } else {
                                    withAnimation(.spring(duration: 0.35)) { offset = 0 }
                                    detent = 0; armed = false
                                }
                            }
                    )
            }
        }
        .frame(height: height)
        .opacity(enabled ? 1 : 0.4)
        .allowsHitTesting(enabled)
        // A firm tick as the key crosses each notch while swiping…
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: detent)
        // …a heavy thunk when it arms past the commit line…
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: armed) { _, new in new }
        // …and the success thud when the deal signs.
        .sensoryFeedback(.success, trigger: committed) { _, new in new }
    }
}

/// An engraved groove line — dark cut above, light catch below.
struct PanelGroove: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1)
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}


// ── PillStepper — player-set numbers ─────────────────────────────────────

struct PillStepper: View {
    let label: String
    let value: String
    var accent: Color = Theme.sky
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @State private var taps = 0

    var body: some View {
        HStack {
            Text(label).font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer()
            stepButton("minus", action: onDecrement)
            TickerText(text: value, font: .game(.subheadline, weight: .bold))
                .frame(minWidth: 64)
                .multilineTextAlignment(.center)
            stepButton("plus", action: onIncrement)
        }
        .sensoryFeedback(.increase, trigger: taps)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.white)
                .metalKey(prominent: false, pressed: false)
        }
        .buttonStyle(.plain)
        // Hold to keep stepping — one tap per $50 was carpal tunnel.
        .buttonRepeatBehavior(.enabled)
    }
}

// ── FormulaSheet — tap any number, see the math (design pillar 4) ────────

struct Explanation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let rows: [(label: String, value: String)]
    let formula: String
}

struct FormulaSheet: View {
    @Environment(\.dismiss) private var dismiss
    let explanation: Explanation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(explanation.title)
                        .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                    Text(explanation.subtitle)
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.07), in: Circle())
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)

            VStack(spacing: 8) {
                ForEach(explanation.rows.indices, id: \.self) { i in
                    HStack {
                        Text(explanation.rows[i].label)
                            .font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(explanation.rows[i].value)
                            .font(.game(.subheadline, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))

            Text(explanation.formula)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.cornflower)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.corner))
                .overlay(RoundedRectangle(cornerRadius: Theme.corner)
                    .strokeBorder(Theme.hairline, lineWidth: 1))

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bgElevated)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
    }
}

// ── Screen scaffold — dark ops background + card stack ───────────────────

struct GameScreen<Content: View>: View {
    let title: String
    var accent: Color = Theme.sky
    /// Optional accessory pinned to the right of the title row (e.g. a
    /// quick-access icon). Defaults to nil, so existing screens are untouched.
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.display(.largeTitle))   // sans semibold
                        .tracking(-1.2)                // engineered compression
                        .foregroundStyle(Theme.textPrimary)
                    if let trailing {
                        Spacer(minLength: 8)
                        trailing
                    }
                }
                .padding(.top, 6)
                content
            }
            .padding(.horizontal, Theme.gutter)
            // Clearance for the floating sim clock: the last row of
            // controls must be able to scroll fully above the pill.
            .padding(.bottom, 92)
        }
        .background(Theme.bg)
        .scrollIndicators(.hidden)
    }
}


// Machined meter pin: the instrument channel at every fill level and color.
#Preview("Instrument gauges") {
    GameCard {
        SectionHeader(title: "Economics", icon: "slider.horizontal.3", accent: Theme.teal)
        HStack(spacing: 20) {
            InstrumentGauge(value: 0.86, label: "Load factor", icon: "person.2.fill")
            InstrumentGauge(value: 0.58, label: "On-time", icon: "clock.fill")
        }
        HStack(spacing: 20) {
            InstrumentGauge(value: 0.30, label: "Load factor", icon: "person.2.fill")
            InstrumentGauge(value: 1.0, label: "On-time", icon: "clock.fill")
        }
    }
    .padding(16)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Meters") {
    GameCard {
        MeterRow(label: "Happiness", value: 0.70, color: Theme.profit)
        MeterRow(label: "Workload", value: 0.87, display: "87%", color: Theme.warn)
        MeterRow(label: "Load factor", value: 0.42, color: Theme.warn)
        MeterRow(label: "Condition", value: 0.20, display: "20/100", color: Theme.loss)
        MeterRow(label: "Satisfaction", value: 0.55, color: Theme.sky)
        MeterRow(label: "Empty", value: 0.0, color: Theme.profit)
        MeterRow(label: "Full", value: 1.0, color: Theme.profit)
    }
    .padding(16)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Metal keys") {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            Button("Set up route") {}.buttonStyle(GameButtonStyle(finish: .bronze))
            Button("Cancel route") {}.buttonStyle(GameButtonStyle(finish: .obsidian))
        }
        HStack(spacing: 12) {
            Button("Buy · $4.2M") {}.buttonStyle(GameButtonStyle(color: Theme.sky, prominent: true))
            Button("Post job ad · $2.0K") {}.buttonStyle(GameButtonStyle(color: Theme.sky))
        }
        PillStepper(label: "Weekly wage", value: "$1.5K", onDecrement: {}, onIncrement: {})
            .padding(.horizontal, 24)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.card)
    .preferredColorScheme(.dark)
}
