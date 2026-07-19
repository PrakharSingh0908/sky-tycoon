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
        // Toy Store: paper-white card at the near-square 3pt radius — flat,
        // no border, no shadow (only CTA pills float). A highlight makes it
        // the sand callout voice.
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlight == nil ? Theme.card : Theme.sand,
                        in: RoundedRectangle(cornerRadius: Theme.corner))
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
                    Image(systemName: icon).font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text(title.lowercased())                     // the lowercase voice
                    .font(.game(.caption, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
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
                Capsule().fill(Color.black.opacity(0.07))
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
        // Toy Store tag: a quiet little pill — sand for neutral, tinted
        // wash for functional colors.
        Text(text.lowercased())
            .font(.game(.caption2, weight: .bold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color == Theme.ink ? Theme.sand : color.opacity(0.12),
                        in: Capsule())
            .foregroundStyle(color == Theme.ink ? Theme.textPrimary : color)
    }
}

// ── GameButtonStyle — every tappable action ──────────────────────────────

struct GameButtonStyle: ButtonStyle {
    var color: Color = Theme.sky
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        // Toy Store buttons: pills. Prominent = electric violet with the
        // system's only drop shadow; quiet = sand pill with violet text.
        // Functional colors (loss/warn) keep their meaning on both.
        let functional = color == Theme.loss || color == Theme.warn || color == Theme.profit
        let fill: Color = functional ? color : Theme.violet
        return configuration.label
            .font(.game(.subheadline, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 18).padding(.vertical, 9)
            .frame(minHeight: 38)
            .background(prominent ? AnyShapeStyle(fill) : AnyShapeStyle(Theme.sand),
                        in: Capsule())
            .foregroundStyle(prominent ? Color.white : (functional ? color : Theme.violet))
            .shadow(color: prominent ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
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
                .font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .background(Theme.sand, in: Circle())
                .foregroundStyle(Theme.violet)
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
                        .background(Theme.sand, in: Circle())
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
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.sand, in: RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Theme.bgElevated)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.light)
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
                Text(title.lowercased())       // the playdate signature
                    .font(.display(.largeTitle))   // rounded heavy
                    .tracking(-0.5)
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
