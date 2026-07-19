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
struct FadeEdgeModifier: ViewModifier {
    var edge: Edge = .bottom
    var length: CGFloat = 24

    func body(content: Content) -> some View {
        content.mask {
            switch edge {
            case .top, .bottom:
                VStack(spacing: 0) {
                    if edge == .top {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: length)
                    }
                    Rectangle()
                    if edge == .bottom {
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: length)
                    }
                }
            case .leading, .trailing:
                HStack(spacing: 0) {
                    if edge == .leading {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: length)
                    }
                    Rectangle()
                    if edge == .trailing {
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: length)
                    }
                }
            }
        }
    }
}

extension View {
    func fadeEdge(_ edge: Edge = .bottom, length: CGFloat = 24) -> some View {
        modifier(FadeEdgeModifier(edge: edge, length: length))
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
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var accent: Color = Theme.sky

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.cornflower)   // icons carry the accent
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

// ── MeterBar — any 0...1 quantity ────────────────────────────────────────

/// A quiet rounded track (Warm Paper: gestural, no gridlines) — the fill
/// color carries the health semantics.
struct MeterBar: View {
    let value: Double          // 0...1
    var color: Color = Theme.profit
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let fraction = min(1, max(0, value))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(color.opacity(0.85))
                    .frame(width: max(height, geo.size.width * fraction))
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

    var body: some View {
        // Blueprint tag: mono, 4px corner, hairline — no filled chips.
        Text(text.uppercased())
            .font(.data(.caption2)).tracking(0.85)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: Theme.tagCorner)
                .strokeBorder(color == Theme.ink ? Theme.graphite : color.opacity(0.55),
                              lineWidth: 1))
            .foregroundStyle(color == Theme.ink ? Theme.textSecondary : color)
    }
}

// ── GameButtonStyle — every tappable action ──────────────────────────────

struct GameButtonStyle: ButtonStyle {
    var color: Color = Theme.sky
    var prominent = false
    /// Explicit material override; when set, `color`/`prominent` are ignored
    /// (e.g. `.bronze` confirm / `.obsidian` cancel pairs).
    var finish: MetalFinish? = nil

    func makeBody(configuration: Configuration) -> some View {
        let material = finish ?? (prominent ? .chrome : .gunmetal)
        configuration.label
            .font(.game(.subheadline, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(minHeight: 36)
            .foregroundStyle(material.ink)
            .metalKey(material, pressed: configuration.isPressed,
                      tint: finish == nil && !prominent ? color : nil)
            .sensoryFeedback(.impact(weight: .light),
                             trigger: configuration.isPressed) { old, new in
                !old && new
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
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                Text(title)
                    .font(.display(.largeTitle))   // sans semibold
                    .tracking(-1.2)                // engineered compression
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 6)
                content
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
        .scrollIndicators(.hidden)
    }
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
