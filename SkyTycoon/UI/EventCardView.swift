//
//  EventCardView.swift
//  SkyTycoon — UI
//
//  The choice card (GDD §4.7) — icon medallion, flavor text, full-width
//  option buttons. A card being dealt, not an alert (DESIGN_SYSTEM.md §4).
//

import SwiftUI

struct EventCardView: View {
    @Environment(GameEngine.self) private var engine
    let event: GameEvent

    private var categoryIcon: String {
        switch event.category {
        case .market: "chart.line.downtrend.xyaxis"
        case .weather: "cloud.bolt.rain.fill"
        case .labor: "person.3.fill"
        case .technical: "wrench.and.screwdriver.fill"
        case .opportunity: "sparkles"
        case .regulatory: "checkmark.shield.fill"
        case .pr: "megaphone.fill"
        case .story: "envelope.open.fill"   // Aunt Meera's beats
        }
    }

    private var tint: Color { event.isNegative ? Theme.warn : Theme.profit }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: categoryIcon)
                    .font(.system(size: 30))
                    .foregroundStyle(tint)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text(event.title)
                    .font(.display(.title2))
                    .foregroundStyle(Theme.textPrimary)
                Text(event.firedOn.description)
                    .font(.game(.caption2, weight: .semibold)).tracking(1)
                    .foregroundStyle(Theme.textSecondary)
                Text(event.body)
                    .font(.game(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(Array(event.options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        engine.resolveEvent(option: option)
                    } label: {
                        Text(option.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GameButtonStyle(color: tint, prominent: index == 0))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bgElevated)
        .presentationDetents([.medium])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
    }
}
