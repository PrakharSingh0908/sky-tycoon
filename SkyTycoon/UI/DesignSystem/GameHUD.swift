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

/// The time console: a glanceable pill (state · date · week progress)
/// that expands on tap into the full instrument — labeled day strip,
/// speed control, and a one-week step for deliberate play.
struct SimClockPill: View {
    @Environment(GameEngine.self) private var engine
    @State private var expanded = false

    private var stateIcon: String {
        if engine.clockIsHeld { return "pause.circle.fill" }
        return engine.speed == .paused ? "pause.fill" : "play.fill"
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if expanded {
                console
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                compactPill
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25), value: expanded)
        .sensoryFeedback(.selection, trigger: expanded)
    }

    // ── Glanceable: state, date, and the week filling up ─────────────────

    // Speed is the most frequent action — it stays ONE tap, inline.
    // The date/strip block is the affordance that opens the console.
    private var compactPill: some View {
        HStack(spacing: 10) {
            Button {
                expanded = true
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if engine.clockIsHeld {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.warn)
                        }
                        TickerText(text: "\(engine.state.date.description) · \(engine.simDayName)",
                                   font: .game(.caption, weight: .semibold),
                                   color: Theme.textPrimary)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    weekStrip(height: 3, labeled: false)
                        .frame(width: 118)
                }
                .fixedSize()
            }
            .buttonStyle(.plain)
            SpeedControl()
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner)
            .strokeBorder(Theme.hairline, lineWidth: 1))
    }

    // ── Expanded: the full time console ──────────────────────────────────

    private var console: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(engine.state.date.description) · \(engine.simDayName)".uppercased())
                    .font(.data(.caption2)).tracking(0.85)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button {
                    expanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            weekStrip(height: 5, labeled: true)
            HStack(spacing: 8) {
                SpeedControl()
                Button {
                    engine.stepOneWeek()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.frame.fill").font(.system(size: 9))
                        Text("Step wk").font(.game(.caption, weight: .medium))
                    }
                }
                .buttonStyle(GameButtonStyle(color: Theme.sky, prominent: true))
                .disabled(engine.clockIsHeld)
            }
        }
        .padding(12)
        .frame(width: 268)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner)
            .strokeBorder(Theme.hairline, lineWidth: 1))
    }

    /// Seven segments, one per day: filled = elapsed, cornflower = today.
    /// The week filling toward the settle is the sim's heartbeat — shown,
    /// not implied.
    private func weekStrip(height: CGFloat, labeled: Bool) -> some View {
        let dayIndex = min(6, Int(engine.weekProgress * 7))
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < dayIndex ? Color.white.opacity(0.45)
                              : i == dayIndex ? Theme.cornflower
                              : Color.white.opacity(0.10))
                        .frame(height: height)
                    if labeled {
                        Text(days[i])
                            .font(.data(.caption2))
                            .foregroundStyle(i == dayIndex ? Theme.cornflower
                                             : Theme.textTertiary)
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: dayIndex)
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

#Preview("Time console") {
    VStack {
        Spacer()
        HStack { Spacer(); SimClockPill().padding() }
    }
    .background(Theme.bg)
    .environment(GameEngine.previewGame())
    .preferredColorScheme(.dark)
}
