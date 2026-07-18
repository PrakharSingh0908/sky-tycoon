//
//  PeopleView.swift
//  SkyTycoon — UI (violet accent)
//
//  One card per staff pool: happiness and workload meters, plain-language
//  warnings, headcount/wage pill-steppers (GDD §4.4, DESIGN_SYSTEM.md §4).
//

import SwiftUI

struct PeopleView: View {
    @Environment(GameEngine.self) private var engine
    @State private var hiringRole: StaffRole?
    private let accent = Theme.violet

    var body: some View {
        GameScreen(title: "People", accent: accent) {
            ForEach(StaffRole.allCases) { role in
                if let pool = engine.state.staff[role] {
                    StaffPoolCard(role: role, pool: pool, accent: accent,
                                  onHiring: { hiringRole = $0 })
                }
            }
        }
        .sheet(item: $hiringRole) { HiringSheet(role: $0) }
    }
}

#Preview {
    PeopleView().environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

private struct StaffPoolCard: View {
    @Environment(GameEngine.self) private var engine
    let role: StaffRole
    let pool: StaffPool
    let accent: Color
    let onHiring: (StaffRole) -> Void
    @State private var rosterExpanded = false

    private var roleApplicants: [JobApplicant] {
        engine.state.applicants.filter { $0.role == role }
    }

    var body: some View {
        GameCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName).font(.game(.headline, weight: .bold))
                    HStack(spacing: 4) {
                        StarRating(rating: pool.skill, size: 9)
                        Text(String(format: "%.1f skill", pool.skill))
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                let joining = pool.members.filter { $0.hiredOn == engine.state.date }.count
                if joining > 0 {
                    StatusBadge(text: "+\(joining) joining", color: Theme.teal)
                }
                StatusBadge(text: "\(pool.headcount) staff", color: accent)
            }

            HStack(spacing: 14) {
                MeterRow(label: "Happiness", value: pool.happiness / 100,
                         display: "\(Int(pool.happiness))",
                         color: Theme.health(pool.happiness / 100))
                MeterRow(label: "Workload", value: min(pool.lastUtilization, 1.0),
                         display: "\(Int(pool.lastUtilization * 100))%",
                         color: workloadColor)
            }

            warningView

            Divider().overlay(Theme.hairline)
            PillStepper(label: "Weekly wage", value: pool.weeklyWage.money, accent: accent,
                onDecrement: { engine.setWage(role: role, wage: pool.weeklyWage - 50) },
                onIncrement: { engine.setWage(role: role, wage: pool.weeklyWage + 50) })

            // ── Recruitment: hiring happens through job ads ──────────────
            HStack {
                if let weeksLeft = engine.state.jobPostings[role] {
                    Label("Ad running · \(weeksLeft) wk left", systemImage: "megaphone.fill")
                        .font(.game(.caption, weight: .semibold)).foregroundStyle(accent)
                } else {
                    Button("Post job ad · \(Balance.jobAdFee.money)") {
                        engine.postJobAd(role: role)
                    }
                    .buttonStyle(GameButtonStyle(color: accent))
                    .disabled(engine.state.cash < Balance.jobAdFee)
                }
                Spacer()
            }

            // ── The roster: every individual, with their own pink slip ───
            if !pool.members.isEmpty {
                DisclosureGroup(isExpanded: $rosterExpanded) {
                    ForEach(pool.members) { member in
                        memberRow(member)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Label("Roster (\(pool.members.count))", systemImage: "person.text.rectangle")
                            .font(.game(.caption, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        // Pending starts surface on the collapsed row too.
                        let joining = pool.members.filter { $0.hiredOn == engine.state.date }.count
                        if joining > 0 {
                            Text("· \(joining) join\(joining == 1 ? "s" : "") next wk")
                                .font(.game(.caption, weight: .semibold))
                                .foregroundStyle(Theme.teal)
                        }
                    }
                }
                .tint(Theme.textSecondary)
            }

            // Applicants live in the Hiring sheet — one button, not N rows.
            if !roleApplicants.isEmpty {
                Button {
                    onHiring(role)
                } label: {
                    Label("Applicants waiting (\(roleApplicants.count))",
                          systemImage: "person.crop.circle.badge.clock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: accent, prominent: true))
            }
        }
    }

    private func memberRow(_ member: StaffMember) -> some View {
        // Hired mid-week: on the roster now, on the job from the next
        // settle — say so instead of leaving the lag unexplained.
        let justJoined = member.hiredOn == engine.state.date
        return HStack(spacing: 8) {
            PersonAvatar(avatar: member.avatar, name: member.name, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.game(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 4) {
                    StarRating(rating: member.skill, size: 8)
                    Text("\(member.weeklyWage.money)/wk · since \(member.hiredOn.description)")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if justJoined {
                StatusBadge(text: "On duty next wk", color: Theme.teal)
            }
            Button("Fire") { engine.fireStaff(role: role, memberID: member.id) }
                .buttonStyle(GameButtonStyle(color: Theme.loss))
        }
        .padding(.vertical, 4)
    }

    private var workloadColor: Color {
        switch pool.lastUtilization {
        case ..<0.85: Theme.profit
        case ..<1.0: Theme.warn
        default: Theme.loss
        }
    }

    @ViewBuilder private var warningView: some View {
        if pool.headcount > 0 && pool.happiness < Balance.strikeRiskHappinessThreshold {
            warningLabel("Morale critical: strike risk. Raise pay or cut workload now.",
                         icon: "exclamationmark.octagon.fill", color: Theme.loss)
        } else if pool.headcount > 0 && pool.happiness < Balance.attritionHappinessThreshold {
            warningLabel("Unhappy. People are quitting each week.",
                         icon: "person.fill.xmark", color: Theme.warn)
        } else if pool.lastUtilization > 1.0 {
            warningLabel(overworkText, icon: "exclamationmark.triangle.fill", color: Theme.warn)
        }
    }

    private var overworkText: String {
        if pool.headcount == 0 {
            return "Nobody hired. Contractors cover \(role.displayName.lowercased()) at 1.5× rates, and it shows in delays."
        }
        return "Your \(role.displayName.lowercased()) are working \(Int((pool.lastUtilization - 1) * 100))% over roster. Expect delays and overtime pay."
    }

    private func warningLabel(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.game(.caption, weight: .medium))
            .foregroundStyle(color)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

// ── The hiring desk: applicants for one role, out of the pool card ───────

private struct HiringSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let role: StaffRole
    @State private var negotiating: JobApplicant?
    private let accent = Theme.violet

    private var applicants: [JobApplicant] {
        engine.state.applicants.filter { $0.role == role }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hiring · \(role.displayName)")
                    .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                    .padding(.top, 20)
                if applicants.isEmpty {
                    Text("Nobody at the desk. Applicants arrive while a job ad runs.")
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
                ForEach(applicants) { applicant in
                    applicantRow(applicant)
                }
                Button("Done") { dismiss() }
                    .buttonStyle(GameButtonStyle(color: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.bgElevated)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()   // patience doesn't drain while you're deciding
        .sheet(item: $negotiating) { NegotiationSheet(applicant: $0) }
    }

    private func applicantRow(_ applicant: JobApplicant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PersonAvatar(avatar: applicant.avatar, name: applicant.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(applicant.name).font(.game(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 4) {
                        StarRating(rating: applicant.skill, size: 8)
                        Text("asks \(applicant.askingWage.money)/wk · waits \(applicant.weeksRemaining) wk")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Button("Negotiate") { negotiating = applicant }
                    .buttonStyle(GameButtonStyle(color: accent))
                Button("Hire") { engine.hireApplicant(applicantID: applicant.id) }
                    .buttonStyle(GameButtonStyle(color: accent, prominent: true))
            }
            if applicant.irritation > 0 {
                MeterRow(label: "Patience", value: 1 - applicant.irritation / 100,
                         display: "\(Int(100 - applicant.irritation))%",
                         color: Theme.health(1 - applicant.irritation / 100))
            }
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }
}

// ── The negotiation table ────────────────────────────────────────────────

private struct NegotiationSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let applicant: JobApplicant
    @State private var offer: Double = 0
    @State private var response: String?

    /// Live copy from state (asking wage / irritation move as you haggle).
    private var current: JobApplicant? {
        engine.state.applicants.first { $0.id == applicant.id }
    }

    var body: some View {
        VStack(spacing: 16) {
            if let person = current {
                VStack(spacing: 8) {
                    PersonAvatar(avatar: person.avatar, name: person.name, size: 72)
                    Text(person.name).font(.display(.title2))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 6) {
                        StarRating(rating: person.skill, size: 11)
                        Text(person.role.displayName)
                            .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 12)

                VStack(spacing: 10) {
                    HStack {
                        Text("Asking").font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TickerText(text: person.askingWage.money + "/wk",
                                   font: .game(.subheadline, weight: .bold))
                    }
                    MeterRow(label: "Patience", value: 1 - person.irritation / 100,
                             display: "\(Int(100 - person.irritation))%",
                             color: Theme.health(1 - person.irritation / 100))
                    Divider().overlay(Theme.hairline)
                    HStack {
                        Text("Your offer").font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TickerText(text: offer.money + "/wk",
                                   font: .game(.subheadline, weight: .bold), color: Theme.violet)
                    }
                    Slider(value: $offer,
                           in: (person.askingWage * 0.5)...(person.askingWage * 1.05))
                        .tint(Theme.violet)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

                if let response {
                    Text(response)
                        .font(.game(.caption, weight: .medium))
                        .foregroundStyle(Theme.warn)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button("Make offer") { makeOffer(person) }
                        .buttonStyle(GameButtonStyle(color: Theme.violet, prominent: true))
                    Button("Hire at asking") {
                        engine.hireApplicant(applicantID: person.id)
                        dismiss()
                    }
                    .buttonStyle(GameButtonStyle(color: Theme.violet))
                }
            } else {
                Text("They've left the table.")
                    .font(.game(.headline)).foregroundStyle(Theme.textSecondary)
                    .padding(.top, 40)
                Button("Close") { dismiss() }
                    .buttonStyle(GameButtonStyle(color: Theme.violet))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bgElevated)
        .presentationDetents([.medium])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()   // applicants' patience shouldn't drain mid-haggle
        .onAppear { offer = applicant.askingWage * 0.9 }
    }

    private func makeOffer(_ person: JobApplicant) {
        switch engine.negotiate(applicantID: person.id, offer: offer) {
        case .accepted:
            dismiss()
        case .countered(let newAsking):
            response = newAsking < person.askingWage
                ? "\"I could do \(newAsking.money) a week.\""
                : "\"That's not going to work for me.\""
        case .walkedAway:
            response = "They walked away from the table."
        case nil:
            dismiss()
        }
    }
}
