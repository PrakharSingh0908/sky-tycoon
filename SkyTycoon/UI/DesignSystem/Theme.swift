//
//  Theme.swift
//  SkyTycoon — Design system tokens (DESIGN_SYSTEM.md §0, v3.2)
//
//  "Toy Store" — the Playdate translation: a sunlit product catalog.
//  Fog canvas, flat paper-white cards at a near-square 3pt radius, warm
//  carbon text, ONE interactive accent (electric violet, pills only,
//  carrying the system's only shadows) and sunbeam yellow reserved for
//  band moments (the hero). Muted functional green/red/amber survive
//  for P&L semantics only.
//

import SwiftUI

enum Theme {
    // ── Surfaces (fog canvas, paper cards, sand callouts, slate stage) ───
    static let bg = Color(red: 0.937, green: 0.937, blue: 0.937)           // #EFEFEF fog
    static let fog = Color(red: 0.937, green: 0.937, blue: 0.937)
    static let bgElevated = Color.white                                     // sheets
    static let card = Color.white                                           // paper
    static let sand = Color(red: 0.914, green: 0.894, blue: 0.851)         // #E9E4D9
    static let slate = Color(red: 0.471, green: 0.502, blue: 0.525)        // #788086 stage
    static let yellow = Color(red: 1.0, green: 0.773, blue: 0.0)           // #FFC500
    /// Quiet dividers only (ash-toned).
    static let hairline = Color(red: 0.694, green: 0.686, blue: 0.655).opacity(0.45) // #B1AFA7
    static let graphite = Color(red: 0.694, green: 0.686, blue: 0.655)     // ash borders

    // ── Text (warm carbon — never pure black) ────────────────────────────
    static let textPrimary = Color(red: 0.192, green: 0.184, blue: 0.153)  // #312F27 carbon
    static let textSecondary = Color(red: 0.443, green: 0.431, blue: 0.392) // warm gray
    static let textTertiary = Color(red: 0.694, green: 0.686, blue: 0.655) // #B1AFA7 ash
    static let ink = textPrimary

    // ── The one interactive accent ───────────────────────────────────────
    static let violet = Color(red: 0.467, green: 0.0, blue: 1.0)           // #7700FF

    // ── Functional semantics (game necessity; muted for light paper) ─────
    static let profit = Color(red: 0.114, green: 0.478, blue: 0.302)       // #1D7A4D
    static let loss = Color(red: 0.729, green: 0.263, blue: 0.192)         // #BA4331
    static let warn = Color(red: 0.663, green: 0.416, blue: 0.110)         // #A96A1C

    // ── Legacy accent tokens → the single violet (interactive states) ────
    static let sky = violet
    static let orange = violet
    static let teal = violet
    static let mint = violet
    static let cornflower = violet
    // v3.0/3.1 leftovers, kept coherent:
    static let peach = sand
    static let sienna = textPrimary

    // ── Data palette (warm neutrals + the brand yellow; violet stays
    // interactive-only per the reference) ────────────────────────────────
    static let chartPalette: [Color] = [
        textPrimary,                                          // carbon
        yellow,
        slate,
        Color(red: 0.55, green: 0.45, blue: 0.30),            // warm umber
        Color(red: 0.80, green: 0.65, blue: 0.25),            // ochre
        textSecondary,
        Color(red: 0.85, green: 0.55, blue: 0.25),            // amber-orange
        textTertiary,
        sand,
    ]

    // ── Shape & space (near-square cards, pill actions) ──────────────────
    static let corner: CGFloat = 3          // cards: the 2.85px signature
    static let controlCorner: CGFloat = 6   // inputs
    static let tagCorner: CGFloat = 14      // small tag pills
    static let artifactCorner: CGFloat = 3
    static let cardPadding: CGFloat = 16
    static let gutter: CGFloat = 20
    static let cardSpacing: CGFloat = 16

    /// The reference's violet gradient (buttons may wear it subtly).
    static func accentGradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.85)],
                       startPoint: .top, endPoint: .bottom)
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

// ── Fonts (v3.2 "Toy Store") ─────────────────────────────────────────────
// Roobert's stand-in is SF Rounded: humanist-geometric warmth in one
// family. 400 carries body, 700/800 anchor display words — the lowercase
// extra-bold title is the signature moment.

extension Font {
    static func game(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    /// Display voice: rounded HEAVY — for the lowercase wordmark moments.
    static func display(_ style: TextStyle) -> Font {
        .system(style, design: .rounded).weight(.heavy)
    }

    /// Data values: rounded with monospaced digits (applied by TickerText).
    static func data(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
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
