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

#Preview("Roster rows") {
    RosterRowsPreview()
}

// Immediacy pin: assigning a plane mid-week moves the Workload meter NOW.
// Top card = baseline; bottom card = same pool right after one more plane
// was leased and assigned, no settle in between.
#Preview("Workload moves on assignment") {
    WorkloadProjectionPreview()
}

private struct WorkloadProjectionPreview: View {
    private let baseline = GameEngine.previewGame()
    private let assigned: GameEngine
    init() {
        let e = GameEngine.previewGame()
        let type = e.state.fleet[0].type
        if e.leaseAircraft(type: type, nickname: "PROOF-1"),
           let plane = e.state.fleet.last {
            e.assign(aircraftID: plane.id, to: e.state.routes[0].id)
        }
        assigned = e
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                StaffPoolCard(role: .pilots, pool: baseline.state.staff[.pilots]!,
                              accent: Theme.violet, onHiring: { _ in })
                    .environment(baseline)
                StaffPoolCard(role: .pilots, pool: assigned.state.staff[.pilots]!,
                              accent: Theme.violet, onHiring: { _ in })
                    .environment(assigned)
            }
            .padding()
        }
        .background(Theme.bg)
        .preferredColorScheme(.dark)
    }
}

private struct RosterRowsPreview: View {
    private let engine = GameEngine.previewGame()
    var body: some View {
        ScrollView {
            StaffPoolCard(role: .pilots, pool: engine.state.staff[.pilots]!,
                          accent: Theme.violet, onHiring: { _ in }, expanded: true)
                .padding()
        }
        .background(Theme.bg)
        .environment(engine)
        .preferredColorScheme(.dark)
    }
}

private struct StaffPoolCard: View {
    @Environment(GameEngine.self) private var engine
    let role: StaffRole
    let pool: StaffPool
    let accent: Color
    let onHiring: (StaffRole) -> Void

    init(role: StaffRole, pool: StaffPool, accent: Color,
         onHiring: @escaping (StaffRole) -> Void, expanded: Bool = false) {
        self.role = role
        self.pool = pool
        self.accent = accent
        self.onHiring = onHiring
        _rosterExpanded = State(initialValue: expanded)
    }
    @State private var rosterExpanded = false

    private var roleApplicants: [JobApplicant] {
        engine.state.applicants.filter { $0.role == role }
    }

    var body: some View {
        GameCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName).font(.game(.headline, weight: .bold))
                    StarRating(rating: pool.skill, size: 9)
                }
                Spacer()
                StatusBadge(text: "\(pool.headcount) staff", color: accent)
            }

            // Workload is a LIVE projection (immediacy rule): a hire or an
            // assignment change moves this meter the moment it happens.
            let workload = engine.projectedUtilization(role: role)
            HStack(spacing: 14) {
                MeterRow(label: "Happiness", value: pool.happiness / 100,
                         display: "\(Int(pool.happiness))",
                         color: Theme.health(pool.happiness / 100))
                MeterRow(label: "Workload", value: min(workload, 1.0),
                         display: "\(Int(workload * 100))%",
                         color: workloadColor(workload))
            }

            warningView

            Divider().overlay(Theme.hairline)
            PillStepper(label: "Weekly wage", value: pool.weeklyWage.wageMoney, accent: accent,
                onDecrement: { engine.setWage(role: role, wage: pool.weeklyWage - 50) },
                onIncrement: { engine.setWage(role: role, wage: pool.weeklyWage + 50) })

            // ── Recruitment: hiring happens through job ads ──────────────
            if let weeksLeft = engine.state.jobPostings[role] {
                HStack {
                    Label("Ad running · \(weeksLeft) wk left", systemImage: "megaphone.fill")
                        .font(.game(.caption, weight: .semibold)).foregroundStyle(accent)
                    Spacer()
                }
            } else {
                Button {
                    engine.postJobAd(role: role)
                } label: {
                    Text("Post job ad · \(Balance.jobAdFee.money)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(color: accent))
                .disabled(engine.state.cash < Balance.jobAdFee)
            }

            // ── The roster: every individual, with their own pink slip ───
            if !pool.members.isEmpty {
                DisclosureGroup(isExpanded: $rosterExpanded) {
                    ForEach(pool.members) { member in
                        memberRow(member)
                    }
                } label: {
                    Label("Roster (\(pool.members.count))", systemImage: "person.text.rectangle")
                        .font(.game(.caption, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
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
        // New hires are on the job the moment the contract inks (2026-07-20);
        // the meta line just marks them fresh for the week.
        let justJoined = member.hiredOn == engine.state.date
        return HStack(spacing: 10) {
            PersonAvatar(avatar: member.avatar, name: member.name, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.game(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    StarRating(rating: member.skill, size: 8)
                    Text(justJoined
                         ? "\(member.weeklyWage.wageMoney)/wk · just joined"
                         : "\(member.weeklyWage.wageMoney)/wk · since \(member.hiredOn.description)")
                        .font(.game(.caption2))
                        .foregroundStyle(justJoined ? Theme.cornflower : Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            Button("Fire") { engine.fireStaff(role: role, memberID: member.id) }
                .buttonStyle(GameButtonStyle(finish: .obsidian))
        }
        .padding(.vertical, 4)
    }

    private func workloadColor(_ utilization: Double) -> Color {
        switch utilization {
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
        } else if (pool.lastContractorShare ?? 0) > 0.02 {
            warningLabel(contractorText, icon: "person.badge.clock.fill", color: Theme.warn)
        } else if engine.projectedUtilization(role: role) > 1.0 {
            warningLabel(overworkText, icon: "exclamationmark.triangle.fill", color: Theme.warn)
        }
    }

    private var contractorText: String {
        let share = Int(((pool.lastContractorShare ?? 0) * 100).rounded())
        if pool.headcount == 0 {
            return "Nobody hired. Contractors fly all your \(role.displayName.lowercased()) hours at premium rates, and it shows in delays."
        }
        return "Roster maxed out: contractors cover \(share)% of \(role.displayName.lowercased()) hours at premium rates. Hire to bring it in-house."
    }

    private var overworkText: String {
        "Your \(role.displayName.lowercased()) are working \(Int((engine.projectedUtilization(role: role) - 1) * 100))% over roster. Expect delays and overtime pay."
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
    @State private var signed: SignedContract?
    /// A contract inked at the negotiation table waits here until that
    /// sheet finishes dismissing, then presents.
    @State private var pendingContract: SignedContract?
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
        // The desk closes itself once the last applicant is dealt with.
        .onChange(of: applicants.count) { _, _ in closeIfDeskEmpty() }
        .sheet(item: $negotiating, onDismiss: {
            if let contract = pendingContract {
                pendingContract = nil
                signed = contract
            } else {
                closeIfDeskEmpty()
            }
        }) { applicant in
            NegotiationSheet(applicant: applicant) { pendingContract = $0 }
        }
        .sheet(item: $signed, onDismiss: closeIfDeskEmpty) {
            ContractSignedCard(contract: $0)
        }
    }

    /// Dismiss the hiring sheet the moment the desk is empty — but only
    /// when no contract card or negotiation is still on top of it, so the
    /// last hire's flow finishes before the desk folds away.
    private func closeIfDeskEmpty() {
        guard applicants.isEmpty,
              negotiating == nil, signed == nil, pendingContract == nil else { return }
        // A short beat lets the final row's removal animation land.
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            guard applicants.isEmpty,
                  negotiating == nil, signed == nil, pendingContract == nil else { return }
            dismiss()
        }
    }

    // Info line first, keys on their own full-width row below — five
    // things sharing one line wrapped the meta and truncated the buttons.
    private func applicantRow(_ applicant: JobApplicant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PersonAvatar(avatar: applicant.avatar, name: applicant.name, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(applicant.name).font(.game(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        StarRating(rating: applicant.skill, size: 8)
                        Text("waits \(applicant.weeksRemaining) wk")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                // The quiet no: turn them away without a word.
                Button {
                    withAnimation(.snappy) {
                        _ = engine.rejectApplicant(applicantID: applicant.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
            if applicant.irritation > 0 {
                MeterRow(label: "Patience", value: 1 - applicant.irritation / 100,
                         display: "\(Int(100 - applicant.irritation))%",
                         color: Theme.health(1 - applicant.irritation / 100))
            }
            HStack(spacing: 10) {
                Button {
                    negotiating = applicant
                } label: {
                    Text("Negotiate").frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(finish: .obsidian))
                Button {
                    // Capture the contract before the applicant leaves state.
                    let contract = SignedContract(applicant: applicant,
                                                  wage: applicant.askingWage)
                    if engine.hireApplicant(applicantID: applicant.id) {
                        signed = contract
                    }
                } label: {
                    Text("Hire · \(applicant.askingWage.wageMoney)/wk").frame(maxWidth: .infinity)
                }
                .buttonStyle(GameButtonStyle(finish: .bronze))
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
    }
}

// ── The negotiation table ────────────────────────────────────────────────

private struct NegotiationSheet: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let applicant: JobApplicant
    var onSigned: (SignedContract) -> Void = { _ in }
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
                        TickerText(text: person.askingWage.wageMoney + "/wk",
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
                        let contract = SignedContract(applicant: person,
                                                      wage: person.askingWage)
                        if engine.hireApplicant(applicantID: person.id) {
                            onSigned(contract)
                        }
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
            onSigned(SignedContract(applicant: person, wage: offer))
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

// ── The signing moment ───────────────────────────────────────────────────

/// A hire caught at the instant of signing — captured before the applicant
/// leaves state, because the roster only knows them as a member afterward.
private struct SignedContract: Identifiable {
    let id = UUID()
    let name: String
    let avatar: String?
    let role: StaffRole
    let wage: Double
    let skill: Double

    init(applicant: JobApplicant, wage: Double) {
        name = applicant.name
        avatar = applicant.avatar
        role = applicant.role
        self.wage = wage
        skill = applicant.skill
    }
}

/// The contract inks in front of you: portrait arrives, terms stamped,
/// then the new hire's signature draws itself across the line. They are
/// on the job the moment the ink dries.
private struct ContractSignedCard: View {
    @Environment(\.dismiss) private var dismiss
    let contract: SignedContract
    @State private var arrived = false
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.caption2.weight(.medium)).polishedSilver()
                Text("EMPLOYMENT CONTRACT")
                    .font(.data(.caption2)).tracking(0.9)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 22)

            PersonAvatar(avatar: contract.avatar, name: contract.name, size: 76)
                .scaleEffect(arrived ? 1 : 0.6)
                .opacity(arrived ? 1 : 0)

            VStack(spacing: 4) {
                Text(contract.name)
                    .font(.display(.title2)).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                StarRating(rating: contract.skill, size: 10)
            }

            VStack(spacing: 8) {
                termRow("Position", contract.role.displayName)
                termRow("Weekly wage", "\(contract.wage.wageMoney)/wk")
                termRow("Starts", "Immediately")
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))

            VStack(spacing: 5) {
                HandwrittenSignature(name: contract.name, size: 34)
                Rectangle().fill(Theme.hairline)
                    .frame(height: 1).frame(maxWidth: 220)
                Text("Employee signature")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 4)

            Button {
                dismiss()
            } label: {
                Text("Welcome aboard").frame(maxWidth: .infinity)
            }
            .buttonStyle(GameButtonStyle(finish: .bronze))
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) {
            contentHeight = $0
        }
        .presentationDetents([.height(min(contentHeight + 24, 720))])
        .presentationBackground(Theme.bgElevated)
        .preferredColorScheme(.dark)
        .holdsSimClock()
        .sensoryFeedback(.success, trigger: arrived)
        .onAppear { withAnimation(.spring(duration: 0.5)) { arrived = true } }
    }

    private func termRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.game(.caption, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

// Hiring desk pin (flat): applicant rows with hire, negotiate, and the
// quiet reject cross.
#Preview("Hiring desk") {
    HiringSheet(role: .pilots)
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}

// Signing-moment pin (flat): the contract card as presented after a hire.
#Preview("Contract signed") {
    let applicant = JobApplicant(id: UUID(), role: .cabinCrew,
                                 name: "Maya Thompson",
                                 avatar: "avatar_crew_f_03",
                                 skill: 3.4, askingWage: 940,
                                 flexibility: 0.5, irritation: 0,
                                 weeksRemaining: 3)
    ContractSignedCard(contract: SignedContract(applicant: applicant, wage: 940))
        .background(Theme.bgElevated)
        .environment(GameEngine.previewGame())
        .preferredColorScheme(.dark)
}
