//
//  GameEngine.swift
//  SkyTycoon — Simulation core (pure Swift, no SwiftUI)
//
//  The single mutation owner. GameEngine owns the one GameState and is the
//  only thing allowed to mutate it. SwiftUI observes it via @Observable
//  (from the Observation framework — deliberately NOT SwiftUI, so the sim
//  core stays UI-free and unit-testable).
//

import Foundation
import Observation

@Observable
final class GameEngine {
    private(set) var state: GameState
    /// Difficulty levers (nil in pre-difficulty saves reads as .standard).
    var difficulty: Difficulty { state.difficulty ?? .standard }
    var speed: SimSpeed = .paused

    enum SimSpeed: Double, CaseIterable {
        case paused = 0, x1 = 1, x2 = 2, x4 = 4
    }

    /// Real seconds per WEEK at 1x; a day is 1/7 of it (GDD §23). A full
    /// week still takes the same wall-clock time — it just settles daily.
    private let secondsPerWeek: Double = 16
    private var secondsPerDay: Double { secondsPerWeek / 7 }
    private var accumulator: Double = 0
    private var timer: Timer?

    /// The running week's report, accumulating each day's 1/7 share until the
    /// 7-day close finalizes it. Transient: saves happen only at week close.
    @ObservationIgnored private var weekReport: WeeklyReport?

    /// Settlement cash already paid out this week (crashes, lawsuit/recall
    /// verdicts) — folded into the week's report as its Incidents line at
    /// close (GDD §23), so it dents quarter profit without re-charging cash.
    @ObservationIgnored private var pendingIncident: Double = 0

    /// Presentation only: how far through the CURRENT day the clock has
    /// accrued (the sim advances in whole days).
    var dayProgress: Double { min(accumulator / secondsPerDay, 0.999) }
    /// Which day of the week is in progress, 0...6 (Mon…Sun).
    var dayIndex: Int { min(6, (state.date.day ?? 1) - 1) }
    /// The weekday shown on the sim clock.
    var simDayName: String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][dayIndex]
    }

    /// Transient UI hold: while decision UI is open (negotiation, purchase
    /// receipts, confirmations), the clock doesn't advance — the player's
    /// chosen speed resumes when the last one closes. Counted so nested
    /// sheets stack safely. Not part of the save.
    private var interactionHolds = 0
    /// True only for decision UI holds (negotiation, receipts, confirmations)
    /// that show the neutral "held" indicator. An event card also stops the
    /// clock — but through the pendingEvent guard in clockFired, NOT here — so
    /// it neither flips the speed control to paused NOR lights the held
    /// indicator: the player's chosen speed simply resumes when the card is
    /// answered. (The event sheet self-sizes, so the pill stays visible
    /// behind it; showing a pause there for an event read as a false pause.)
    var clockIsHeld: Bool { interactionHolds > 0 }
    func beginInteraction() { interactionHolds += 1 }
    func endInteraction() { interactionHolds = max(0, interactionHolds - 1) }

    // ── Init / new game ──────────────────────────────────────────────────

    init(state: GameState) {
        self.state = state
        backfillAvatars()
        retagFleet()
        refreshPendingEventCopy()
        // §22 grandfather: saves from before fleet tiers keep everything.
        if self.state.unlockedFleetTier == nil {
            self.state.unlockedFleetTier = Balance.maxFleetTier
        }
    }

    // ── Fleet tiers (GDD §22) ────────────────────────────────────────────

    var unlockedFleetTier: Int { state.unlockedFleetTier ?? Balance.maxFleetTier }

    /// Can this model be acquired yet?
    func isUnlocked(_ type: AircraftType) -> Bool {
        Balance.fleetTier(of: type) <= unlockedFleetTier
    }

    /// The next tier's requirement, for showroom lock labels.
    var nextTierThreshold: Double? {
        let next = unlockedFleetTier + 1
        guard next <= Balance.maxFleetTier else { return nil }
        return Balance.fleetTierThresholds[next]
    }

    /// Settle-time check: crossing a market-cap threshold grants the next
    /// tier and deals the unlock card — the drawer opening on new metal.
    private func checkFleetUnlocks() {
        guard state.pendingEvent == nil,
              unlockedFleetTier < Balance.maxFleetTier else { return }
        let next = unlockedFleetTier + 1
        guard marketCap >= Balance.fleetTierThresholds[next] else { return }
        state.unlockedFleetTier = next
        let models = AircraftType.allCases
            .filter { Balance.fleetTier(of: $0) == next }
            .map { Balance.specs[$0]!.displayName }
        let unique = Array(NSOrderedSet(array: models)) as! [String]
        state.pendingEvent = GameEvent(
            id: UUID(), cardID: "fleetUnlock", category: .opportunity,
            isNegative: false,
            title: Balance.fleetTierNames[next],
            body: "Your market cap cleared \(Balance.fleetTierThresholds[next].money). The registry has cleared you for a new class of aircraft: \(unique.joined(separator: ", ")). The showroom has them waiting.",
            options: [EventOption(label: "To the showroom", effects: [])],
            firedOn: state.date)
        state.lastEventTotalWeek = state.date.totalWeeks
        logEvent(title: "Unlocked: \(Balance.fleetTierNames[next])", isNegative: false)
    }

    // ── Fleet registration prefix (2026-07-19) ───────────────────────────
    // Tail codes carry the airline's initials ("Blue Dart" → BD-A, BD-B…).

    /// Two letters from the airline name: initials of the first two words,
    /// or the first two letters of a single-word name. Fallback "VT".
    var fleetPrefix: String {
        let words = state.airlineName.split(separator: " ").filter { !$0.isEmpty }
        let letters: String
        if words.count >= 2 {
            letters = words.prefix(2).compactMap(\.first).map(String.init).joined()
        } else if let word = words.first {
            letters = String(word.prefix(2))
        } else {
            letters = "VT"
        }
        return letters.uppercased()
    }

    /// Re-registers auto-issued tail codes (XX-A pattern) under the current
    /// prefix — pre-feature saves carried the fixed "VT" prefix.
    private func retagFleet() {
        let prefix = fleetPrefix
        for i in state.fleet.indices {
            let nick = state.fleet[i].nickname
            guard let dash = nick.firstIndex(of: "-"),
                  nick[..<dash].allSatisfy(\.isLetter),
                  nick[..<dash] != Substring(prefix) else { continue }
            state.fleet[i].nickname = prefix + nick[dash...]
        }
    }

    // ── Avatar backfill for pre-portrait saves (2026-07-19) ──────────────
    // Deterministic from data the person already carries: the first name
    // picks the gender pool, the stable UUID picks the variant. No RNG
    // stream is consumed, so sim determinism is untouched.

    private static func inferredAvatar(name: String, id: UUID, role: StaffRole) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        let male = Balance.firstNamesFemale.contains(first) ? false : true
        let variants = Balance.avatarVariants(role: role, male: male)
        let hash = id.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Balance.avatarName(role: role, male: male, variant: (hash % variants) + 1)
    }

    private func backfillAvatars() {
        for role in StaffRole.allCases {
            guard var pool = state.staff[role] else { continue }
            var changed = false
            for i in pool.members.indices where pool.members[i].avatar == nil {
                pool.members[i].avatar = Self.inferredAvatar(
                    name: pool.members[i].name, id: pool.members[i].id, role: role)
                changed = true
            }
            if changed { state.staff[role] = pool }
        }
        for i in state.applicants.indices where state.applicants[i].avatar == nil {
            let applicant = state.applicants[i]
            state.applicants[i].avatar = Self.inferredAvatar(
                name: applicant.name, id: applicant.id, role: applicant.role)
        }
    }

    static func newGame(airlineName: String, country: Country, seed: UInt64 = .random(in: 0...UInt64.max), difficulty: Difficulty = .standard) -> GameEngine {
        let profile = Balance.countryProfiles[country]!
        var rng = SeededRandomNumberGenerator(seed: seed)
        var staff: [StaffRole: StaffPool] = [:]
        for role in StaffRole.allCases {
            let count = role == .hq ? 3 : 0
            let wage = role.marketWage * profile.laborCost
            staff[role] = StaffPool(role: role, headcount: count,
                                    weeklyWage: wage,
                                    happiness: 70, skill: 2.0, lastUtilization: 0,
                                    members: (0..<count).map { _ in
                                        { () -> StaffMember in
                                            let p = Self.generatePerson(role: role, country: country, rng: &rng)
                                            return StaffMember(id: UUID(), name: p.name,
                                                    skill: 2.0, weeklyWage: wage,
                                                    hiredOn: GameDate(week: 1, year: 1),
                                                    avatar: p.avatar)
                                        }()
                                    })
        }
        let initialMarket = Self.generateUsedListings(rng: &rng)
        let state = GameState(
            seedRNG: rng,
            date: GameDate(week: 1, year: 1),
            country: country,
            difficulty: difficulty,
            airlineName: airlineName,
            // §22 Foundation Era: a small flat seed. Leasing a feeder and
            // making one route work IS the opening game.
            cash: Balance.auntSeedFund * difficulty.startingCashFactor,
            livery: .launch,
            trustFundActive: true,
            trustFundDeadline: GameDate(week: 52, year: 3),
            trustFundResolution: .pending,
            consecutiveProfitableQuarters: 0,
            reputation: 3.0,
            brandAwareness: Balance.startingAwareness, weeklyMarketingSpend: 0,
            letters: [], completedMilestones: [],
            weeksInsolvent: 0, isBankrupt: false,
            cities: Balance.cities(for: country),
            fleet: [], routes: [], staff: staff, loans: [],
            usedMarket: initialMarket,
            weeksUntilMarketRefresh: Balance.usedMarketRefreshWeeksMin,
            jobPostings: [:], applicants: [],
            sellerOrders: [:],
            pendingEvent: nil, activeEffects: [], lastNegativeEventTotalWeek: 0,
            // §22: new airlines EARN the flight line, tier by tier.
            unlockedFleetTier: 0,
            reports: [],
            netWorthHistory: [], cashHistory: [], reputationHistory: []
        )
        return GameEngine(state: state)
    }

    /// Gender-coherent identity: name and avatar agree (2026-07-19), and
    /// names come from the campaign country's labor market.
    private static func generatePerson(role: StaffRole, country: Country,
                                       rng: inout SeededRandomNumberGenerator)
        -> (name: String, avatar: String) {
        let male = Bool.random(using: &rng)
        let first = Balance.firstNames(country: country, male: male)
            .randomElement(using: &rng)!
        let last = Balance.lastNames(country: country).randomElement(using: &rng)!
        let variant = Int.random(in: 1...Balance.avatarVariants(role: role, male: male),
                                 using: &rng)
        return ("\(first) \(last)",
                Balance.avatarName(role: role, male: male, variant: variant))
    }

    /// Roster lookup across all pools (the event card shows the accused).
    func staffMember(id: UUID) -> StaffMember? {
        for role in StaffRole.allCases {
            if let member = state.staff[role]?.members.first(where: { $0.id == id }) {
                return member
            }
        }
        return nil
    }

    /// Recomputes a pool's aggregate wage/skill from its members (the sim
    /// runs on the aggregates; the roster is the source of truth).
    private func recomputeAggregates(_ pool: inout StaffPool) {
        guard !pool.members.isEmpty else { return }
        pool.weeklyWage = pool.members.map(\.weeklyWage).reduce(0, +) / Double(pool.members.count)
        pool.skill = min(5, pool.members.map(\.skill).reduce(0, +) / Double(pool.members.count))
    }

    /// Rolls a fresh set of second-hand listings from the seeded RNG
    /// (determinism preserved — same seed, same market, forever).
    private static func generateUsedListings(rng: inout SeededRandomNumberGenerator) -> [UsedListing] {
        let count = Int.random(in: Balance.usedMarketMinListings...Balance.usedMarketMaxListings, using: &rng)
        return (0..<count).map { _ in
            let type = AircraftType.allCases.randomElement(using: &rng)!
            let age = Double.random(in: Balance.usedAgeRange, using: &rng)
            let condition = Double.random(in: Balance.usedConditionRange, using: &rng)
            return UsedListing(id: UUID(), type: type, ageYears: age,
                               condition: condition,
                               price: Balance.usedPrice(type: type, ageYears: age, condition: condition))
        }
    }

    // ── Tick loop (fixed timestep) ───────────────────────────────────────

    func startClock() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.clockFired(delta: 1.0 / 30.0)
        }
    }
    func stopClock() { timer?.invalidate(); timer = nil }

    /// Step exactly one day and hold: the deliberate-play loop (adjust
    /// while paused → step → read the day). Deterministic — the same
    /// advanceDay the clock drives.
    func stepOneDay() {
        guard state.pendingEvent == nil, interactionHolds == 0,
              !state.isBankrupt else { return }
        speed = .paused
        accumulator = 0
        advanceDay()
    }

    private func clockFired(delta: Double) {
        guard speed != .paused, state.pendingEvent == nil, interactionHolds == 0,
              !state.isBankrupt else { return }
        accumulator += delta * speed.rawValue
        while accumulator >= secondsPerDay {
            accumulator -= secondsPerDay
            advanceDay()
            // An event holds the clock (clockIsHeld) without disturbing the
            // player's speed: the loop stops here, and time resumes at that
            // same speed once the card is dealt with. No pause is stamped
            // into the speed control, and the timeline doesn't lurch.
            if state.pendingEvent != nil { accumulator = 0; break }
        }
    }

    // ── The daily tick — the heart of the sim (GDD §23) ─────────────────
    // Continuous lines (revenue, costs, wear, drift) accrue 1/7 per day so
    // cash and every meter move daily; the discrete block (deliveries,
    // crash, events, trends, attrition, recruitment, market, quarter) runs
    // only on the 7-day CLOSE, drawing the seeded RNG once per week exactly
    // as before. Seven daily accruals sum to one old weekly settle, so the
    // §22 economy is unchanged — only the feedback cadence is daily.
    //
    // Compat: advance a full week by running seven days (used by previews).
    func advanceWeek() {
        for _ in 0..<7 where !state.isBankrupt { advanceDay() }
    }

    func advanceDay() {
        guard !state.isBankrupt else { return }
        let f = 1.0 / 7.0                       // this day's share of the week
        let close = (state.date.day ?? 1) >= 7  // the 7th day finalizes the week
        let profile = Balance.countryProfiles[state.country]!

        // The running week's report accumulates each day's 1/7 share.
        if weekReport == nil {
            weekReport = WeeklyReport(date: state.date, revenue: 0, fuelCost: 0,
                                      wageCost: 0, maintenanceCost: 0, loanCost: 0,
                                      leaseCost: 0, cabinCost: 0, marketingCost: 0,
                                      overheadCost: 0)
        }
        var report = weekReport!
        let profitBefore = report.profit     // cash books only THIS day's delta
        let revenueBefore = report.revenue   // P&L chart books this day's revenue

        // 2. CREW-HOURS (GDD §4.4) — demand vs roster capacity, for strain
        // and punctuality (which feed satisfaction). Non-mutating.
        var activePlanesByRoute: [[Aircraft]] = Array(repeating: [], count: state.routes.count)
        for r in state.routes.indices where state.routes[r].weeklyFrequency > 0 {
            activePlanesByRoute[r] = state.fleet.filter {
                state.routes[r].assignedAircraftIDs.contains($0.id) && $0.groundedWeeksRemaining == 0
            }
        }
        let crewDemandHours = liveCrewDemandHours()
        var utilization: [StaffRole: Double] = [:]
        for role in StaffRole.allCases {
            let demand = crewDemandHours[role] ?? 0
            let capacity = Double(state.staff[role]?.headcount ?? 0) * Balance.weeklyHoursPerStaff
            utilization[role] = capacity > 0 ? demand / capacity
                              : (demand > 0 ? Balance.maxStrainPerPool + 1 : 0)
        }
        var strain = 0.0
        for role in StaffRole.allCases {
            strain += Balance.strainWeight(role)
                * min(Balance.maxStrainPerPool, max(0, (utilization[role] ?? 0) - 1))
        }
        let opsSkill = ((state.staff[.pilots]?.skill ?? 1) + (state.staff[.ground]?.skill ?? 1)) / 2
        let punctuality = min(0.98, max(0.20,
            Balance.basePunctuality
            - Balance.strainDelayFactor * strain
            - Balance.skillDelayFactor * (1 - opsSkill / 5)))

        let fuelEventMult = state.activeEffects
            .filter { $0.kind == .fuelPrice }.reduce(1.0) { $0 * $1.multiplier }
            * trendMultiplier(.fuel)
        let demandEventMult = state.activeEffects
            .filter { $0.kind == .demand }.reduce(1.0) { $0 * $1.multiplier }
            * trendMultiplier(.demand)

        // 3. OPERATE ROUTES — a day's 1/7 share of the week's economics; the
        // route display values stay full-week projections (pillar 4).
        for r in state.routes.indices {
            let route = state.routes[r]
            guard route.weeklyFrequency > 0 else { continue }
            let activePlanes = activePlanesByRoute[r]
            guard !activePlanes.isEmpty else {
                state.routes[r].lastLoadFactor = 0
                state.routes[r].lastWeeklyProfit = 0
                state.routes[r].lastWeeklyRevenue = 0
                state.routes[r].lastWeeklyFuel = 0
                appendLoadFactor(0, routeIndex: r)
                continue
            }
            let econ = computeEconomics(route: route, planes: activePlanes,
                                        profile: profile,
                                        fuelEventMult: fuelEventMult,
                                        demandEventMult: demandEventMult)
            var avgComfort = activePlanes.map(\.comfortScore).reduce(0, +)
                / Double(activePlanes.count)
            avgComfort = min(1, avgComfort)
            let catering = route.catering ?? CateringLevel.none
            if catering != .none {
                report.cabinCost += econ.pax * catering.costPerPax * f
            }
            report.revenue += econ.revenue * f
            report.fuelCost += econ.fuel * f
            state.routes[r].lastLoadFactor = econ.loadFactor
            state.routes[r].lastWeeklyProfit = econ.revenue - econ.fuel
            state.routes[r].lastWeeklyRevenue = econ.revenue
            state.routes[r].lastWeeklyFuel = econ.fuel
            appendLoadFactor(econ.loadFactor, routeIndex: r)
            // Wear: this day's share of the week's block hours.
            for plane in activePlanes {
                if let idx = state.fleet.firstIndex(where: { $0.id == plane.id }) {
                    let spec = Balance.specs[plane.type]!
                    let hours = route.distanceKm / spec.cruiseKmh * Double(route.weeklyFrequency) * 2
                    let fatigue = 0.7 + pow(state.fleet[idx].wear / 100, 1.5)
                    state.fleet[idx].wear = min(100, state.fleet[idx].wear
                        + hours * 0.05 * fatigue
                        * (1.5 - state.fleet[idx].condition / 200) * f)
                }
            }
            // Satisfaction drifts toward its target — a day's share of the step.
            let cabinSkill = state.staff[.cabinCrew]?.skill ?? 1
            let cabinU = utilization[.cabinCrew] ?? 0
            let cabinAdequacy = cabinU <= 1 ? 1.0 : 1.0 / cabinU
            let service = (cabinSkill / 5.0) * cabinAdequacy
            let incidents = 1.0
            let ovensReady = activePlanes.allSatisfy { $0.hasGalleyOven ?? false }
            let cateringDelta: Double = switch catering {
            case .none: 0
            case .sandwichBox: ovensReady ? Balance.cateringSandwichDelta
                                          : Balance.cateringSandwichColdPenalty
            case .fruitPlatter: Balance.cateringFruitDelta
            case .asianBento: ovensReady ? Balance.cateringBentoDelta
                                         : Balance.cateringBentoColdPenalty
            }
            let target = min(100, max(0,
                (punctuality * 0.35 + avgComfort * 0.25 + service * 0.20
                 + econ.fairness * 0.15 + incidents * 0.05) * 100 + cateringDelta))
            state.routes[r].satisfaction += (target - route.satisfaction) * 0.15 * f
            state.routes[r].lastPunctuality = punctuality
        }

        // 4. WAGES + costs — a day's share; happiness/skill drift daily.
        let wageTrendMult = trendMultiplier(.wages)
        for role in StaffRole.allCases {
            guard var pool = state.staff[role] else { continue }
            let u = utilization[role] ?? 0
            let demand = crewDemandHours[role] ?? 0
            let capacity = Double(pool.headcount) * Balance.weeklyHoursPerStaff
            report.wageCost += Double(pool.headcount) * pool.weeklyWage * wageTrendMult * f
            let marketRate = role.marketWage * profile.laborCost
            let excessHours = max(0, demand - capacity)
            let overtimeHours = min(excessHours, capacity * Balance.overtimeCapFactor)
            let contractorHours = excessHours - overtimeHours
            if overtimeHours > 0 {
                let hourly = pool.weeklyWage / Balance.weeklyHoursPerStaff
                report.wageCost += overtimeHours * hourly * Balance.overtimeMultiplier * wageTrendMult * f
            }
            if contractorHours > 0 {
                let marketHourly = marketRate / Balance.weeklyHoursPerStaff
                report.contractorCost = (report.contractorCost ?? 0)
                    + contractorHours * marketHourly * Balance.contractorPremium * wageTrendMult * f
            }
            let staffLoad = capacity > 0 ? min(u, 1 + Balance.overtimeCapFactor) : 0
            let target = happinessTarget(role: role, weeklyWage: pool.weeklyWage, staffLoad: staffLoad)
            pool.happiness += (target - pool.happiness) * 0.08 * f
            for i in pool.members.indices { pool.members[i].skill = min(5, pool.members[i].skill + 0.005 * f) }
            pool.skill = min(5, pool.skill + 0.005 * f)
            pool.lastUtilization = staffLoad
            pool.lastContractorShare = demand > 0 ? contractorHours / demand : 0
            state.staff[role] = pool
        }

        // 5. Maintenance / lease / cabin upkeep / marketing / overhead — day's share.
        for plane in state.fleet where plane.status != .onOrder {
            let spec = Balance.specs[plane.type]!
            report.maintenanceCost += spec.baseMaintPerWeek
                * (1 + plane.wear / 200) * (1.6 - 0.6 * plane.condition / 100)
                * difficulty.costFactor * f
        }
        for plane in state.fleet where plane.acquisition == .leased {
            report.leaseCost += plane.weeklyLeaseCost * difficulty.costFactor * f
        }
        for plane in state.fleet where plane.status != .onOrder {
            report.cabinCost += plane.cabin.weeklyUpkeep(spec: Balance.specs[plane.type]!) * f
        }
        report.marketingCost += state.weeklyMarketingSpend * f
        report.overheadCost += Balance.hqOverhead(fleetCount: state.fleet.count) * difficulty.costFactor * f

        // 6. Loans — book a day's share of the weekly payment (principal
        // amortizes on the weekly close).
        for i in state.loans.indices {
            let interest = state.loans[i].remaining * state.loans[i].weeklyInterestRate
            let payment = min(state.loans[i].weeklyPayment, state.loans[i].remaining + interest)
            report.loanCost += payment * f
        }

        // Aircraft aging + condition decay — a day's share.
        for i in state.fleet.indices where state.fleet[i].status != .onOrder {
            state.fleet[i].ageYears += (1.0 / 52.0) * f
            state.fleet[i].condition = max(20, state.fleet[i].condition - 0.06 * f)
        }

        // 7. SETTLE — cash books only THIS day's profit; reputation drifts daily.
        weekReport = report
        state.cash += report.profit - profitBefore
        let paxWeightedSat = state.routes.isEmpty ? 60.0
            : state.routes.map(\.satisfaction).reduce(0, +) / Double(state.routes.count)
        let repTarget = 1 + (paxWeightedSat / 100) * 4
        state.reputation += (repTarget - state.reputation) * 0.06 * f

        // DAILY history — every chart tips forward each day (GDD §23). The
        // trend charts bucket these into weeks/months/quarters for display.
        appendHistory(\.netWorthHistory, netWorth)
        appendHistory(\.cashHistory, state.cash)
        appendHistory(\.reputationHistory, state.reputation)
        state.debtHistory = Array(((state.debtHistory ?? []) + [totalDebt]).suffix(historyCap))
        state.dailyProfit = Array(((state.dailyProfit ?? [])
            + [report.profit - profitBefore]).suffix(Balance.plChartDays))
        state.dailyRevenue = Array(((state.dailyRevenue ?? [])
            + [report.revenue - revenueBefore]).suffix(Balance.plChartDays))

        if close { closeWeek(report) }
        state.date.advanceDay()
    }

    /// The 7-day close: the discrete, seeded-random systems and bookkeeping
    /// — run once per week, drawing the RNG in a fixed order (deterministic).
    private func closeWeek(_ reportIn: WeeklyReport) {
        var report = reportIn
        // Deliveries + maintenance countdowns.
        for i in state.fleet.indices where state.fleet[i].status == .onOrder {
            state.fleet[i].deliveryWeeksRemaining -= 1
            if state.fleet[i].deliveryWeeksRemaining <= 0 {
                state.fleet[i].deliveryWeeksRemaining = 0
                state.fleet[i].status = .idle
                if let routeID = state.fleet[i].assignedRouteID {
                    if let r = state.routes.firstIndex(where: { $0.id == routeID }),
                       canOperate(aircraftID: state.fleet[i].id, routeID: routeID) {
                        state.routes[r].assignedAircraftIDs.append(state.fleet[i].id)
                        state.fleet[i].status = .assigned
                    } else {
                        state.fleet[i].assignedRouteID = nil
                    }
                }
            }
        }
        for i in state.fleet.indices where state.fleet[i].groundedWeeksRemaining > 0 {
            state.fleet[i].groundedWeeksRemaining -= 1
            if state.fleet[i].groundedWeeksRemaining == 0 {
                state.fleet[i].status = state.fleet[i].assignedRouteID == nil ? .idle : .assigned
            }
        }


        // Airworthiness crash sweep (RNG, at most one hull loss/week).
        for i in state.fleet.indices {
            let plane = state.fleet[i]
            guard plane.status != .onOrder, plane.groundedWeeksRemaining == 0,
                  let routeID = plane.assignedRouteID,
                  let route = state.routes.first(where: { $0.id == routeID }),
                  route.weeklyFrequency > 0,
                  plane.wear > Balance.wearDangerThreshold else { continue }
            let over = (plane.wear - Balance.wearDangerThreshold) / (100 - Balance.wearDangerThreshold)
            let risk = over * over * Balance.crashRiskAt100Wear
            if Double.random(in: 0...1, using: &state.seedRNG) < risk {
                crash(planeIndex: i, route: route)
                break
            }
        }

        // Attrition (RNG): unhappy pools shed people.
        for role in StaffRole.allCases {
            guard var pool = state.staff[role],
                  pool.happiness < Balance.attritionHappinessThreshold, pool.headcount > 0 else { continue }
            let severity = (Balance.attritionHappinessThreshold - pool.happiness) / Balance.attritionHappinessThreshold
            let expected = Double(pool.headcount) * Balance.attritionMaxRatePerWeek * severity
            var leavers = Int(expected)
            if Double.random(in: 0...1, using: &state.seedRNG) < expected - Double(leavers) { leavers += 1 }
            for _ in 0..<min(leavers, pool.members.count) {
                pool.members.remove(at: Int.random(in: 0..<pool.members.count, using: &state.seedRNG))
            }
            pool.headcount = max(0, pool.headcount - leavers)
            recomputeAggregates(&pool)
            state.staff[role] = pool
        }

        // Marketing awareness (weekly recurrence).
        state.brandAwareness = min(100, state.brandAwareness * (1 - Balance.awarenessDecay)
            + Balance.awarenessGain(spend: state.weeklyMarketingSpend))

        // Loan principal amortization (weekly).
        for i in state.loans.indices {
            let interest = state.loans[i].remaining * state.loans[i].weeklyInterestRate
            let payment = min(state.loans[i].weeklyPayment, state.loans[i].remaining + interest)
            state.loans[i].remaining = max(0, state.loans[i].remaining + interest - payment)
        }
        state.loans.removeAll { $0.remaining <= 0.01 }

        // Events, timed effects, trends, unlocks.
        drawEvent()
        for i in state.activeEffects.indices { state.activeEffects[i].weeksRemaining -= 1 }
        state.activeEffects.removeAll { $0.weeksRemaining <= 0 }
        tickIndustryTrends()
        checkFleetUnlocks()

        // Recruitment (RNG).
        for role in StaffRole.allCases {
            guard let weeksLeft = state.jobPostings[role] else { continue }
            let waiting = state.applicants.filter { $0.role == role }.count
            let count = min(1 + (Double.random(in: 0...1, using: &state.seedRNG) < 0.5 ? 1 : 0),
                            Balance.maxApplicantsPerRole - waiting)
            for _ in 0..<max(0, count) { state.applicants.append(generateApplicant(role: role)) }
            state.jobPostings[role] = weeksLeft <= 1 ? nil : weeksLeft - 1
        }
        for i in state.applicants.indices { state.applicants[i].weeksRemaining -= 1 }
        state.applicants.removeAll { $0.weeksRemaining <= 0 }

        // Used market refresh (RNG).
        state.weeksUntilMarketRefresh -= 1
        if state.weeksUntilMarketRefresh <= 0 {
            state.usedMarket = Self.generateUsedListings(rng: &state.seedRNG)
            let metalMult = aircraftPriceMultiplier
            if metalMult != 1.0 {
                for i in state.usedMarket.indices { state.usedMarket[i].price *= metalMult }
            }
            state.weeksUntilMarketRefresh = Int.random(
                in: Balance.usedMarketRefreshWeeksMin...Balance.usedMarketRefreshWeeksMax,
                using: &state.seedRNG)
        }

        // Fold this week's settlements into the Incidents line (GDD §23) so
        // quarter profit reflects them; the cash already left when they hit.
        if pendingIncident != 0 {
            report.incidentCost = (report.incidentCost ?? 0) + pendingIncident
            pendingIncident = 0
        }

        // Finalize the week's report (the statement stays weekly). The
        // trend histories are appended DAILY in advanceDay, not here.
        state.reports.append(report)
        if state.reports.count > 52 { state.reports.removeFirst() }
        weekReport = nil

        // Milestones (paid once, never blocking).
        for milestone in Balance.milestones
        where !state.completedMilestones.contains(milestone.id) && milestone.isComplete(state) {
            state.completedMilestones.insert(milestone.id)
            state.cash += milestone.reward
        }

        // Fail state (GDD §3.2): 8 insolvent weeks with nothing to sell.
        state.weeksInsolvent = state.cash < 0 ? state.weeksInsolvent + 1 : 0
        let hasSellableAssets = state.fleet.contains {
            $0.acquisition != .leased && $0.status != .onOrder
        }
        if state.weeksInsolvent >= 8 && !hasSellableAssets {
            state.isBankrupt = true
            speed = .paused
            // A grounded airline makes no more decisions: drop any event this
            // same close drew (drawEvent runs before the fail check) so no
            // card floats over the game-over screen.
            state.pendingEvent = nil
        }

        if state.date.week % 13 == 0 { closeQuarter() }
        save()
    }

    // ── Crew hours: ONE formula for the tick and the UI ─────────────────

    /// Crew demand hours by role from the CURRENT routes and assignments —
    /// the weekly tick runs on this, and the live workload projection
    /// reads it so the meter moves the moment a hire signs on.
    func liveCrewDemandHours() -> [StaffRole: Double] {
        var hours: [StaffRole: Double] = [:]
        for route in state.routes where route.weeklyFrequency > 0 {
            let activePlanes = state.fleet.filter {
                route.assignedAircraftIDs.contains($0.id) && $0.groundedWeeksRemaining == 0
            }
            for plane in activePlanes {
                let spec = Balance.specs[plane.type]!
                // A round trip = two legs of cruise plus turnaround duty.
                let blockHours = 2 * (route.distanceKm / spec.cruiseKmh + Balance.turnaroundHoursPerLeg)
                let trips = Double(route.weeklyFrequency)
                hours[.pilots, default: 0] += Double(spec.pilotsPerFlight) * blockHours * trips
                hours[.cabinCrew, default: 0] += Double(spec.cabinCrewPerFlight) * blockHours * trips
                hours[.ground, default: 0] += Balance.groundHoursPerDeparture * 2 * trips
            }
        }
        let deliveredFleet = state.fleet.filter { $0.status != .onOrder }.count
        hours[.hq] = Balance.hqBaseHours
            + Balance.hqHoursPerAircraft * Double(deliveredFleet)
            + Balance.hqHoursPerRoute * Double(state.routes.count)
        return hours
    }

    /// Live workload for the UI (immediacy rule): hires, assignments, and
    /// frequency changes move the meter NOW; money still settles weekly.
    /// Same cap as the settle's staffLoad, so the meter never disagrees
    /// with what next week will book.
    func projectedUtilization(role: StaffRole) -> Double {
        let demand = liveCrewDemandHours()[role] ?? 0
        let capacity = Double(state.staff[role]?.headcount ?? 0) * Balance.weeklyHoursPerStaff
        return capacity > 0 ? min(demand / capacity, 1 + Balance.overtimeCapFactor) : 0
    }

    /// Morale target from pay vs market minus overwork (GDD §4.4) — ONE
    /// formula for the weekly drift and the same-day wage reaction. The
    /// penalty tracks the staff's own load, not contractor volume.
    func happinessTarget(role: StaffRole, weeklyWage: Double, staffLoad: Double) -> Double {
        let marketRate = role.marketWage
            * Balance.countryProfiles[state.country]!.laborCost
        let payFactor = weeklyWage / max(marketRate, 1)   // >1 = generous
        let workloadPenalty = Balance.workloadHappinessPenalty
            * min(Balance.maxStrainPerPool, max(0, staffLoad - 1))
        return min(100, max(0, 50 + (payFactor - 1) * 120 - workloadPenalty))
    }

    // ── Route economics: ONE formula for the tick and the UI ────────────

    /// The demand/revenue/fuel math, decomposed. The weekly tick runs on
    /// this and the "tap any number" breakdowns read from it (pillar 4).
    func computeEconomics(route: Route, planes: [Aircraft], profile: CountryProfile,
                          fuelEventMult: Double, demandEventMult: Double) -> RouteEconomics {
        guard let origin = city(route.originID), let dest = city(route.destinationID) else {
            return RouteEconomics(gravity: 0, growth: 1, season: 1, brand: 1, eventDemand: 1,
                                  referenceFare: 1, priceRatio: 1, priceResponse: 1, demand: 0,
                                  seatsOffered: 0, pax: 0, loadFactor: 0, revenue: 0, fuel: 0,
                                  fairness: 0, breakevenLoadFactor: 0)
        }

        // Gravity demand (GDD §4.3), weekly, both directions combined.
        let gravity = Balance.demandK
            * pow(origin.population * dest.population, 0.55)
            / pow(route.distanceKm, 0.35)
        let growth = pow(1 + profile.demandGrowthPerYear, Double(state.date.year - 1))
        let season = 1.0 + 0.20 * sin(Double(state.date.week) / 52.0 * 2 * .pi)
        // Reputation sets the brand range; awareness (M5 marketing) scales it.
        let brand = (0.5 + (state.reputation / 5.0) * 1.1)
            * Balance.awarenessMultiplier(state.brandAwareness)

        let referenceFare = route.distanceKm * Balance.referenceFarePerKm * profile.fareLevel
        let priceRatio = route.fare / max(referenceFare, 1)
        let priceResponse = pow(priceRatio, -profile.priceElasticity)
        let demand = gravity * growth * season * brand * min(priceResponse, 2.5)
            * (state.difficulty ?? .standard).demandFactor
            * profile.demandLevel
            * demandEventMult

        var seatsOffered = 0
        var fuel = 0.0
        for plane in planes {
            let spec = Balance.specs[plane.type]!
            seatsOffered += plane.seats(spec: spec) * route.weeklyFrequency * 2
            // The AIRFRAME burns fuel (max seats) regardless of cabin config;
            // poor condition adds a burn penalty (GDD §4.1).
            fuel += Double(spec.maxSeats) * route.distanceKm
                 * spec.fuelBurnPerSeatKm * Double(route.weeklyFrequency) * 2
                 * Balance.fuelPricePerUnit * profile.fuelCost
                 * Balance.fuelConditionMultiplier(condition: plane.condition)
                 * fuelEventMult
        }

        // Competition (GDD §21): comfort, price-for-market, and the
        // route's satisfaction decide your SHARE of the pair — unless you
        // are the only carrier. Rivals also grow the total pie, so a
        // strong product barely feels them while a weak one collapses.
        let competitors = Balance.competitorCount(origin, dest)
        let affluence = (origin.businessIndex + dest.businessIndex) / 2
        var comfort = planes.isEmpty ? 0.4
            : planes.map(\.comfortScore).reduce(0, +) / Double(planes.count)
        comfort = min(1, comfort)
        let priceValue = max(0, min(1, 1.5 - priceRatio))   // cheap = appealing
        // Affluent pairs weigh comfort over price; budget pairs the reverse.
        let wComfort = 0.25 + 0.30 * affluence
        let wPrice = 0.45 - 0.30 * affluence
        let appeal = max(0.05, wComfort * comfort + wPrice * priceValue
            + 0.30 * (route.satisfaction / 100))
        let captureShare = competitors == 0 ? 1.0
            : appeal / (appeal + Double(competitors) * Balance.rivalAppeal * 0.8)
        let marketPie = demand * (1 + Balance.marketGrowthPerRival * Double(competitors))

        let pax = min(marketPie * captureShare, Double(seatsOffered))
        let loadFactor = seatsOffered > 0 ? pax / Double(seatsOffered) : 0
        let revenue = pax * route.fare

        // The fare↔satisfaction link: pricing below the market reference
        // actively pleases passengers; gouging costs goodwill.
        let fairness = max(0, min(1, 1.6 - priceRatio * 0.8))

        let maxRevenue = route.fare * Double(seatsOffered)
        let breakeven = maxRevenue > 0 ? min(1.5, fuel / maxRevenue) : 0

        return RouteEconomics(gravity: gravity, growth: growth, season: season,
                              brand: brand, eventDemand: demandEventMult,
                              referenceFare: referenceFare, priceRatio: priceRatio,
                              priceResponse: min(priceResponse, 2.5), demand: demand,
                              seatsOffered: seatsOffered, pax: pax, loadFactor: loadFactor,
                              revenue: revenue, fuel: fuel, fairness: fairness,
                              breakevenLoadFactor: breakeven,
                              competitors: competitors, affluence: affluence,
                              captureShare: captureShare)
    }

    /// This week's economics for a route, for the UI's unit-economics and
    /// formula breakdowns — computed by the very same function as the tick.
    func routeEconomics(routeID: UUID) -> RouteEconomics? {
        guard let route = state.routes.first(where: { $0.id == routeID }) else { return nil }
        let planes = state.fleet.filter {
            route.assignedAircraftIDs.contains($0.id) && $0.groundedWeeksRemaining == 0
        }
        let fuelMult = state.activeEffects
            .filter { $0.kind == .fuelPrice }.reduce(1.0) { $0 * $1.multiplier }
            * trendMultiplier(.fuel)
        let demandMult = state.activeEffects
            .filter { $0.kind == .demand }.reduce(1.0) { $0 * $1.multiplier }
            * trendMultiplier(.demand)
        return computeEconomics(route: route, planes: planes,
                                profile: Balance.countryProfiles[state.country]!,
                                fuelEventMult: fuelMult, demandEventMult: demandMult)
    }

    /// Cap for the daily trend-history buffers: ~5 in-game years of days
    /// (GDD §23). Enough for the yearly (quarter-bucketed) chart window.
    var historyCap: Int { 52 * 7 * 5 }

    /// Appends to a capped daily history buffer.
    private func appendHistory(_ keyPath: WritableKeyPath<GameState, [Double]>, _ value: Double) {
        state[keyPath: keyPath].append(value)
        if state[keyPath: keyPath].count > historyCap { state[keyPath: keyPath].removeFirst() }
    }

    /// Appends to a route's daily load-factor sparkline buffer (last ~13 wk).
    private func appendLoadFactor(_ value: Double, routeIndex: Int) {
        state.routes[routeIndex].loadFactorHistory.append(value)
        if state.routes[routeIndex].loadFactorHistory.count > 91 {
            state.routes[routeIndex].loadFactorHistory.removeFirst()
        }
    }

    private func closeQuarter() {
        let quarterProfit = state.reports.suffix(13).map(\.profit).reduce(0, +)
        applyQuarterResult(quarterProfit: quarterProfit)
    }

    /// Quarter bookkeeping + the trust-fund arc (GDD §3.1/§6). Internal so
    /// tests can drive quarters deterministically.
    func applyQuarterResult(quarterProfit: Double) {
        state.consecutiveProfitableQuarters =
            quarterProfit > 0 ? state.consecutiveProfitableQuarters + 1 : 0

        guard state.trustFundResolution == .pending else { return }

        let quartersLeft = max(0, (state.trustFundDeadline.totalWeeks - state.date.totalWeeks) / 13)
        let streak = state.consecutiveProfitableQuarters

        if streak >= 4 {
            // ── Success: the fund converts to a gift ─────────────────────
            state.trustFundResolution = .succeeded
            state.trustFundActive = false
            appendLetter(tone: .triumphant, quarterProfit: quarterProfit, quartersLeft: 0)
            state.pendingEvent = GameEvent(
                id: UUID(), cardID: "trustFundSuccess", category: .story,
                isNegative: false,
                title: "Aunt's Approval",
                body: "Four consecutive profitable quarters. The trust fund converts to a gift, with a bonus from a very proud aunt. Her letter is on the Money tab.",
                options: [EventOption(label: "Accept the gift (+\(Balance.trustFundSuccessGift.money))",
                                      effects: [.cash(Balance.trustFundSuccessGift),
                                                .reputation(Balance.trustFundSuccessReputationBonus)])],
                firedOn: state.date)
        } else if state.date >= state.trustFundDeadline {
            // ── Failure: the remaining fund is withdrawn — hard mode ─────
            state.trustFundResolution = .failed
            state.trustFundActive = false
            let withdrawal = min(max(state.cash, 0), Balance.auntSeedFund)
            appendLetter(tone: .heartbroken, quarterProfit: quarterProfit, quartersLeft: 0)
            state.pendingEvent = GameEvent(
                id: UUID(), cardID: "trustFundWithdrawn", category: .story,
                isNegative: true,
                title: "The Fund Is Withdrawn",
                body: "The deadline passed without four consecutive profitable quarters. The accountants have recalled what remained of the trust fund. What you build from here is yours alone.",
                options: [EventOption(label: "Carry on (−\(withdrawal.money))",
                                      effects: [.cash(-withdrawal)])],
                firedOn: state.date)
            state.lastNegativeEventTotalWeek = state.date.totalWeeks
        } else {
            // ── An ordinary quarter: a letter keyed to performance ───────
            let tone: QuarterlyLetter.Tone =
                quarterProfit > 0
                    ? (streak >= 2 ? .proud : .encouraging)
                    : (state.cash > 500_000 ? .worried : .stern)
            appendLetter(tone: tone, quarterProfit: quarterProfit, quartersLeft: quartersLeft)
        }
    }

    private func appendLetter(tone: QuarterlyLetter.Tone, quarterProfit: Double,
                              quartersLeft: Int) {
        state.letters.append(QuarterlyLetter(
            id: UUID(), date: state.date, tone: tone, quarterProfit: quarterProfit,
            body: Balance.auntLetter(tone: tone, quarterProfit: quarterProfit,
                                     streak: state.consecutiveProfitableQuarters,
                                     quartersLeft: quartersLeft,
                                     country: state.country)))
        if state.letters.count > Balance.lettersKept { state.letters.removeFirst() }
    }

    /// Bankruptcy is the hard fail (GDD §3.2): start over, same airline name.
    func restart() {
        let name = state.airlineName
        let country = state.country
        state = GameEngine.newGame(airlineName: name, country: country).state
        speed = .paused
        save()
    }

    // ── The event deck (GDD §4.7) ────────────────────────────────────────

    /// Cards that may fire THIS week: past their intro week, situationally
    /// eligible, and respecting the year-one guard rail (no negative event
    /// the week after a negative event).
    func eligibleCards() -> [EventCard] {
        let now = state.date.totalWeeks
        let negativeBlocked = state.date.year == 1
            && state.lastNegativeEventTotalWeek > 0
            && now - state.lastNegativeEventTotalWeek <= 1
        return Balance.eventDeck.filter { card in
            now >= card.minTotalWeek
                && card.isEligible(state)
                && !(negativeBlocked && card.isNegative)
        }
    }

    /// Base weight shifted by game state — events read as consequences:
    /// worn fleets attract technical cards, miserable crews labor cards,
    /// understaffed maintenance raises fault odds.
    func eventWeight(for card: EventCard) -> Double {
        var weight = card.baseWeight
        switch card.category {
        case .technical:
            let delivered = state.fleet.filter { $0.status != .onOrder }
            let avgWear = delivered.isEmpty ? 0
                : delivered.map(\.wear).reduce(0, +) / Double(delivered.count)
            weight *= 0.5 + avgWear / 40.0
            if (state.staff[.ground]?.lastUtilization ?? 0) > 1.2 { weight *= 1.5 }
        case .labor:
            let lowMorale = StaffRole.allCases.filter {
                (state.staff[$0]?.headcount ?? 0) > 0
                && (state.staff[$0]?.happiness ?? 100) < Balance.attritionHappinessThreshold
            }.count
            weight *= 1.0 + Double(strikeRiskPools.count) * 2.0 + Double(lowMorale) * 0.5
        case .market, .weather, .opportunity, .regulatory, .pr:
            break
        case .story:
            weight = 0   // story beats are fired by the arc, never drawn
        }
        return weight
    }

    private func drawEvent() {
        guard state.date.totalWeeks > Balance.eventGraceWeeks,
              state.pendingEvent == nil else { return }
        // Pity ramp: every event-free week raises the odds, so decision
        // cards arrive on a rhythm instead of drought-or-flood.
        let sinceLast = state.date.totalWeeks
            - (state.lastEventTotalWeek ?? Balance.eventGraceWeeks)
        let chance = min(Balance.eventChanceCap,
                         Balance.eventChancePerWeek
                         + Balance.eventPityRampPerWeek * Double(max(0, sinceLast - 1)))
        guard Double.random(in: 0...1, using: &state.seedRNG) < chance else { return }

        let candidates = eligibleCards()
        let weights = candidates.map { eventWeight(for: $0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return }

        var roll = Double.random(in: 0..<total, using: &state.seedRNG)
        for (card, weight) in zip(candidates, weights) {
            roll -= weight
            if roll < 0 { present(card); return }
        }
    }

    /// Hull loss (GDD §17): the plane is gone, souls are lost — named crew
    /// among them — the courts settle, and the market recoils. Everything
    /// applies immediately; the event card is the reckoning, not a choice.
    private func crash(planeIndex: Int, route: Route) {
        let plane = state.fleet[planeIndex]
        let spec = Balance.specs[plane.type]!
        let pax = max(1, Int((Double(plane.seats(spec: spec)) * route.lastLoadFactor).rounded()))
        let souls = pax + spec.pilotsPerFlight + spec.cabinCrewPerFlight

        unassignEverywhere(aircraftID: plane.id)
        state.fleet.remove(at: planeIndex)

        // The crew aboard were real roster members.
        var lostNames: [String] = []
        func removeCrew(role: StaffRole, count: Int) {
            guard var pool = state.staff[role], count > 0,
                  !pool.members.isEmpty else { return }
            for _ in 0..<min(count, pool.members.count) {
                let idx = Int.random(in: 0..<pool.members.count, using: &state.seedRNG)
                lostNames.append(pool.members[idx].name)
                pool.members.remove(at: idx)
            }
            pool.headcount = pool.members.count
            recomputeAggregates(&pool)
            state.staff[role] = pool
        }
        removeCrew(role: .pilots, count: spec.pilotsPerFlight)
        removeCrew(role: .cabinCrew, count: spec.cabinCrewPerFlight)

        // Reputation craters, every route feels it, the courts settle.
        state.reputation = max(0.5, state.reputation - 1.5)
        for i in state.routes.indices {
            state.routes[i].satisfaction = max(0, state.routes[i].satisfaction - 20)
        }
        let settlement = Double(souls) * Balance.settlementPerLife
        state.cash -= settlement
        pendingIncident += settlement   // dents this week's P&L / quarter profit

        // The market recoils: a safety scare lands as an industry trend.
        var trends = industryTrends
        trends.removeAll { $0.key == "safety_scare" }
        trends.append(IndustryTrend(
            id: UUID(), key: "safety_scare", name: "Safety scare",
            detail: "Your crash leads every bulletin.",
            kind: .demand, horizon: .short, multiplier: 0.80, weeksRemaining: 8))
        state.industryTrends = trends

        let crewLine = lostNames.isEmpty ? ""
            : " Among them, your own: \(lostNames.joined(separator: ", "))."
        state.pendingEvent = GameEvent(
            id: UUID(), cardID: "hullLoss", category: .technical, isNegative: true,
            title: "\(plane.nickname) is lost",
            body: "\(plane.nickname) (\(spec.displayName)) went down on \(route.originID) ✈︎ \(route.destinationID). \(souls) lives were lost.\(crewLine) The courts award \(settlement.money) to the families. The investigation is unsparing: at \(Int(plane.wear))% wear, this airframe should never have flown.",
            options: [EventOption(label: "Own it. Never again.", effects: [])],
            firedOn: state.date)
        state.lastEventTotalWeek = state.date.totalWeeks
        state.lastNegativeEventTotalWeek = state.date.totalWeeks
        logEvent(title: "\(plane.nickname) is lost", isNegative: true)
    }

    /// Appends to the capped event history (charts + Major events list).
    private func logEvent(title: String, isNegative: Bool) {
        var log = state.eventLog ?? []
        log.append(EventLogEntry(id: UUID(), totalWeek: state.date.totalWeeks,
                                 title: title, isNegative: isNegative))
        if log.count > 120 { log.removeFirst(log.count - 120) }
        state.eventLog = log
    }

    /// Fires a card (internal so tests can force specific cards).
    func present(_ card: EventCard) {
        // Lawsuit incidents (GDD §19) name a real roster member; recalls
        // (GDD §20) name a real model in your fleet. The card reads the
        // facts, and the resolution weighs exactly those.
        let incident = incidentContext(for: card)
        let recall = recallContext(for: card)
        state.pendingEvent = GameEvent(
            id: UUID(), cardID: card.id, category: card.category,
            isNegative: card.isNegative, title: card.title,
            body: incident?.body ?? recall?.body ?? card.body,
            options: card.options, firedOn: state.date,
            subjectID: incident?.subjectID,
            subjectAircraftType: recall?.type)
        state.lastEventTotalWeek = state.date.totalWeeks
        logEvent(title: card.title, isNegative: card.isNegative)
        if card.isNegative {
            state.lastNegativeEventTotalWeek = state.date.totalWeeks
        }
    }

    /// Picks the recalled model: the delivered type you operate MOST of —
    /// a recall should sting, that's the drama.
    private func recallContext(for card: EventCard) -> (body: String, type: AircraftType)? {
        guard card.id == "fleetRecall" else { return nil }
        let delivered = state.fleet.filter { $0.status != .onOrder }
        guard !delivered.isEmpty else { return nil }
        var counts: [AircraftType: Int] = [:]
        for plane in delivered { counts[plane.type, default: 0] += 1 }
        let maxCount = counts.values.max()!
        // Deterministic tie-break through the seeded RNG.
        let top = counts.filter { $0.value == maxCount }.keys
            .sorted { $0.rawValue < $1.rawValue }
        let type = top[Int.random(in: 0..<top.count, using: &state.seedRNG)]
        return (recallBody(type: type), type)
    }

    /// Picks the accused for a lawsuit card and writes their record into
    /// the body — the same facts the court will weigh.
    private func incidentContext(for card: EventCard) -> (body: String, subjectID: UUID)? {
        let role: StaffRole? = switch card.id {
        case "teaSpill": .cabinCrew
        case "hardLanding": .pilots
        default: nil
        }
        guard let role, let pool = state.staff[role], !pool.members.isEmpty else { return nil }
        let member = pool.members[Int.random(in: 0..<pool.members.count, using: &state.seedRNG)]
        return (lawsuitBody(cardID: card.id, member: member), member.id)
    }

    /// The lawsuit body from stored facts only (no RNG) — reused when a
    /// persisted pending card refreshes its copy on load.
    private func lawsuitBody(cardID: String, member: StaffMember) -> String {
        let tenure = max(0, state.date.totalWeeks - member.hiredOn.totalWeeks)
        let record = String(format: "%.1f★ · %d wk with you", member.skill, tenure)
        let counsel = "Counsel: settling stays out of the news. Court is public, and the verdict rides on their record."
        return cardID == "teaSpill"
            ? "\(member.name) (\(record)) spilled scalding tea on a passenger. The burns needed treatment. Their lawyers want \(180_000.0.money).\n\n\(counsel)"
            : "\(member.name) (\(record)) landed hard. An elderly passenger's spine was injured. The family's lawyers want \(300_000.0.money).\n\n\(counsel)"
    }

    /// The recall body from a stored type (no RNG) — same refresh use.
    private func recallBody(type: AircraftType) -> String {
        let spec = Balance.specs[type]!
        let n = state.fleet.filter { $0.type == type && $0.status != .onOrder }.count
        return "\(spec.seller) has recalled the \(spec.displayName) over a fuel-line defect. You operate \(n).\n\nCounsel: comply and each airframe is grounded 2 weeks, wear refreshed. Defer and you pay fines while the defect keeps flying."
    }

    /// A pending card persisted by an older build carries stale copy: its
    /// labels and body were baked at draw time. Refresh them from the
    /// current deck (effects included) and rebuild personalized bodies
    /// from the stored subject — deterministic, no RNG consumed.
    private func refreshPendingEventCopy() {
        guard var event = state.pendingEvent,
              let card = Balance.eventDeck.first(where: { $0.id == event.cardID })
        else { return }
        event.title = card.title
        event.options = card.options
        if let id = event.subjectID, let member = staffMember(id: id) {
            event.body = lawsuitBody(cardID: event.cardID, member: member)
        } else if let type = event.subjectAircraftType {
            event.body = recallBody(type: type)
        } else if event.subjectID == nil {
            event.body = card.body
        }
        state.pendingEvent = event
    }

    /// Applies one effect. Random-aircraft picks use the seeded RNG, so
    /// replays stay identical.
    private func apply(_ effect: EventEffect) {
        switch effect {
        case .cash(let delta):
            state.cash += delta
        case .happiness(let role, let delta):
            for r in StaffRole.allCases where role == nil || role == r {
                if var pool = state.staff[r] {
                    pool.happiness = max(0, min(100, pool.happiness + delta))
                    state.staff[r] = pool
                }
            }
        case .satisfaction(let delta):
            for i in state.routes.indices {
                state.routes[i].satisfaction =
                    max(0, min(100, state.routes[i].satisfaction + delta))
            }
        case .reputation(let delta):
            state.reputation = max(1, min(5, state.reputation + delta))
        case .raiseWage(let role, let factor):
            for r in StaffRole.allCases where role == nil || role == r {
                guard var pool = state.staff[r] else { continue }
                pool.weeklyWage *= factor
                for i in pool.members.indices { pool.members[i].weeklyWage *= factor }
                state.staff[r] = pool
            }
        case .fuelPrice(let multiplier, let weeks):
            state.activeEffects.append(TimedEffect(
                id: UUID(), kind: .fuelPrice, multiplier: multiplier,
                weeksRemaining: weeks,
                label: "Fuel \(multiplier > 1 ? "+" : "−")\(Int(abs(multiplier - 1) * 100))%"))
        case .demand(let multiplier, let weeks):
            state.activeEffects.append(TimedEffect(
                id: UUID(), kind: .demand, multiplier: multiplier,
                weeksRemaining: weeks,
                label: "Demand \(multiplier > 1 ? "+" : "−")\(Int(abs(multiplier - 1) * 100))%"))
        case .groundRandomAircraft(let weeks):
            let candidates = state.fleet.indices.filter {
                state.fleet[$0].status != .onOrder
                && state.fleet[$0].groundedWeeksRemaining == 0
            }
            guard !candidates.isEmpty else { return }
            let pick = candidates[Int.random(in: 0..<candidates.count, using: &state.seedRNG)]
            state.fleet[pick].status = .inMaintenance
            state.fleet[pick].groundedWeeksRemaining = weeks
        case .wearRandomAircraft(let amount):
            let candidates = state.fleet.indices.filter { state.fleet[$0].status != .onOrder }
            guard !candidates.isEmpty else { return }
            let pick = candidates[Int.random(in: 0..<candidates.count, using: &state.seedRNG)]
            state.fleet[pick].wear = min(100, state.fleet[pick].wear + amount)
        case .courtVerdict(let baseFee):
            resolveCourtCase(baseFee: baseFee)
        case .recallGround(let weeks, let costPerPlane):
            guard let type = eventSubjectAircraftType else { return }
            var grounded = 0
            for i in state.fleet.indices
            where state.fleet[i].type == type && state.fleet[i].status != .onOrder {
                state.fleet[i].status = .inMaintenance
                state.fleet[i].groundedWeeksRemaining =
                    max(state.fleet[i].groundedWeeksRemaining, weeks)
                // The retrofit is a shop visit — wear freshens while it's in.
                state.fleet[i].wear = max(0, state.fleet[i].wear - 15)
                grounded += 1
            }
            state.cash -= Double(grounded) * costPerPlane
            logEvent(title: "Recall: \(grounded) aircraft sent in", isNegative: true)
        case .recallDefer(let finePerPlane, let wearPerPlane):
            guard let type = eventSubjectAircraftType else { return }
            var deferred = 0
            for i in state.fleet.indices
            where state.fleet[i].type == type && state.fleet[i].status != .onOrder {
                state.fleet[i].wear = min(100, state.fleet[i].wear + wearPerPlane)
                deferred += 1
            }
            state.cash -= Double(deferred) * finePerPlane
            state.reputation = max(0.5, state.reputation - 0.1)
            logEvent(title: "Recall deferred: defect still flying", isNegative: true)
        }
    }

    /// The public trial (GDD §19). Credibility = the accused's skill stars
    /// plus tenure with the airline; the verdict card lands immediately.
    private func resolveCourtCase(baseFee: Double) {
        var skill = 2.5
        var tenureYears = 0.0
        var name = "your crew member"
        if let id = eventSubjectID {
            for role in StaffRole.allCases {
                if let member = state.staff[role]?.members.first(where: { $0.id == id }) {
                    skill = member.skill
                    tenureYears = Double(max(0, state.date.totalWeeks
                        - member.hiredOn.totalWeeks)) / 52.0
                    name = member.name
                    break
                }
            }
        }
        // 20% floor + 12%/star + 15%/tenure-year (2y cap) → 44% for a green
        // 2★ hire, ~90% for a 5★ veteran. The roster IS the defense.
        let winChance = min(0.90, 0.20 + 0.12 * skill + 0.15 * min(2, tenureYears))
        if Double.random(in: 0...1, using: &state.seedRNG) < winChance {
            let legal = baseFee * 0.15
            state.cash -= legal
            state.reputation = min(5, state.reputation + 0.15)
            logEvent(title: "Cleared in court", isNegative: false)
            state.pendingEvent = GameEvent(
                id: UUID(), cardID: "courtWon", category: .pr, isNegative: false,
                title: "Cleared in Court",
                body: "The claim fell apart in court. \(name)'s record held, and the judge dismissed the case. Legal costs ran \(legal.money). The papers ran your side of the story.",
                options: [EventOption(label: "Back to work", effects: [])],
                firedOn: state.date)
        } else {
            let award = baseFee * 1.5
            state.cash -= award
            state.reputation = max(0.5, state.reputation - 0.8)
            state.lastNegativeEventTotalWeek = state.date.totalWeeks
            logEvent(title: "Found liable in court", isNegative: true)
            state.pendingEvent = GameEvent(
                id: UUID(), cardID: "courtLost", category: .pr, isNegative: true,
                title: "Humiliated in Court",
                body: "The verdict: liable, with \(award.money) awarded, and the press filled the gallery. \(name)'s record did not survive the stand. The brand takes the bruise.",
                options: [EventOption(label: "Take the hit", effects: [])],
                firedOn: state.date)
        }
    }

    // ── Player actions (the ONLY external mutation points) ──────────────

    // NOTE (staff dictionary mutations): always read-modify-write via a
    // local copy. An optional-chained write whose RHS reads the same
    // dictionary is a Swift exclusivity violation through @Observable's
    // _modify — it aborts at runtime. apply(_:) follows this pattern.
    /// Incident cards whose settlements dent the P&L (GDD §23): lawsuits and
    /// recalls. Their cash outflow this resolution becomes an Incidents cost.
    private static let incidentCards: Set<String> = ["teaSpill", "hardLanding", "fleetRecall"]

    func resolveEvent(option: EventOption) {
        guard let event = state.pendingEvent else { return }
        // Clear FIRST: a courtVerdict effect may present the verdict card,
        // which must survive this resolution. The subject rides alongside.
        eventSubjectID = event.subjectID
        eventSubjectAircraftType = event.subjectAircraftType
        state.pendingEvent = nil
        // Cash spent settling an incident is booked as an Incidents cost so
        // the quarter reflects it (the cash itself still leaves immediately).
        let cashBefore = state.cash
        for effect in option.effects {
            apply(effect)
        }
        if Self.incidentCards.contains(event.cardID) {
            pendingIncident += max(0, cashBefore - state.cash)
        }
        eventSubjectID = nil
        eventSubjectAircraftType = nil
        save()
    }

    /// The roster member / aircraft model the event being resolved is
    /// about (GDD §19, §20).
    private var eventSubjectID: UUID?
    private var eventSubjectAircraftType: AircraftType?

    // ── Industry trends (GDD §14) ────────────────────────────────────────
    // One LONG economic regime is always in force; up to two SHORT shocks
    // come and go. All draws use the seeded RNG — deterministic per save.

    var industryTrends: [IndustryTrend] { state.industryTrends ?? [] }

    /// Product of all active trends on one lever.
    func trendMultiplier(_ kind: IndustryTrend.Kind) -> Double {
        industryTrends.filter { $0.kind == kind }
            .reduce(1.0) { $0 * $1.multiplier }
    }

    /// Moves new-order prices, lease signings, and used listings together.
    var aircraftPriceMultiplier: Double { trendMultiplier(.aircraftPrices) }

    private func spawnTrend(from deck: [Balance.TrendTemplate],
                            excluding activeKeys: Set<String>) -> IndustryTrend? {
        let candidates = deck.filter { !activeKeys.contains($0.key) }
        guard !candidates.isEmpty else { return nil }
        let pick = candidates[Int.random(in: 0..<candidates.count, using: &state.seedRNG)]
        return IndustryTrend(
            id: UUID(), key: pick.key, name: pick.name, detail: pick.detail,
            kind: pick.kind, horizon: pick.horizon,
            multiplier: Double.random(in: pick.multiplier, using: &state.seedRNG),
            weeksRemaining: Int.random(in: pick.weeks, using: &state.seedRNG))
    }

    private func tickIndustryTrends() {
        var trends = industryTrends
        for i in trends.indices { trends[i].weeksRemaining -= 1 }
        trends.removeAll { $0.weeksRemaining <= 0 }

        let activeKeys = Set(trends.map(\.key))
        // The economy always has a regime.
        if !trends.contains(where: { $0.horizon == .long }),
           let regime = spawnTrend(from: Balance.longTrendDeck, excluding: activeKeys) {
            trends.append(regime)
        }
        // Short shocks: capped at two, spawn-checked weekly.
        if trends.filter({ $0.horizon == .short }).count < 2,
           Double.random(in: 0...1, using: &state.seedRNG) < Balance.trendChancePerWeek,
           let shock = spawnTrend(from: Balance.shortTrendDeck,
                                  excluding: Set(trends.map(\.key))) {
            trends.append(shock)
        }
        state.industryTrends = trends
    }

    // ── Fleet acquisition (GDD §4.1): new order / used / lease ──────────

    /// Loyalty: factory-new orders from the same manufacturer earn 3% off
    /// each subsequent order, capped at 12% (GDD §4.1).
    func loyaltyDiscount(seller: String) -> Double {
        min(Balance.loyaltyDiscountCap,
            Double(state.sellerOrders[seller] ?? 0) * Balance.loyaltyDiscountPerOrder)
    }

    /// What a factory-new order actually costs right now: loyalty plus the
    /// aircraft-price trend in force (cheap credit, order boom…).
    func discountedPrice(for type: AircraftType) -> Double {
        let spec = Balance.specs[type]!
        return spec.purchasePrice * (1 - loyaltyDiscount(seller: spec.seller))
            * aircraftPriceMultiplier
    }

    /// Buying new is an ORDER: cash up front, plane arrives after the
    /// archetype's delivery wait (status .onOrder until then).
    @discardableResult
    /// Ordered from a route's desk (forRoute), the plane remembers its
    /// posting and joins that route the week it is delivered.
    func orderNewAircraft(type: AircraftType, nickname: String,
                          forRoute routeID: UUID? = nil) -> Bool {
        guard isUnlocked(type) else { return false }
        let spec = Balance.specs[type]!
        let price = discountedPrice(for: type)
        guard state.cash >= price else { return false }
        state.cash -= price
        state.sellerOrders[spec.seller, default: 0] += 1
        state.fleet.append(Aircraft(id: UUID(), type: type, nickname: nickname,
            status: .onOrder, acquisition: .ownedNew, weeklyLeaseCost: 0,
            deliveryWeeksRemaining: Balance.deliveryWeeks[type]!,
            cabin: .standard(abreast: spec.seatsAbreast), wear: 0, condition: 100,
            ageYears: 0, assignedRouteID: routeID, groundedWeeksRemaining: 0))
        save()
        return true
    }

    // ── Catering (GDD §18) ───────────────────────────────────────────────

    /// Set a route's in-flight service. Immediate (immediacy rule): the
    /// satisfaction consequences start with the next settle.
    func setCatering(routeID: UUID, level: CateringLevel) {
        guard let i = state.routes.firstIndex(where: { $0.id == routeID }) else { return }
        state.routes[i].catering = level
        save()
    }

    /// Fit a galley oven — the hardware hot meals need. Instant.
    @discardableResult
    func installGalleyOven(aircraftID: UUID) -> Bool {
        guard let i = state.fleet.firstIndex(where: { $0.id == aircraftID }),
              state.fleet[i].status != .onOrder,
              !(state.fleet[i].hasGalleyOven ?? false),
              state.cash >= Balance.galleyOvenCost else { return false }
        state.cash -= Balance.galleyOvenCost
        state.fleet[i].hasGalleyOven = true
        save()
        return true
    }

    /// Re-architect an aircraft's interior (GDD §4.2 as amended): costs the
    /// refit price and grounds the plane while the work is done.
    @discardableResult
    func refitCabin(aircraftID: UUID, layout: CabinLayout) -> Bool {
        guard let i = state.fleet.firstIndex(where: { $0.id == aircraftID }),
              state.fleet[i].status != .onOrder,
              state.fleet[i].groundedWeeksRemaining == 0,
              layout != state.fleet[i].cabin else { return false }
        let cost = layout.refitCost(spec: Balance.specs[state.fleet[i].type]!)
        guard state.cash >= cost else { return false }
        state.cash -= cost
        state.fleet[i].cabin = layout
        state.fleet[i].status = .inMaintenance
        state.fleet[i].groundedWeeksRemaining = Balance.cabinRefitWeeks
        // A heavier cabin can shrink effective range below the assigned
        // route's distance — pull the plane off rather than fly an
        // impossible schedule.
        if let routeID = state.fleet[i].assignedRouteID,
           !canOperate(aircraftID: aircraftID, routeID: routeID) {
            unassignEverywhere(aircraftID: aircraftID)
            state.fleet[i].assignedRouteID = nil
        }
        save()
        return true
    }

    /// Used planes deliver instantly at 30–60% of new, with visible
    /// condition/age from the listing.
    @discardableResult
    func buyUsedAircraft(listingID: UUID, nickname: String,
                         forRoute routeID: UUID? = nil) -> Bool {
        guard let idx = state.usedMarket.firstIndex(where: { $0.id == listingID }) else { return false }
        let listing = state.usedMarket[idx]
        guard isUnlocked(listing.type), state.cash >= listing.price else { return false }
        state.cash -= listing.price
        state.usedMarket.remove(at: idx)
        let planeID = UUID()
        state.fleet.append(Aircraft(id: planeID, type: listing.type, nickname: nickname,
            status: .idle, acquisition: .ownedUsed, weeklyLeaseCost: 0,
            deliveryWeeksRemaining: 0,
            cabin: .standard(abreast: Balance.specs[listing.type]!.seatsAbreast),
            wear: 0, condition: listing.condition,
            ageYears: listing.ageYears, assignedRouteID: nil, groundedWeeksRemaining: 0))
        save()
        // Bought from a route's desk: straight onto that route.
        if let routeID { assign(aircraftID: planeID, to: routeID) }
        return true
    }

    /// Leasing: any archetype instantly, no capital outlay, a weekly
    /// payment that never ends. The cautious player's first plane.
    @discardableResult
    func leaseAircraft(type: AircraftType, nickname: String,
                       forRoute routeID: UUID? = nil) -> Bool {
        guard isUnlocked(type) else { return false }
        let spec = Balance.specs[type]!
        let planeID = UUID()
        state.fleet.append(Aircraft(id: planeID, type: type, nickname: nickname,
            status: .idle, acquisition: .leased,
            // The trend prices the signing; the rate then stays locked.
            weeklyLeaseCost: spec.purchasePrice * Balance.leaseRatePerWeek
                * aircraftPriceMultiplier,
            deliveryWeeksRemaining: 0,
            cabin: .standard(abreast: spec.seatsAbreast), wear: 0, condition: 100,
            ageYears: 0, assignedRouteID: nil, groundedWeeksRemaining: 0))
        save()
        // Leased from a route's desk: straight onto that route.
        if let routeID { assign(aircraftID: planeID, to: routeID) }
        return true
    }

    /// Sell an owned, delivered aircraft at depreciated value.
    @discardableResult
    func sellAircraft(aircraftID: UUID) -> Bool {
        guard let i = state.fleet.firstIndex(where: { $0.id == aircraftID }) else { return false }
        let plane = state.fleet[i]
        guard plane.acquisition != .leased, plane.status != .onOrder else { return false }
        state.cash += Balance.resaleValue(type: plane.type, ageYears: plane.ageYears,
                                          condition: plane.condition)
        unassignEverywhere(aircraftID: aircraftID)
        state.fleet.remove(at: i)
        save()
        return true
    }

    /// Return a leased aircraft anytime for a termination fee
    /// (MVP: 4 weeks of payments).
    @discardableResult
    func returnLeasedAircraft(aircraftID: UUID) -> Bool {
        guard let i = state.fleet.firstIndex(where: { $0.id == aircraftID }),
              state.fleet[i].acquisition == .leased else { return false }
        let fee = state.fleet[i].weeklyLeaseCost * Balance.leaseTerminationWeeks
        guard state.cash >= fee else { return false }
        state.cash -= fee
        unassignEverywhere(aircraftID: aircraftID)
        state.fleet.remove(at: i)
        save()
        return true
    }

    private func unassignEverywhere(aircraftID: UUID) {
        for i in state.routes.indices {
            state.routes[i].assignedAircraftIDs.removeAll { $0 == aircraftID }
        }
    }

    @discardableResult
    func openRoute(from originID: String, to destID: String, fare: Double, frequency: Int) -> Route? {
        guard originID != destID,
              city(originID) != nil, city(destID) != nil,
              !state.routes.contains(where: {
                  ($0.originID == originID && $0.destinationID == destID) ||
                  ($0.originID == destID && $0.destinationID == originID) })
        else { return nil }
        // Airport slots are finite (GDD §4.3): clamp to what's free at the
        // more congested endpoint.
        let clamped = min(frequency, freeSlots(at: originID), freeSlots(at: destID))
        let route = Route(id: UUID(), originID: originID, destinationID: destID,
                          distanceKm: Balance.distance(originID, destID),
                          weeklyFrequency: max(0, clamped), fare: fare,
                          assignedAircraftIDs: [], satisfaction: 60,
                          lastLoadFactor: 0, lastWeeklyProfit: 0,
                          lastWeeklyRevenue: 0, lastWeeklyFuel: 0,
                          loadFactorHistory: [], lastPunctuality: 1.0)
        state.routes.append(route)
        save()
        return route
    }

    /// Weekly slots still unused at an airport (optionally ignoring one
    /// route, for editing its own frequency).
    func freeSlots(at cityID: String, excludingRoute routeID: UUID? = nil) -> Int {
        guard let city = city(cityID) else { return 0 }
        let used = state.routes
            .filter { $0.id != routeID && ($0.originID == cityID || $0.destinationID == cityID) }
            .reduce(0) { $0 + $1.weeklyFrequency }
        return max(0, city.weeklySlots - used)
    }

    /// Staff pools currently at strike-risk happiness (GDD §4.4) — feeds
    /// the M3 event deck's weight shifting.
    var strikeRiskPools: [StaffRole] {
        StaffRole.allCases.filter {
            (state.staff[$0]?.headcount ?? 0) > 0
            && (state.staff[$0]?.happiness ?? 100) < Balance.strikeRiskHappinessThreshold
        }
    }

    /// Cancel a route: assigned aircraft go idle (grounded ones finish
    /// their checks first), and the route disappears from the network.
    func closeRoute(routeID: UUID) {
        guard let r = state.routes.firstIndex(where: { $0.id == routeID }) else { return }
        for i in state.fleet.indices where state.fleet[i].assignedRouteID == routeID {
            state.fleet[i].assignedRouteID = nil
            if state.fleet[i].status == .assigned {
                state.fleet[i].status = .idle
            }
        }
        state.routes.remove(at: r)
        save()
    }

    /// Whether an aircraft is physically able to fly a route: delivered,
    /// enough range, and runway class met at BOTH endpoints. The single
    /// source of truth for assignment rules — the UI asks this too.
    func canOperate(aircraftID: UUID, routeID: UUID) -> Bool {
        guard let plane = state.fleet.first(where: { $0.id == aircraftID }),
              let route = state.routes.first(where: { $0.id == routeID }),
              plane.status != .onOrder,
              let origin = city(route.originID), let dest = city(route.destinationID)
        else { return false }
        let spec = Balance.specs[plane.type]!
        // Range is payload-corrected: the same airframe reaches further
        // with an airy cabin than a certified-limit sardine layout.
        return plane.effectiveRangeKm(spec: spec) >= route.distanceKm
            && origin.runwayClass >= spec.requiredRunwayClass
            && dest.runwayClass >= spec.requiredRunwayClass
    }

    /// Pull an aircraft off its route; it goes idle (grounded planes
    /// finish their checks first).
    func unassign(aircraftID: UUID) {
        guard let a = state.fleet.firstIndex(where: { $0.id == aircraftID }) else { return }
        unassignEverywhere(aircraftID: aircraftID)
        state.fleet[a].assignedRouteID = nil
        if state.fleet[a].status == .assigned { state.fleet[a].status = .idle }
        save()
    }

    func assign(aircraftID: UUID, to routeID: UUID) {
        guard let a = state.fleet.firstIndex(where: { $0.id == aircraftID }),
              let r = state.routes.firstIndex(where: { $0.id == routeID }),
              canOperate(aircraftID: aircraftID, routeID: routeID) else { return }

        // Unassign from any previous route first.
        for i in state.routes.indices {
            state.routes[i].assignedAircraftIDs.removeAll { $0 == aircraftID }
        }
        state.routes[r].assignedAircraftIDs.append(aircraftID)
        state.fleet[a].assignedRouteID = routeID
        // A plane still in the shop keeps its maintenance status; the
        // countdown in the tick promotes it to .assigned when it's done.
        if state.fleet[a].groundedWeeksRemaining == 0 {
            state.fleet[a].status = .assigned
        }
        save()
    }

    func orderCheck(aircraftID: UUID, heavy: Bool) {
        guard let i = state.fleet.firstIndex(where: { $0.id == aircraftID }),
              state.fleet[i].status != .onOrder   // can't service an undelivered plane
        else { return }
        let cost = heavy ? 250_000.0 : 30_000.0
        guard state.cash >= cost else { return }
        state.cash -= cost
        state.fleet[i].status = .inMaintenance
        state.fleet[i].groundedWeeksRemaining = heavy ? 2 : 1
        state.fleet[i].wear = heavy ? 0 : max(0, state.fleet[i].wear - 25)
        if heavy { state.fleet[i].condition = min(100, state.fleet[i].condition + 10) }
        save()
    }

    /// Repaint the airline (GDD §4.8 branding). Cosmetic — no sim effects
    /// in MVP; awareness/branding mechanics arrive with M5 marketing.
    func setLivery(_ livery: Livery) {
        state.livery = livery
        save()
    }

    // ── Recruitment (GDD §4.4 as amended) ────────────────────────────────
    // Hiring happens through job ads: applicants arrive with their own
    // skill and asking wage; hire outright, or negotiate — lowballs raise
    // irritation, and irritated applicants walk.

    private func generateApplicant(role: StaffRole) -> JobApplicant {
        let profile = Balance.countryProfiles[state.country]!
        let skill = 1.0 + pow(Double.random(in: 0...1, using: &state.seedRNG), 1.3) * 3.5
        let noise = Double.random(in: -0.08...0.08, using: &state.seedRNG)
        let person = Self.generatePerson(role: role, country: state.country, rng: &state.seedRNG)
        return JobApplicant(
            id: UUID(),
            role: role,
            name: person.name,
            avatar: person.avatar,
            skill: skill,
            askingWage: Balance.askingWage(marketRate: role.marketWage * profile.laborCost,
                                           skill: skill, noise: noise),
            flexibility: Double.random(in: 0.3...0.8, using: &state.seedRNG),
            irritation: 0,
            weeksRemaining: Int.random(in: Balance.applicantPatienceWeeksMin...Balance.applicantPatienceWeeksMax,
                                       using: &state.seedRNG))
    }

    /// Run a job ad for a role. The first wave applies the moment the ad
    /// is up (immediacy rule, GDD amendment 2026-07-18); the weekly tick
    /// keeps the trickle coming. All draws from the seeded RNG.
    @discardableResult
    func postJobAd(role: StaffRole) -> Bool {
        guard state.cash >= Balance.jobAdFee, state.jobPostings[role] == nil else { return false }
        state.cash -= Balance.jobAdFee
        state.jobPostings[role] = Balance.jobPostingWeeks
        let waiting = state.applicants.filter { $0.role == role }.count
        let firstWave = min(1 + (Double.random(in: 0...1, using: &state.seedRNG) < 0.5 ? 1 : 0),
                            Balance.maxApplicantsPerRole - waiting)
        for _ in 0..<max(0, firstWave) {
            state.applicants.append(generateApplicant(role: role))
        }
        save()
        return true
    }

    enum NegotiationOutcome: Equatable {
        case accepted            // hired at your offer
        case countered(Double)   // still talking; their (possibly new) asking wage
        case walkedAway          // you pushed too hard
    }

    /// Make a wage offer. Meeting their number hires on the spot; lowballs
    /// irritate — they may meet you in the middle, hold firm, or walk.
    @discardableResult
    func negotiate(applicantID: UUID, offer: Double) -> NegotiationOutcome? {
        guard let i = state.applicants.firstIndex(where: { $0.id == applicantID }) else { return nil }
        let ratio = max(0, offer) / max(state.applicants[i].askingWage, 1)

        if ratio >= Balance.negotiationAcceptRatio {
            hire(state.applicants[i], atWage: offer)
            state.applicants.remove(at: i)
            save()
            return .accepted
        }

        state.applicants[i].irritation += (1 - ratio) * Balance.negotiationIrritationFactor
        if state.applicants[i].irritation >= 100 {
            state.applicants.remove(at: i)
            save()
            return .walkedAway
        }
        if Double.random(in: 0...1, using: &state.seedRNG) < state.applicants[i].flexibility {
            // Flexible: they meet you in the middle.
            state.applicants[i].askingWage = (state.applicants[i].askingWage + max(offer, 0)) / 2
        } else if ratio < Balance.negotiationInsultRatio,
                  Double.random(in: 0...1, using: &state.seedRNG) < 0.5 {
            // Stubborn AND insulted: gone.
            state.applicants.remove(at: i)
            save()
            return .walkedAway
        }
        let asking = state.applicants[i].askingWage
        save()
        return .countered(asking)
    }

    /// Turn someone away at the desk — they leave the applicant pool now.
    @discardableResult
    func rejectApplicant(applicantID: UUID) -> Bool {
        guard let i = state.applicants.firstIndex(where: { $0.id == applicantID }) else { return false }
        state.applicants.remove(at: i)
        save()
        return true
    }

    /// Hire at their current asking wage, no haggling.
    @discardableResult
    func hireApplicant(applicantID: UUID) -> Bool {
        guard let i = state.applicants.firstIndex(where: { $0.id == applicantID }) else { return false }
        hire(state.applicants[i], atWage: state.applicants[i].askingWage)
        state.applicants.remove(at: i)
        save()
        return true
    }

    /// Hires join the roster by name; the pool's aggregate wage/skill are
    /// recomputed from the members, so a bargain hire lowers the average
    /// wage and a squeezed hire dents morale slightly.
    private func hire(_ applicant: JobApplicant, atWage wage: Double) {
        guard var pool = state.staff[applicant.role] else { return }
        pool.members.append(StaffMember(id: UUID(), name: applicant.name,
                                        skill: applicant.skill, weeklyWage: wage,
                                        hiredOn: state.date,
                                        avatar: applicant.avatar))
        pool.happiness = max(0, pool.happiness - applicant.irritation / 25)
        pool.headcount += 1
        recomputeAggregates(&pool)
        state.staff[applicant.role] = pool
    }

    /// Let a specific person go (from the roster dropdown). Firing stings
    /// the pool's morale a little — people notice.
    @discardableResult
    func fireStaff(role: StaffRole, memberID: UUID) -> Bool {
        guard var pool = state.staff[role],
              let i = pool.members.firstIndex(where: { $0.id == memberID }) else { return false }
        pool.members.remove(at: i)
        pool.headcount = max(0, pool.headcount - 1)
        pool.happiness = max(0, pool.happiness - 3)
        recomputeAggregates(&pool)
        state.staff[role] = pool
        save()
        return true
    }

    /// Direct headcount set (tests + internal): the roster syncs — extra
    /// members are generated at the pool's averages, trims come off the end.
    func setHeadcount(role: StaffRole, count: Int) {
        guard var pool = state.staff[role] else { return }
        let target = max(0, count)
        while pool.members.count > target { pool.members.removeLast() }
        while pool.members.count < target {
            let person = Self.generatePerson(role: role, country: state.country, rng: &state.seedRNG)
            pool.members.append(StaffMember(id: UUID(),
                                            name: person.name,
                                            skill: pool.skill, weeklyWage: pool.weeklyWage,
                                            hiredOn: state.date,
                                            avatar: person.avatar))
        }
        pool.headcount = target
        state.staff[role] = pool
        save()
    }

    /// Pool-wide wage set (the slider): everyone's pay scales to match.
    func setWage(role: StaffRole, wage: Double) {
        guard var pool = state.staff[role] else { return }
        let target = max(0, wage)
        let factor = pool.weeklyWage > 0 ? target / pool.weeklyWage : 1
        for i in pool.members.indices { pool.members[i].weeklyWage *= factor }
        pool.weeklyWage = target
        // Word of a raise (or a cut) travels the same day: morale takes a
        // visible step toward the new pay target NOW, and the weekly drift
        // keeps settling it from there. Same formula as the tick, so the
        // step never disagrees with where the drift is headed.
        let moraleTarget = happinessTarget(role: role, weeklyWage: target,
                                           staffLoad: projectedUtilization(role: role))
        pool.happiness = max(0, min(100,
            pool.happiness + (moraleTarget - pool.happiness) * 0.25))
        state.staff[role] = pool
        save()
    }
    func setFare(routeID: UUID, fare: Double) {
        guard let r = state.routes.firstIndex(where: { $0.id == routeID }) else { return }
        state.routes[r].fare = max(1, fare); save()
    }
    func setFrequency(routeID: UUID, frequency: Int) {
        guard let r = state.routes.firstIndex(where: { $0.id == routeID }) else { return }
        // Clamp to free airport slots at both endpoints (GDD §4.3).
        let route = state.routes[r]
        let slotCap = min(freeSlots(at: route.originID, excludingRoute: routeID),
                          freeSlots(at: route.destinationID, excludingRoute: routeID))
        state.routes[r].weeklyFrequency = max(0, min(28, min(frequency, slotCap)))
        save()
    }

    func takeLoan(amount: Double, weeklyRate: Double = 0.0015, weeks: Int = 260) {
        let payment = amount * weeklyRate / (1 - pow(1 + weeklyRate, -Double(weeks)))
        state.loans.append(Loan(id: UUID(), principal: amount, remaining: amount,
                                weeklyInterestRate: weeklyRate, weeklyPayment: payment))
        state.cash += amount
        save()
    }

    /// Pay a loan down early, full or partial — limited by the loan's
    /// balance and the cash on hand. No penalty; the bank just recomputes
    /// nothing (the fixed weekly payment retires the smaller balance sooner).
    @discardableResult
    func repayLoan(loanID: UUID, amount: Double) -> Bool {
        guard let i = state.loans.firstIndex(where: { $0.id == loanID }) else { return false }
        let payment = min(max(0, amount), state.loans[i].remaining, state.cash)
        guard payment > 0 else { return false }
        state.cash -= payment
        state.loans[i].remaining -= payment
        state.loans.removeAll { $0.remaining <= 0.01 }
        save()
        return true
    }

    // ── The bank (M7): three offers, one lending limit ───────────────────

    var totalDebt: Double { state.loans.reduce(0) { $0 + $1.remaining } }

    /// Whether the bank will extend this offer right now.
    func canBorrow(_ offer: Balance.LoanOffer) -> Bool {
        totalDebt + offer.amount <= Balance.borrowingLimit(netWorth: netWorth)
    }

    @discardableResult
    func takeLoan(offer: Balance.LoanOffer) -> Bool {
        guard canBorrow(offer) else { return false }
        takeLoan(amount: offer.amount, weeklyRate: offer.weeklyRate, weeks: offer.weeks)
        return true
    }

    /// Weekly marketing budget (M5), clamped to the slider's range.
    func setMarketingSpend(_ spend: Double) {
        state.weeklyMarketingSpend = max(0, min(Balance.marketingSpendMax, spend))
        save()
    }

    // ── Derived values for the UI ────────────────────────────────────────

    /// Book value of the owned fleet (leased planes aren't assets — the
    /// lessor owns them). Same formula as resale, so selling is never an
    /// exploit.
    var fleetValue: Double {
        state.fleet
            .filter { $0.acquisition != .leased }
            .reduce(0.0) {
                $0 + Balance.resaleValue(type: $1.type, ageYears: $1.ageYears,
                                         condition: $1.condition)
            }
    }

    var netWorth: Double {
        state.cash + fleetValue - totalDebt
    }
    func city(_ id: String) -> City? { state.cities.first { $0.id == id } }
    var latestReport: WeeklyReport? { state.reports.last }

    // ── The industry ladder (2026-07-18) ─────────────────────────────────
    // Player valuation: book value plus an earnings multiple on the
    // trailing year — simple enough to explain, moves with both growth
    // levers (assets AND profitability).

    var marketCap: Double {
        let trailingYearProfit = state.reports.suffix(52).map(\.profit).reduce(0, +)
        return max(0, max(0, netWorth)
            + Balance.marketCapEarningsMultiple * max(0, trailingYearProfit))
    }

    /// Player's weekly passengers, live-projected (immediacy rule).
    var weeklyPax: Double {
        state.routes.compactMap { routeEconomics(routeID: $0.id)?.pax }.reduce(0, +)
    }

    /// Share of the whole industry's weekly traffic, rivals included.
    var marketShare: Double {
        let pax = weeklyPax
        let industry = Balance.rivals(for: state.country).map(\.weeklyPax).reduce(0, +) + pax
        return industry > 0 ? pax / industry : 0
    }

    /// Rank by market cap among the nine incumbents (1 = biggest).
    var industryRank: (rank: Int, total: Int) {
        let cap = marketCap
        let above = Balance.rivals(for: state.country).filter { $0.marketCap > cap }.count
        return (above + 1, Balance.rivals(for: state.country).count + 1)
    }

    /// The next carrier to overtake, if anyone is still above us.
    var nextRival: Balance.IndustryRival? {
        let cap = marketCap
        return Balance.rivals(for: state.country)
            .filter { $0.marketCap > cap }
            .min { $0.marketCap < $1.marketCap }
    }

    // ── Persistence: three save slots (2026-07-18) ───────────────────────
    // Autosave always writes the ACTIVE slot; the slots screen switches it.

    static let slotCount = 3

    static var activeSlot: Int {
        get {
            let raw = UserDefaults.standard.integer(forKey: "activeSaveSlot")
            return (1...slotCount).contains(raw) ? raw : 1
        }
        set { UserDefaults.standard.set(newValue, forKey: "activeSaveSlot") }
    }

    private static func saveURL(slot: Int) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("skytycoon_save_\(slot).json")
    }

    /// Pre-slots saves become slot 1 (run once at launch).
    static func migrateLegacySave() {
        let legacy = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("skytycoon_save.json")
        guard FileManager.default.fileExists(atPath: legacy.path),
              !FileManager.default.fileExists(atPath: saveURL(slot: 1).path) else { return }
        try? FileManager.default.moveItem(at: legacy, to: saveURL(slot: 1))
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: Self.saveURL(slot: Self.activeSlot), options: .atomic)
        } catch {
            print("Save failed: \(error)")   // never crash the game over a save
        }
    }

    /// Loads the active slot.
    static func load() -> GameEngine? { load(slot: activeSlot) }

    static func load(slot: Int) -> GameEngine? {
        guard let data = try? Data(contentsOf: saveURL(slot: slot)),
              let state = try? JSONDecoder().decode(GameState.self, from: data)
        else { return nil }
        return GameEngine(state: state)
    }

    /// Lightweight peek for the slots screen (nil = empty slot).
    static func slotState(_ slot: Int) -> GameState? {
        guard let data = try? Data(contentsOf: saveURL(slot: slot)),
              let state = try? JSONDecoder().decode(GameState.self, from: data)
        else { return nil }
        return state
    }

    static func deleteSave(slot: Int) {
        try? FileManager.default.removeItem(at: saveURL(slot: slot))
    }
}
