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

    /// The sheet sizes to its content (the receipt pattern): long lawsuit
    /// bodies get room instead of truncating in a fixed medium detent.
    @State private var contentHeight: CGFloat = 380

    var body: some View {
        ScrollView {
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
                        .multilineTextAlignment(.center)
                    Text(event.firedOn.description)
                        .font(.game(.caption2, weight: .semibold)).tracking(1)
                        .foregroundStyle(Theme.textSecondary)
                    Text(event.body)
                        .font(.game(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(Array(event.options.enumerated()), id: \.element.id) { index, option in
                        Button {
                            engine.resolveEvent(option: option)
                        } label: {
                            Text(option.label).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GameButtonStyle(color: tint, prominent: index == 0,
                                                     lines: 2))
                    }
                }
            }
            .padding(24)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) {
                contentHeight = $0
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity)
        .background(Theme.bgElevated)
        .presentationDetents([.height(min(contentHeight + 24, 720))])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
    }
}

// Regression pin (the receipt lesson): the sheet-presented preview is the
// one that exercises detents — long lawsuit bodies must not truncate.
#Preview("Lawsuit card (long body)") {
    Color.black.sheet(isPresented: .constant(true)) {
        EventCardView(event: GameEvent(
            id: UUID(), cardID: "teaSpill", category: .pr, isNegative: true,
            title: "Scalding Tea, Furious Passenger",
            body: "Trevor Reed (4.1★ · 48 wk with you) spilled scalding tea over a passenger during service, and the burns needed treatment. The passenger's lawyers want $180.0K. Counsel's read: a strong record wins a public trial; a thin one gets torn apart on the stand.",
            options: [
                EventOption(label: "Settle quietly (−$180,000 · never makes the news)",
                            effects: []),
                EventOption(label: "Fight it in court (public · verdict rides on her record)",
                            effects: []),
            ],
            firedOn: GameDate(week: 31, year: 2)))
            .environment(GameEngine.previewGame())
    }
    .preferredColorScheme(.dark)
}
