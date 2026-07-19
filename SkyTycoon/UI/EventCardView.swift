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

    /// Incident cards put the person at the center — literally: the
    /// accused's portrait replaces the category icon, with the incident
    /// (the spilling tea) breaking over its bottom-right corner.
    @ViewBuilder private var medallion: some View {
        if let id = event.subjectID, let member = engine.staffMember(id: id) {
            PersonAvatar(avatar: member.avatar, name: member.name, size: 76)
                .overlay(alignment: .bottomTrailing) {
                    if event.cardID == "teaSpill",
                       let tea = UIImage(named: "incident_tea") {
                        Image(uiImage: tea)
                            .resizable().scaledToFit()
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                            .offset(x: 8, y: 4)
                    } else {
                        ZStack {
                            Circle().fill(Theme.bgElevated)
                            Circle().fill(tint.opacity(0.18))
                            Image(systemName: categoryIcon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                        .offset(x: 5, y: 2)
                    }
                }
        } else {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: categoryIcon)
                    .font(.system(size: 30))
                    .foregroundStyle(tint)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                medallion
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    Text(event.title)
                        .font(.display(.title2))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(event.firedOn.description)
                        .font(.game(.caption2, weight: .semibold)).tracking(1)
                        .foregroundStyle(Theme.textSecondary)
                    // Paragraphs split on blank lines; the counsel line
                    // renders in white so the advice stands apart.
                    ForEach(Array(event.body.components(separatedBy: "\n\n").enumerated()),
                            id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.game(.subheadline))
                            .foregroundStyle(paragraph.hasPrefix("Counsel")
                                             ? Theme.textPrimary : Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, paragraph.hasPrefix("Counsel") ? 6 : 0)
                    }
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

// Flat variant: the full card in one snapshot (sheet previews catch the
// rise animation), here the hard-landing flavor with a pilot subject.
#Preview("Hard landing card (flat)") {
    HardLandingCardPreview()
}

private struct HardLandingCardPreview: View {
    private let engine = GameEngine.previewGame()
    var body: some View {
        let member = engine.state.staff[.pilots]?.members.first
        EventCardView(event: GameEvent(
            id: UUID(), cardID: "hardLanding", category: .pr, isNegative: true,
            title: "Hard Landing, Injured Passenger",
            body: "\(member?.name ?? "Vikram Rao") (3.6★ · 92 wk with you) landed hard. An elderly passenger's spine was injured. The family's lawyers want $300.0K.\n\nCounsel: settling stays out of the news. Court is public, and the verdict rides on their record.",
            options: [
                EventOption(label: "Settle quietly · −$300K", effects: []),
                EventOption(label: "Fight it in court", effects: []),
            ],
            firedOn: GameDate(week: 44, year: 2),
            subjectID: member?.id))
            .environment(engine)
            .preferredColorScheme(.dark)
    }
}

// Regression pin (the receipt lesson): the sheet-presented preview is the
// one that exercises detents — long lawsuit bodies must not truncate, and
// the accused's portrait wears the spilling tea.
#Preview("Lawsuit card (long body)") {
    LawsuitCardPreview()
}

private struct LawsuitCardPreview: View {
    private let engine = GameEngine.previewGame()
    var body: some View {
        let member = engine.state.staff[.cabinCrew]?.members.first
        Color.black.sheet(isPresented: .constant(true)) {
            EventCardView(event: GameEvent(
                id: UUID(), cardID: "teaSpill", category: .pr, isNegative: true,
                title: "Scalding Tea, Furious Passenger",
                body: "\(member?.name ?? "Trevor Reed") (4.1★ · 48 wk with you) spilled scalding tea on a passenger. The burns needed treatment. Their lawyers want $180.0K.\n\nCounsel: settling stays out of the news. Court is public, and the verdict rides on their record.",
                options: [
                    EventOption(label: "Settle quietly · −$180K", effects: []),
                    EventOption(label: "Fight it in court", effects: []),
                ],
                firedOn: GameDate(week: 31, year: 2),
                subjectID: member?.id))
                .environment(engine)
        }
        .preferredColorScheme(.dark)
    }
}
