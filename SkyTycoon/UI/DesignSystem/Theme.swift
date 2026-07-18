//
//  Theme.swift
//  SkyTycoon — Design system tokens (DESIGN_SYSTEM.md §0, v3.0)
//
//  "Warm Paper" — serif analytics on warm paper (Steep translation).
//  Near-monochrome ink on white; flat mist cards; ONE chromatic accent
//  (blush peach + sienna ink) reserved for editorial moments; muted
//  functional colors survive only for P&L/health semantics.
//

import SwiftUI

enum Theme {
    // ── Surfaces (Steep: paper / mist / fog; flat, no card shadows) ──────
    static let bg = Color.white                                            // paper
    static let bgElevated = Color.white                                    // sheets/artifacts
    static let card = Color(red: 0.949, green: 0.949, blue: 0.953)         // #F2F2F3 mist
    static let fog = Color(red: 0.980, green: 0.980, blue: 0.984)          // #FAFAFB
    /// Hairline dividers, ticket perforations, artifact rings.
    static let hairline = Color(red: 0.925, green: 0.925, blue: 0.925)     // #ECECEC

    // ── Text (ink / slate / ash / smoke) ─────────────────────────────────
    static let textPrimary = Color(red: 0.090, green: 0.098, blue: 0.110)  // #17191C ink
    static let textSecondary = Color(red: 0.467, green: 0.482, blue: 0.525) // #777B86 slate
    static let textTertiary = Color(red: 0.592, green: 0.592, blue: 0.600) // #979799 ash
    static let ink = textPrimary

    // ── The one chromatic accent (rare, editorial) ───────────────────────
    static let peach = Color(red: 0.984, green: 0.882, blue: 0.820)        // #FBE1D1 blush
    static let sienna = Color(red: 0.365, green: 0.165, blue: 0.102)       // #5D2A1A

    // ── Functional semantics (game necessity; muted for white paper) ─────
    static let profit = Color(red: 0.114, green: 0.478, blue: 0.302)       // #1D7A4D
    static let loss = Color(red: 0.729, green: 0.263, blue: 0.192)         // #BA4331
    static let warn = Color(red: 0.663, green: 0.416, blue: 0.110)         // #A96A1C

    // ── Legacy tab accents: collapsed to ink (v3.0 is monochrome; identity
    // comes from serif + layout, not hue). Kept as tokens so call sites
    // survive; all resolve to ink except the functional trio above.
    static let sky = ink
    static let orange = ink
    static let teal = ink
    static let violet = ink
    static let mint = ink

    // ── Editorial chart palette (warm ramp into grays — slices/bars) ─────
    static let chartPalette: [Color] = [
        sienna,
        Color(red: 0.60, green: 0.32, blue: 0.19),
        Color(red: 0.78, green: 0.50, blue: 0.35),
        Color(red: 0.91, green: 0.70, blue: 0.55),
        peach,
        Color(red: 0.35, green: 0.37, blue: 0.41),
        textSecondary,
        textTertiary,
        Color(red: 0.80, green: 0.80, blue: 0.81),
    ]

    // ── Shape & space (Steep: soft, generous) ────────────────────────────
    static let corner: CGFloat = 24        // content cards
    static let controlCorner: CGFloat = 16 // inputs, small cards, chips
    static let artifactCorner: CGFloat = 20 // floating artifacts (map, passes)
    static let cardPadding: CGFloat = 18
    static let gutter: CGFloat = 20
    static let cardSpacing: CGFloat = 16

    /// v3.0: the "gradient border" era is over; retained for the few
    /// remaining callers as a flat editorial tint.
    static func accentGradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.opacity(0.9), color.opacity(0.45)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The floating-artifact shadow (Steep "subtle-3"): hairline ring is
    /// applied separately; this is the soft 10% lift.
    static func artifactShadow<V: View>(_ view: V) -> some View {
        view.shadow(color: .black.opacity(0.10), radius: 14, y: 10)
            .shadow(color: .black.opacity(0.06), radius: 5, y: 4)
    }

    /// Meter color by health fraction (1 = good): green → amber → red.
    static func health(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.35: loss
        case ..<0.65: warn
        default: profit
        }
    }
}

// ── Fonts (v3.0 "Warm Paper") ────────────────────────────────────────────
// Serif REGULAR (New York) for titles and headline moments — never bold;
// SF for body/UI with weight capped at medium (the Steep sans never
// exceeds 500). Values keep monospaced digits via TickerText.

extension Font {
    static func game(_ style: TextStyle, weight: Weight = .regular) -> Font {
        // Steep's sans tops out at 500: bold requests render medium.
        let capped: Weight = (weight == .bold || weight == .heavy) ? .medium : weight
        return .system(style, design: .default).weight(capped)
    }

    /// Serif display voice — always regular; the restraint IS the style.
    static func display(_ style: TextStyle) -> Font {
        .system(style, design: .serif).weight(.regular)
    }

    /// Data values: sans with monospaced digits (applied by TickerText).
    static func data(_ style: TextStyle, weight: Weight = .regular) -> Font {
        let capped: Weight = (weight == .bold || weight == .heavy) ? .medium : weight
        return .system(style, design: .default).weight(capped).monospacedDigit()
    }
}

// ── LiveryColor ⇄ Color bridging (UI layer only; sim stores plain RGB) ───

extension Color {
    init(_ livery: LiveryColor) {
        self.init(red: livery.red, green: livery.green, blue: livery.blue)
    }
}

extension LiveryColor {
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b))
    }
}
