//
//  Theme.swift
//  SkyTycoon — Design system tokens (DESIGN_SYSTEM.md §0, v3.1)
//
//  "Blueprint" — a dark command center (Dovetail reference): near-black
//  canvas, carbon cards, tone-stacked surfaces with hairline borders and
//  ZERO shadows. One chromatic accent (cornflower #6798FF) for active
//  states, icons, and data strokes — never a button fill. Muted
//  functional green/red/amber survive for P&L semantics only.
//

import SwiftUI
import CoreText

enum Theme {
    // ── Surfaces (tone hierarchy: ink → coal → carbon → steel) ──────────
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.039)           // #0A0A0A ink
    static let fog = Color(red: 0.078, green: 0.078, blue: 0.078)          // #141414 coal
    static let bgElevated = Color(red: 0.078, green: 0.078, blue: 0.078)   // sheets = coal
    static let card = Color(red: 0.118, green: 0.118, blue: 0.118)         // #1E1E1E carbon
    /// Hairline borders and dividers (steel); graphite for outlined controls.
    static let hairline = Color(red: 0.192, green: 0.192, blue: 0.192)     // #313131 steel
    static let graphite = Color(red: 0.271, green: 0.271, blue: 0.271)     // #454545

    // ── Text (snow / ash / fog) ──────────────────────────────────────────
    static let textPrimary = Color.white                                    // snow
    static let textSecondary = Color(red: 0.655, green: 0.655, blue: 0.655) // #A7A7A7 ash
    static let textTertiary = Color(red: 0.486, green: 0.486, blue: 0.486)  // #7C7C7C fog
    static let ink = textPrimary   // legacy name from v3.0 call sites

    // ── The one chromatic accent ─────────────────────────────────────────
    static let cornflower = Color(red: 0.404, green: 0.596, blue: 1.0)     // #6798FF

    // ── Functional semantics (game necessity; quiet on near-black) ───────
    static let profit = Color(red: 0.36, green: 0.78, blue: 0.53)
    static let loss = Color(red: 0.91, green: 0.45, blue: 0.40)
    static let warn = Color(red: 0.89, green: 0.68, blue: 0.34)

    // ── Legacy accent tokens: all resolve to the single blue accent
    // (they mark active states, selected fills, and icons — exactly the
    // accent's Dovetail role).
    static let sky = cornflower
    static let orange = cornflower
    static let teal = cornflower
    static let violet = cornflower
    static let mint = cornflower
    // v3.0 leftovers, remapped so stragglers stay coherent:
    static let peach = card
    static let sienna = cornflower

    // ── Data palette: anodized metals — DISTINCT hues at a machined
    // saturation, ordered so neighbors contrast (v3.1.2: categorical
    // slices need separation; the one-accent rule holds for strokes).
    static let chartPalette: [Color] = [
        cornflower,                                    // steel blue
        Color(red: 0.83, green: 0.62, blue: 0.36),     // bronze
        Color(red: 0.42, green: 0.78, blue: 0.71),     // anodized teal
        Color(red: 0.71, green: 0.56, blue: 1.00),     // anodized violet
        Color(red: 0.92, green: 0.78, blue: 0.44),     // gold
        Color(red: 0.87, green: 0.52, blue: 0.44),     // copper rose
        Color(white: 0.82),                            // polished silver
        Color(red: 0.47, green: 0.55, blue: 0.67),     // slate steel
        Color(white: 0.38),                            // graphite
    ]

    // ── Shape & space (compact, engineered: 8px system) ─────────────────
    static let corner: CGFloat = 8          // cards, buttons, inputs
    static let controlCorner: CGFloat = 8
    static let tagCorner: CGFloat = 4       // small tags/chips
    static let artifactCorner: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let gutter: CGFloat = 16
    static let cardSpacing: CGFloat = 12

    /// v3.1: no gradients on surfaces. Retained for the map arc glow only.
    static func accentGradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color, color], startPoint: .top, endPoint: .bottom)
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

// ── Fonts (v3.1 "Blueprint") ─────────────────────────────────────────────
// Inter-equivalent (SF) everywhere: 400 body, 500 labels, 600 headings
// with tight tracking at display sizes. Mono is reserved for eyebrows,
// tags, and data codes with POSITIVE tracking — the instrument voice.

extension Font {
    static func game(_ style: TextStyle, weight: Weight = .regular) -> Font {
        // Dovetail's stack: nothing heavier than semibold.
        let capped: Weight = (weight == .bold || weight == .heavy) ? .semibold : weight
        return .system(style, design: .default).weight(capped)
    }

    /// Headline voice: sans semibold (tracking applied at call sites).
    static func display(_ style: TextStyle) -> Font {
        .system(style, design: .default).weight(.semibold)
    }

    /// Mono for eyebrows/tags/data codes (positive tracking at call site).
    static func data(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }

    /// The human hand: Caveat (SIL OFL, see CREDITS.md) for the aunt's
    /// signature and other handwritten touches. Registered lazily on
    /// first use — works in app AND previews, no Info.plist entry.
    /// Serif-italic fallback if the face ever fails to register.
    static func handwriting(_ size: CGFloat) -> Font {
        _ = HandwritingFont.registered
        return UIFont(name: "Caveat", size: size) != nil
            || UIFont(name: "Caveat-Regular", size: size) != nil
            ? .custom("Caveat", size: size)
            : .system(size: size, design: .serif).italic()
    }
}

private enum HandwritingFont {
    static let registered: Void = {
        guard let url = Bundle.main.url(forResource: "Caveat-Variable",
                                        withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()
}

/// A signature being written: the name in the handwriting face, revealed
/// left to right like ink following the nib.
struct HandwrittenSignature: View {
    let name: String
    var size: CGFloat = 28
    var color: Color = Theme.textPrimary
    @State private var inked = false

    var body: some View {
        Text(name)
            .font(.handwriting(size))
            .foregroundStyle(color)
            // Cursive glyphs overhang their advance width; without this the
            // final letter's flourish is clipped on the right. Give the
            // frame room, then mask over the padded width.
            .padding(.trailing, size * 0.4)
            .mask(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle().frame(width: geo.size.width * (inked ? 1 : 0))
                }
            }
            .onAppear {
                inked = false
                withAnimation(.easeInOut(duration: 1.3).delay(0.3)) { inked = true }
            }
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

#Preview("Handwriting") {
    VStack(spacing: 14) {
        Text("Aunt Margaret").font(.handwriting(38)).foregroundStyle(.white)
        HandwrittenSignature(name: "Aunt Meera", size: 38)
    }
    .padding(30)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
