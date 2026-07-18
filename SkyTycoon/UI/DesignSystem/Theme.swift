//
//  Theme.swift
//  SkyTycoon — Design system tokens (DESIGN_SYSTEM.md §2)
//
//  "The Ops Center" — dark navy surfaces, one accent per tab, semantic
//  health colors that always override accents.
//

import SwiftUI

enum Theme {
    // ── Surfaces ─────────────────────────────────────────────────────────
    static let bg = Color(red: 0.043, green: 0.071, blue: 0.125)          // #0B1220
    static let bgElevated = Color(red: 0.075, green: 0.114, blue: 0.184)  // #131D2F
    static let card = Color(red: 0.094, green: 0.137, blue: 0.220)        // #182338
    /// Internal dividers and ticket perforations ONLY — never card borders
    /// (DESIGN_SYSTEM.md v1.1: cards are borderless, Flighty-style).
    static let hairline = Color.white.opacity(0.08)

    // ── Text ─────────────────────────────────────────────────────────────
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    // ── Semantic health (always override tab accents) ────────────────────
    static let profit = Color(red: 0.302, green: 0.851, blue: 0.549)      // #4DD98C
    static let loss = Color(red: 1.0, green: 0.42, blue: 0.42)            // #FF6B6B
    static let warn = Color(red: 1.0, green: 0.722, blue: 0.302)          // #FFB84D

    // ── Tab accents (GDD §7: one accent color per tab) ───────────────────
    static let sky = Color(red: 0.349, green: 0.651, blue: 1.0)           // #59A6FF
    static let orange = Color(red: 1.0, green: 0.620, blue: 0.302)        // #FF9E4D
    static let teal = Color(red: 0.251, green: 0.839, blue: 0.788)        // #40D6C9
    static let violet = Color(red: 0.690, green: 0.549, blue: 1.0)        // #B08CFF
    static let mint = profit

    // ── Shape & space ────────────────────────────────────────────────────
    static let corner: CGFloat = 18
    static let cardPadding: CGFloat = 14
    static let gutter: CGFloat = 16
    static let cardSpacing: CGFloat = 12

    /// Meter color by health fraction (1 = good): green → amber → red.
    static func health(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.35: loss
        case ..<0.65: warn
        default: profit
        }
    }
}

// ── Fonts ────────────────────────────────────────────────────────────────

extension Font {
    static func game(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
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
