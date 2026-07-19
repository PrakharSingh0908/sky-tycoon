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

struct StarRating: View {
    let rating: Double         // 0...5
    var size: CGFloat = 12
    var color: Color = Theme.warn

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: symbol(at: i)).font(.system(size: size))
            }
        }
        .foregroundStyle(color)
    }

    private func symbol(at index: Int) -> String {
        let fill = rating - Double(index)
        if fill >= 0.75 { return "star.fill" }
        if fill >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
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

    func makeBody(configuration: Configuration) -> some View {
        // Blueprint keys (v3.1.1): machined METAL buttons — the one
        // sanctioned exception to zero elevation, because a console's
        // buttons are physical. Gradient face, bright top rim, extruded
        // base lip, and real press-travel: the key sinks into the panel.
        let pressed = configuration.isPressed
        let functional = color == Theme.loss || color == Theme.warn || color == Theme.profit
        let shape = RoundedRectangle(cornerRadius: Theme.corner)
        let travel: CGFloat = 2.5

        // Face: brushed white metal (primary) or dark gunmetal (secondary).
        let face: LinearGradient = prominent
            ? LinearGradient(colors: pressed
                ? [Color(white: 0.80), Color(white: 0.68)]
                : [Color(white: 1.00), Color(white: 0.80)],
                startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: pressed
                ? [Color(white: 0.13), Color(white: 0.09)]
                : [Color(white: 0.24), Color(white: 0.12)],
                startPoint: .top, endPoint: .bottom)
        // Rim: light catches the machined top edge, falls off below.
        let rim = LinearGradient(colors: prominent
            ? [Color.white, Color(white: 0.45)]
            : [Color.white.opacity(0.30), Color.black.opacity(0.55)],
            startPoint: .top, endPoint: .bottom)
        let lip: Color = prominent ? Color(white: 0.30) : Color.black.opacity(0.85)

        return ZStack {
            // The extruded base the key travels onto.
            shape.fill(lip)
                .offset(y: travel)
            configuration.label
                .font(.game(.subheadline, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(minHeight: 36)
                .background(face, in: shape)
                .overlay(shape.strokeBorder(rim, lineWidth: 1))
                .foregroundStyle(prominent ? Theme.bg
                                 : (functional ? color : Color.white))
                .offset(y: pressed ? travel : 0)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(pressed ? 0.15 : 0.35),
                radius: pressed ? 2 : 5, y: pressed ? 1 : 4)
        .animation(.snappy(duration: 0.12), value: pressed)
        .sensoryFeedback(.impact(weight: .light), trigger: pressed) { old, new in
            !old && new
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
                .background(
                    LinearGradient(colors: [Color(white: 0.24), Color(white: 0.12)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: Theme.corner))
                .overlay(RoundedRectangle(cornerRadius: Theme.corner)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.30),
                                                          .black.opacity(0.55)],
                                                 startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
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
