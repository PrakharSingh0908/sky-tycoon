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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
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

/// Placard-style: optional panel index, label, then a hairline rule running
/// to the card edge — instrument-panel labeling, drawn, never an image.
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var accent: Color = Theme.sky
    var index: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let index {
                    Text(String(format: "%02d", index))
                        .font(.data(.caption2, weight: .bold))
                        .foregroundStyle(accent.opacity(0.55))
                }
                if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
                Text(title.uppercased()).font(.game(.caption, weight: .bold)).tracking(1.2)
            }
            .foregroundStyle(accent)
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
            // Every live value is an instrument readout (Flight Deck v2.0):
            // full mono, not just mono digits, whatever font callers pass.
            .fontDesign(.monospaced)
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

/// A rectangular gauge track with 10% graduation ticks and a needle at the
/// current value — instrument language drawn in pure UI.
struct MeterBar: View {
    let value: Double          // 0...1
    var color: Color = Theme.profit
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fraction = min(1, max(0, value))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, w * fraction))
                // Graduations: cut lines every 10%, over track and fill alike.
                ForEach(1..<10, id: \.self) { i in
                    Rectangle().fill(Theme.bg.opacity(0.6))
                        .frame(width: 1, height: height)
                        .offset(x: w * CGFloat(i) / 10)
                }
                // Needle: overshoots the track like a gauge pointer.
                Rectangle().fill(Color.white.opacity(0.9))
                    .frame(width: 1.5, height: height + 4)
                    .offset(x: min(w - 1.5, max(0, w * fraction - 0.75)))
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
        Text(text.uppercased())
            .font(.game(.caption2, weight: .bold)).tracking(0.6)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.controlCorner))
            .foregroundStyle(color)
    }
}

// ── GameButtonStyle — every tappable action ──────────────────────────────

struct GameButtonStyle: ButtonStyle {
    var color: Color = Theme.sky
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.game(.subheadline, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(minHeight: 34)
            .background(prominent ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.16)),
                        in: RoundedRectangle(cornerRadius: Theme.controlCorner))
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : color)
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
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: Theme.controlCorner))
                .foregroundStyle(accent)
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
                        .font(.game(.title2, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text(explanation.subtitle)
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.controlCorner))
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
                .foregroundStyle(Theme.teal)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

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
                    .font(.game(.largeTitle, weight: .bold))
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
