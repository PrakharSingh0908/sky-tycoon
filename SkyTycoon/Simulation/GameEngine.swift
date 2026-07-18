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
    var speed: SimSpeed = .paused

    enum SimSpeed: Double, CaseIterable {
        case paused = 0, x1 = 1, x2 = 2, x4 = 4
        var label: String {
            switch self {
            case .paused: "⏸"; case .x1: "1x"; case .x2: "2x"; case .x4: "4x"
            }
        }
    }

    /// Real seconds of accumulated time per weekly tick at 1x.
    private let secondsPerWeek: Double = 8
    private var accumulator: Double = 0
    private var timer: Timer?

    /// Transient UI hold: while decision UI is open (negotiation, purchase
    /// receipts, confirmations), the clock doesn't advance — the player's
    /// chosen speed resumes when the last one closes. Counted so nested
    /// sheets stack safely. Not part of the save.
    private var interactionHolds = 0
    var clockIsHeld: Bool { interactionHolds > 0 }
    func beginInteraction() { interactionHolds += 1 }
    func endInteraction() { interactionHolds = max(0, interactionHolds - 1) }

    // ── Init / new game ──────────────────────────────────────────────────

    init(state: GameState) { self.state = state }

    static func newGame(airlineName: String, country: Country, seed: UInt64 = .random(in: 0...UInt64.max)) -> GameEngine {
        let profile = Balance.countryProfiles[country]!
        var staff: [StaffRole: StaffPool] = [:]
        for role in StaffRole.allCases {
            staff[role] = StaffPool(role: role, headcount: role == .hq ? 3 : 0,
                                    weeklyWage: role.marketWage * profile.laborCost,
                                    happiness: 70, skill: 2.0, lastUtilization: 0)
        }
        var rng = SeededRandomNumberGenerator(seed: seed)
        let initialMarket = Self.generateUsedListings(rng: &rng)
        let state = GameState(
            seedRNG: rng,
            date: GameDate(week: 1, year: 1),
            country: country,
            airlineName: airlineName,
            cash: profile.startingTrustFund + profile.startingSavings,
            livery: .launch,
            trustFundActive: true,
            trustFundDeadline: GameDate(week: 52, year: 3),
            consecutiveProfitableQuarters: 0,
            reputation: 3.0,
            cities: Balance.indiaCities,          // MVP: India city set for all, swap per-country later
            fleet: [], routes: [], staff: staff, loans: [],
            usedMarket: initialMarket,
            weeksUntilMarketRefresh: Balance.usedMarketRefreshWeeksMin,
            jobPostings: [:], applicants: [],
            sellerOrders: [:],
            pendingEvent: nil, activeEffects: [], lastNegativeEventTotalWeek: 0,
            reports: [],
            netWorthHistory: [], cashHistory: [], reputationHistory: []
        )
        return GameEngine(state: state)
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

    private func clockFired(delta: Double) {
        guard speed != .paused, state.pendingEvent == nil, interactionHolds == 0 else { return }
        accumulator += delta * speed.rawValue
        while accumulator >= secondsPerWeek {
            accumulator -= secondsPerWeek
            advanceWeek()
            if state.pendingEvent != nil { speed = .paused; accumulator = 0; break }
        }
    }

    // ── The weekly tick — the heart of the sim ──────────────────────────
    // Order matters and is fixed: operate → settle → drift → events → bookkeeping.

    func advanceWeek() {
        let profile = Balance.countryProfiles[state.country]!
        var report = WeeklyReport(date: state.date, revenue: 0, fuelCost: 0,
                                  wageCost: 0, maintenanceCost: 0, loanCost: 0,
                                  leaseCost: 0, cabinCost: 0,
                                  overheadCost: Balance.hqOverheadPerWeek)

        // 0. DELIVERIES — new-plane orders count down and enter service.
        for i in state.fleet.indices where state.fleet[i].status == .onOrder {
            state.fleet[i].deliveryWeeksRemaining -= 1
            if state.fleet[i].deliveryWeeksRemaining <= 0 {
                state.fleet[i].deliveryWeeksRemaining = 0
                state.fleet[i].status = .idle
            }
        }

        // 1. MAINTENANCE COUNTDOWN — planes return to service.
        for i in state.fleet.indices where state.fleet[i].groundedWeeksRemaining > 0 {
            state.fleet[i].groundedWeeksRemaining -= 1
            if state.fleet[i].groundedWeeksRemaining == 0 {
                state.fleet[i].status = state.fleet[i].assignedRouteID == nil ? .idle : .assigned
            }
        }

        // 2. CREW-HOURS (GDD §4.4) — what this week's schedule demands of
        // each pool, compared against roster capacity. Computed BEFORE
        // operating because punctuality (from strain) feeds satisfaction.
        var activePlanesByRoute: [[Aircraft]] = Array(repeating: [], count: state.routes.count)
        for r in state.routes.indices where state.routes[r].weeklyFrequency > 0 {
            activePlanesByRoute[r] = state.fleet.filter {
                state.routes[r].assignedAircraftIDs.contains($0.id) && $0.groundedWeeksRemaining == 0
            }
        }

        var crewDemandHours: [StaffRole: Double] = [:]
        for r in state.routes.indices {
            let route = state.routes[r]
            for plane in activePlanesByRoute[r] {
                let spec = Balance.specs[plane.type]!
                // A round trip = two legs of cruise plus turnaround duty.
                let blockHours = 2 * (route.distanceKm / spec.cruiseKmh + Balance.turnaroundHoursPerLeg)
                let trips = Double(route.weeklyFrequency)
                crewDemandHours[.pilots, default: 0] += Double(spec.pilotsPerFlight) * blockHours * trips
                crewDemandHours[.cabinCrew, default: 0] += Double(spec.cabinCrewPerFlight) * blockHours * trips
                crewDemandHours[.ground, default: 0] += Balance.groundHoursPerDeparture * 2 * trips
            }
        }
        let deliveredFleet = state.fleet.filter { $0.status != .onOrder }.count
        crewDemandHours[.hq] = Balance.hqBaseHours
            + Balance.hqHoursPerAircraft * Double(deliveredFleet)
            + Balance.hqHoursPerRoute * Double(state.routes.count)

        var utilization: [StaffRole: Double] = [:]
        for role in StaffRole.allCases {
            let demand = crewDemandHours[role] ?? 0
            let capacity = Double(state.staff[role]?.headcount ?? 0) * Balance.weeklyHoursPerStaff
            // An empty pool with work to do is maximally strained.
            utilization[role] = capacity > 0 ? demand / capacity
                              : (demand > 0 ? Balance.maxStrainPerPool + 1 : 0)
        }

        // Airline-wide punctuality: over-roster strain causes delays, ops
        // skill (pilots + ground) prevents them. (Iterate allCases, not the
        // dictionary — float addition order must be deterministic.)
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

        // Timed event modifiers in force this week (fuel spikes, demand
        // surges) — products of all active effects of each kind.
        let fuelEventMult = state.activeEffects
            .filter { $0.kind == .fuelPrice }.reduce(1.0) { $0 * $1.multiplier }
        let demandEventMult = state.activeEffects
            .filter { $0.kind == .demand }.reduce(1.0) { $0 * $1.multiplier }

        // 3. OPERATE ROUTES — demand, revenue, fuel, wear, satisfaction.
        for r in state.routes.indices {
            let route = state.routes[r]
            guard route.weeklyFrequency > 0 else { continue }
            let activePlanes = activePlanesByRoute[r]
            guard !activePlanes.isEmpty else {
                state.routes[r].lastLoadFactor = 0
                state.routes[r].lastWeeklyProfit = 0
                appendLoadFactor(0, routeIndex: r)
                continue
            }

            let origin = city(route.originID)!
            let dest = city(route.destinationID)!

            // Gravity demand (GDD §4.3), weekly, both directions combined.
            let gravity = Balance.demandK
                * pow(origin.population * dest.population, 0.55)
                / pow(route.distanceKm, 0.35)
            let growth = pow(1 + profile.demandGrowthPerYear, Double(state.date.year - 1))
            let season = 1.0 + 0.20 * sin(Double(state.date.week) / 52.0 * 2 * .pi)
            let brand = 0.5 + (state.reputation / 5.0) * 1.1     // 0.5 ... 1.6

            let referenceFare = route.distanceKm * Balance.referenceFarePerKm * profile.fareLevel
            let priceRatio = route.fare / max(referenceFare, 1)
            let priceResponse = pow(priceRatio, -profile.priceElasticity)

            let demand = gravity * growth * season * brand * min(priceResponse, 2.5)
                * demandEventMult

            // Capacity offered this week.
            var seatsOffered = 0
            var avgComfort = 0.0
            for plane in activePlanes {
                let spec = Balance.specs[plane.type]!
                seatsOffered += plane.seats(spec: spec) * route.weeklyFrequency * 2
                avgComfort += plane.comfortScore
            }
            avgComfort /= Double(activePlanes.count)

            let pax = min(demand, Double(seatsOffered))
            let loadFactor = seatsOffered > 0 ? pax / Double(seatsOffered) : 0
            let revenue = pax * route.fare

            // Costs: the AIRFRAME burns fuel (max seats), regardless of how
            // the cabin is configured — a spacious cabin doesn't shrink the
            // plane. This keeps the seat-config tradeoff honest: fewer seats,
            // same fuel. Poor condition adds a burn penalty (GDD §4.1).
            var fuel = 0.0
            for plane in activePlanes {
                let spec = Balance.specs[plane.type]!
                fuel += Double(spec.maxSeats) * route.distanceKm
                     * spec.fuelBurnPerSeatKm * Double(route.weeklyFrequency) * 2
                     * Balance.fuelPricePerUnit * profile.fuelCost
                     * Balance.fuelConditionMultiplier(condition: plane.condition)
                     * fuelEventMult
            }

            report.revenue += revenue
            report.fuelCost += fuel
            state.routes[r].lastLoadFactor = loadFactor
            state.routes[r].lastWeeklyProfit = revenue - fuel   // route-level, pre-overhead
            appendLoadFactor(loadFactor, routeIndex: r)

            // Wear accumulates with flight hours; worse condition wears faster.
            for plane in activePlanes {
                if let idx = state.fleet.firstIndex(where: { $0.id == plane.id }) {
                    let spec = Balance.specs[plane.type]!
                    let hours = route.distanceKm / spec.cruiseKmh * Double(route.weeklyFrequency) * 2
                    state.fleet[idx].wear = min(100, state.fleet[idx].wear
                        + hours * 0.25 * (1.5 - state.fleet[idx].condition / 200))
                }
            }

            // Route satisfaction drifts toward the GDD §4.5 weighted target:
            // punctuality 35%, comfort 25%, service 20%, price fairness 15%,
            // incidents 5% (placeholder 1.0 until M3's event deck).
            let cabinSkill = state.staff[.cabinCrew]?.skill ?? 1
            let cabinU = utilization[.cabinCrew] ?? 0
            let cabinAdequacy = cabinU <= 1 ? 1.0 : 1.0 / cabinU   // understaffed cabin = worse service
            let service = (cabinSkill / 5.0) * cabinAdequacy
            let fairness = max(0, min(1, 1.4 - priceRatio * 0.6))
            let incidents = 1.0
            let target = (punctuality * 0.35 + avgComfort * 0.25 + service * 0.20
                          + fairness * 0.15 + incidents * 0.05) * 100
            state.routes[r].satisfaction += (target - route.satisfaction) * 0.15
            state.routes[r].lastPunctuality = punctuality
        }

        // 4. WAGES, overtime, happiness (pay AND workload), attrition.
        for role in StaffRole.allCases {
            guard var pool = state.staff[role] else { continue }
            let u = utilization[role] ?? 0
            let demand = crewDemandHours[role] ?? 0
            let capacity = Double(pool.headcount) * Balance.weeklyHoursPerStaff
            report.wageCost += Double(pool.headcount) * pool.weeklyWage

            // Hours beyond capacity are worked anyway — at 1.5×. An empty
            // pool means contractors at market rate: flights still fly, but
            // expensively and badly (the punctuality hit above).
            let marketRate = role.marketWage * profile.laborCost
            let overtimeHours = max(0, demand - capacity)
            if overtimeHours > 0 {
                let hourly = (pool.headcount > 0 ? pool.weeklyWage : marketRate)
                    / Balance.weeklyHoursPerStaff
                report.wageCost += overtimeHours * hourly * Balance.overtimeMultiplier
            }

            // Happiness target: pay vs market, minus overwork (GDD §4.4 —
            // an overworked pool drifts down even at market wage).
            let payFactor = pool.weeklyWage / max(marketRate, 1)   // >1 = generous
            let workloadPenalty = Balance.workloadHappinessPenalty
                * min(Balance.maxStrainPerPool, max(0, u - 1))
            let target = min(100, max(0, 50 + (payFactor - 1) * 120 - workloadPenalty))
            pool.happiness += (target - pool.happiness) * 0.08

            // Below the attrition threshold, people quit each week. The
            // fractional expectation is rounded probabilistically via the
            // seeded RNG (deterministic for a given state).
            if pool.happiness < Balance.attritionHappinessThreshold && pool.headcount > 0 {
                let severity = (Balance.attritionHappinessThreshold - pool.happiness)
                    / Balance.attritionHappinessThreshold
                let expected = Double(pool.headcount) * Balance.attritionMaxRatePerWeek * severity
                var leavers = Int(expected)
                if Double.random(in: 0...1, using: &state.seedRNG) < expected - Double(leavers) {
                    leavers += 1
                }
                pool.headcount = max(0, pool.headcount - leavers)
            }

            // Skill creeps up slowly with tenure.
            pool.skill = min(5, pool.skill + 0.005)
            pool.lastUtilization = u
            state.staff[role] = pool
        }

        // 5. MAINTENANCE base costs (grounded or not, planes cost money).
        for plane in state.fleet where plane.status != .onOrder {
            let spec = Balance.specs[plane.type]!
            report.maintenanceCost += spec.baseMaintPerWeek
                * (1 + plane.wear / 200) * (2 - plane.condition / 100)
        }

        // 5b. LEASE PAYMENTS — their own P&L line, forever (GDD §4.1).
        for plane in state.fleet where plane.acquisition == .leased {
            report.leaseCost += plane.weeklyLeaseCost
        }

        // 5c. CABIN upkeep — interiors cost money to run (GDD §4.2 amended):
        // seat cleaning by material, catering ops per galley, wifi service.
        for plane in state.fleet where plane.status != .onOrder {
            report.cabinCost += plane.cabin.weeklyUpkeep(spec: Balance.specs[plane.type]!)
        }

        // 6. LOANS.
        for i in state.loans.indices {
            let interest = state.loans[i].remaining * state.loans[i].weeklyInterestRate
            let payment = min(state.loans[i].weeklyPayment, state.loans[i].remaining + interest)
            report.loanCost += payment
            state.loans[i].remaining = max(0, state.loans[i].remaining + interest - payment)
        }
        state.loans.removeAll { $0.remaining <= 0.01 }

        // 7. SETTLE cash and reputation.
        state.cash += report.profit
        let paxWeightedSat = state.routes.isEmpty ? 60.0
            : state.routes.map(\.satisfaction).reduce(0, +) / Double(state.routes.count)
        let repTarget = 1 + (paxWeightedSat / 100) * 4
        state.reputation += (repTarget - state.reputation) * 0.06   // 8-week-ish smoothing

        // 8. EVENTS — weighted deck, weights shifted by game state.
        drawEvent()

        // Timed effects age out.
        for i in state.activeEffects.indices { state.activeEffects[i].weeksRemaining -= 1 }
        state.activeEffects.removeAll { $0.weeksRemaining <= 0 }

        // 9. BOOKKEEPING — aging, market refresh, reports, quarters, date, autosave.

        // M0 fix: aircraft aging. Depreciation and netWorth depend on ageYears,
        // which was never incremented. Age every delivered airframe by one week.
        for i in state.fleet.indices where state.fleet[i].status != .onOrder {
            state.fleet[i].ageYears += 1.0 / 52.0
        }

        // Recruitment (GDD §4.4 as amended): active job ads attract 1–2
        // applicants per week; waiting applicants eventually take other
        // jobs. All draws from the seeded RNG in fixed role order.
        for role in StaffRole.allCases {
            guard let weeksLeft = state.jobPostings[role] else { continue }
            let waiting = state.applicants.filter { $0.role == role }.count
            let count = min(1 + (Double.random(in: 0...1, using: &state.seedRNG) < 0.5 ? 1 : 0),
                            Balance.maxApplicantsPerRole - waiting)
            for _ in 0..<max(0, count) {
                state.applicants.append(generateApplicant(role: role))
            }
            state.jobPostings[role] = weeksLeft <= 1 ? nil : weeksLeft - 1
        }
        for i in state.applicants.indices { state.applicants[i].weeksRemaining -= 1 }
        state.applicants.removeAll { $0.weeksRemaining <= 0 }

        // Used market rotates every few weeks (seeded RNG — deterministic).
        state.weeksUntilMarketRefresh -= 1
        if state.weeksUntilMarketRefresh <= 0 {
            state.usedMarket = Self.generateUsedListings(rng: &state.seedRNG)
            state.weeksUntilMarketRefresh = Int.random(
                in: Balance.usedMarketRefreshWeeksMin...Balance.usedMarketRefreshWeeksMax,
                using: &state.seedRNG)
        }

        state.reports.append(report)
        if state.reports.count > 52 { state.reports.removeFirst() }
        appendHistory(\.netWorthHistory, netWorth)
        appendHistory(\.cashHistory, state.cash)
        appendHistory(\.reputationHistory, state.reputation)

        if state.date.week % 13 == 0 { closeQuarter() }
        state.date.advance()

        // M0 fix: autosave. The GDD promises autosave every tick; the tick
        // never called save(). Persist at the end of every week.
        save()
    }

    /// Appends to a capped 260-week (5-year) history buffer.
    private func appendHistory(_ keyPath: WritableKeyPath<GameState, [Double]>, _ value: Double) {
        state[keyPath: keyPath].append(value)
        if state[keyPath: keyPath].count > 260 { state[keyPath: keyPath].removeFirst() }
    }

    /// Appends to a route's capped 26-week load-factor sparkline buffer.
    private func appendLoadFactor(_ value: Double, routeIndex: Int) {
        state.routes[routeIndex].loadFactorHistory.append(value)
        if state.routes[routeIndex].loadFactorHistory.count > 26 {
            state.routes[routeIndex].loadFactorHistory.removeFirst()
        }
    }

    private func closeQuarter() {
        let quarterReports = state.reports.suffix(13)
        let quarterProfit = quarterReports.map(\.profit).reduce(0, +)
        if quarterProfit > 0 {
            state.consecutiveProfitableQuarters += 1
        } else {
            state.consecutiveProfitableQuarters = 0
        }
        if state.trustFundActive && state.date > state.trustFundDeadline
            && state.consecutiveProfitableQuarters < 4 {
            state.trustFundActive = false
            // TODO: fire the "Aunt withdraws the fund" story event here. (M6)
        }
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
        }
        return weight
    }

    private func drawEvent() {
        guard state.date.totalWeeks > Balance.eventGraceWeeks,
              state.pendingEvent == nil,
              Double.random(in: 0...1, using: &state.seedRNG) < Balance.eventChancePerWeek
        else { return }

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

    /// Fires a card (internal so tests can force specific cards).
    func present(_ card: EventCard) {
        state.pendingEvent = GameEvent(
            id: UUID(), cardID: card.id, category: card.category,
            isNegative: card.isNegative, title: card.title, body: card.body,
            options: card.options, firedOn: state.date)
        if card.isNegative {
            state.lastNegativeEventTotalWeek = state.date.totalWeeks
        }
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
        }
    }

    // ── Player actions (the ONLY external mutation points) ──────────────

    // NOTE (staff dictionary mutations): always read-modify-write via a
    // local copy. An optional-chained write whose RHS reads the same
    // dictionary is a Swift exclusivity violation through @Observable's
    // _modify — it aborts at runtime. apply(_:) follows this pattern.
    func resolveEvent(option: EventOption) {
        guard state.pendingEvent != nil else { return }
        for effect in option.effects {
            apply(effect)
        }
        state.pendingEvent = nil
        save()
    }

    // ── Fleet acquisition (GDD §4.1): new order / used / lease ──────────

    /// Loyalty: factory-new orders from the same manufacturer earn 3% off
    /// each subsequent order, capped at 12% (GDD §4.1).
    func loyaltyDiscount(seller: String) -> Double {
        min(Balance.loyaltyDiscountCap,
            Double(state.sellerOrders[seller] ?? 0) * Balance.loyaltyDiscountPerOrder)
    }

    /// What a factory-new order actually costs right now, loyalty included.
    func discountedPrice(for type: AircraftType) -> Double {
        let spec = Balance.specs[type]!
        return spec.purchasePrice * (1 - loyaltyDiscount(seller: spec.seller))
    }

    /// Buying new is an ORDER: cash up front, plane arrives after the
    /// archetype's delivery wait (status .onOrder until then).
    @discardableResult
    func orderNewAircraft(type: AircraftType, nickname: String) -> Bool {
        let spec = Balance.specs[type]!
        let price = discountedPrice(for: type)
        guard state.cash >= price else { return false }
        state.cash -= price
        state.sellerOrders[spec.seller, default: 0] += 1
        state.fleet.append(Aircraft(id: UUID(), type: type, nickname: nickname,
            status: .onOrder, acquisition: .ownedNew, weeklyLeaseCost: 0,
            deliveryWeeksRemaining: Balance.deliveryWeeks[type]!,
            cabin: .standard(abreast: spec.seatsAbreast), wear: 0, condition: 100,
            ageYears: 0, assignedRouteID: nil, groundedWeeksRemaining: 0))
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
    func buyUsedAircraft(listingID: UUID, nickname: String) -> Bool {
        guard let idx = state.usedMarket.firstIndex(where: { $0.id == listingID }) else { return false }
        let listing = state.usedMarket[idx]
        guard state.cash >= listing.price else { return false }
        state.cash -= listing.price
        state.usedMarket.remove(at: idx)
        state.fleet.append(Aircraft(id: UUID(), type: listing.type, nickname: nickname,
            status: .idle, acquisition: .ownedUsed, weeklyLeaseCost: 0,
            deliveryWeeksRemaining: 0,
            cabin: .standard(abreast: Balance.specs[listing.type]!.seatsAbreast),
            wear: 0, condition: listing.condition,
            ageYears: listing.ageYears, assignedRouteID: nil, groundedWeeksRemaining: 0))
        save()
        return true
    }

    /// Leasing: any archetype instantly, no capital outlay, a weekly
    /// payment that never ends. The cautious player's first plane.
    @discardableResult
    func leaseAircraft(type: AircraftType, nickname: String) -> Bool {
        let spec = Balance.specs[type]!
        state.fleet.append(Aircraft(id: UUID(), type: type, nickname: nickname,
            status: .idle, acquisition: .leased,
            weeklyLeaseCost: spec.purchasePrice * Balance.leaseRatePerWeek,
            deliveryWeeksRemaining: 0,
            cabin: .standard(abreast: spec.seatsAbreast), wear: 0, condition: 100,
            ageYears: 0, assignedRouteID: nil, groundedWeeksRemaining: 0))
        save()
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
        let first = Balance.applicantFirstNames.randomElement(using: &state.seedRNG)!
        let last = Balance.applicantLastNames.randomElement(using: &state.seedRNG)!
        return JobApplicant(
            id: UUID(),
            role: role,
            name: "\(first) \(last)",
            skill: skill,
            askingWage: Balance.askingWage(marketRate: role.marketWage * profile.laborCost,
                                           skill: skill, noise: noise),
            flexibility: Double.random(in: 0.3...0.8, using: &state.seedRNG),
            irritation: 0,
            weeksRemaining: Int.random(in: Balance.applicantPatienceWeeksMin...Balance.applicantPatienceWeeksMax,
                                       using: &state.seedRNG))
    }

    /// Run a job ad for a role. Applicants trickle in on the weekly tick.
    @discardableResult
    func postJobAd(role: StaffRole) -> Bool {
        guard state.cash >= Balance.jobAdFee, state.jobPostings[role] == nil else { return false }
        state.cash -= Balance.jobAdFee
        state.jobPostings[role] = Balance.jobPostingWeeks
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

    /// Hire at their current asking wage, no haggling.
    @discardableResult
    func hireApplicant(applicantID: UUID) -> Bool {
        guard let i = state.applicants.firstIndex(where: { $0.id == applicantID }) else { return false }
        hire(state.applicants[i], atWage: state.applicants[i].askingWage)
        state.applicants.remove(at: i)
        save()
        return true
    }

    /// Individual hires blend into the aggregate pool: wage and skill
    /// become headcount-weighted averages, so a bargain hire lowers the
    /// pool's average wage and a squeezed hire dents morale slightly.
    private func hire(_ applicant: JobApplicant, atWage wage: Double) {
        guard var pool = state.staff[applicant.role] else { return }
        let n = Double(pool.headcount)
        pool.weeklyWage = n == 0 ? wage : (pool.weeklyWage * n + wage) / (n + 1)
        pool.skill = n == 0 ? applicant.skill
                            : min(5, (pool.skill * n + applicant.skill) / (n + 1))
        pool.happiness = max(0, pool.happiness - applicant.irritation / 25)
        pool.headcount += 1
        state.staff[applicant.role] = pool
    }

    func setHeadcount(role: StaffRole, count: Int) {
        state.staff[role]?.headcount = max(0, count); save()
    }
    func setWage(role: StaffRole, wage: Double) {
        state.staff[role]?.weeklyWage = max(0, wage); save()
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

    // ── Derived values for the UI ────────────────────────────────────────

    var netWorth: Double {
        // Leased planes aren't assets — the lessor owns them.
        let fleetValue = state.fleet
            .filter { $0.acquisition != .leased }
            .reduce(0.0) {
                $0 + Balance.resaleValue(type: $1.type, ageYears: $1.ageYears,
                                         condition: $1.condition)
            }
        let debt = state.loans.reduce(0.0) { $0 + $1.remaining }
        return state.cash + fleetValue - debt
    }
    func city(_ id: String) -> City? { state.cities.first { $0.id == id } }
    var latestReport: WeeklyReport? { state.reports.last }

    // ── Persistence (snapshot save) ──────────────────────────────────────

    private static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("skytycoon_save.json")
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: Self.saveURL, options: .atomic)
        } catch {
            print("Save failed: \(error)")   // never crash the game over a save
        }
    }

    static func load() -> GameEngine? {
        guard let data = try? Data(contentsOf: saveURL),
              let state = try? JSONDecoder().decode(GameState.self, from: data)
        else { return nil }
        return GameEngine(state: state)
    }
}
