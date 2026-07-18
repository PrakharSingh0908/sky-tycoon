//
//  GameHUD.swift
//  SkyTycoon — Design system (DESIGN_SYSTEM.md §3, v1.1)
//
//  The floating sim clock: date + speed control in one capsule, pinned
//  bottom-trailing above the tab bar on every tab. No persistent header —
//  screens open with their content (Flighty-style).
//

import SwiftUI

/// While any decision UI is open (negotiation, receipts, confirmations,
/// the cabin architect), the sim clock holds; the player's chosen speed
/// resumes when it closes. Apply to sheet CONTENT (fires on appear/disappear).
struct ClockHoldModifier: ViewModifier {
    @Environment(GameEngine.self) private var engine
    func body(content: Content) -> some View {
        content
            .onAppear { engine.beginInteraction() }
            .onDisappear { engine.endInteraction() }
    }
}

extension View {
    func holdsSimClock() -> some View { modifier(ClockHoldModifier()) }
}

struct SimClockPill: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        HStack(spacing: 10) {
            if engine.clockIsHeld {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 12)).foregroundStyle(Theme.warn)
            }
            TickerText(text: "\(engine.state.date.description) · \(engine.simDayName)",
                       font: .game(.caption, weight: .bold),
                       color: engine.speed == .paused || engine.clockIsHeld
                            ? Theme.textSecondary : Theme.textPrimary)
            SpeedControl()
        }
        .padding(.leading, 14)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner)
            .strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

struct SpeedControl: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GameEngine.SimSpeed.allCases, id: \.self) { speed in
                Button {
                    engine.speed = speed
                } label: {
                    glyph(for: speed)
                        .frame(width: 28, height: 26)
                        .background(
                            engine.speed == speed ? AnyShapeStyle(Color.white) : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(engine.speed == speed ? Theme.bg : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.corner))
        .sensoryFeedback(.selection, trigger: engine.speed)
        .animation(.snappy(duration: 0.2), value: engine.speed)
    }

    /// Pause glyph, then one/two/three chevrons for the running speeds.
    @ViewBuilder private func glyph(for speed: GameEngine.SimSpeed) -> some View {
        if speed == .paused {
            Image(systemName: "pause.fill")
                .font(.system(size: 10, weight: .bold))
        } else {
            let chevrons = switch speed {
            case .paused: 0
            case .x1: 1
            case .x2: 2
            case .x4: 3
            }
            HStack(spacing: -2.5) {
                ForEach(0..<chevrons, id: \.self) { _ in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .heavy))
                }
            }
            .accessibilityLabel("Speed \(chevrons)")
        }
    }
}
