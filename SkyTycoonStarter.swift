//
//  SkyTycoonStarter.swift
//  SkyTycoon — starter framework
//
//  A single-file foundation you can paste into a fresh Xcode "App" project
//  (iOS 17+, SwiftUI). Replace the contents of ContentView.swift with this file,
//  or better: paste it in, run it once, then split into the folder structure
//  suggested at the bottom.
//
//  ARCHITECTURE (the "best strategy" part, in brief):
//
//  1. SIMULATION CORE IS PURE SWIFT.
//     Everything in MARK sections 1–4 imports nothing but Foundation.
//     No SwiftUI, no UIKit. This means the whole game logic is unit-testable,
//     deterministic, and portable. The UI is a dumb renderer on top.
//
//  2. DETERMINISM VIA SEEDED RNG.
//     The sim never calls Int.random(). All randomness flows through one
//     SeededRandomNumberGenerator stored in GameState. Same state + same seed
//     = identical outcome, forever. This makes bugs reproducible and replays,
//     tests, and future multiplayer/ghost features possible.
//
//  3. VALUE-TYPE STATE, SINGLE MUTATION OWNER.
//     All models are structs (Codable, Identifiable). The only class is
//     GameEngine, which owns the one GameState and is the only thing allowed
//     to mutate it. SwiftUI observes the engine via @Observable.
//
//  4. FIXED-TIMESTEP TICK LOOP.
//     Real time accumulates; whenever it crosses the per-week threshold, the
//     engine runs exactly one advanceWeek(). Sim speed changes accumulation,
//     never the tick math. The sim is identical at 1x and 4x.
//
//  5. SAVE = SNAPSHOT.
//     GameState is one Codable blob. Autosave every tick. A save version int
//     is included from day one so you can migrate formats later.
//
//  6. BALANCE AS DATA.
//     Aircraft specs, city lists, and tuning constants live in `Balance` —
//     one place to tweak, and trivially movable to bundled JSON later.
//

import SwiftUI

// ═════════════════════════════════════════════════════════════════════════
// MARK: - 1. Deterministic RNG (sim core)
// ═════════════════════════════════════════════════════════════════════════

/// SplitMix64 — tiny, fast, high-quality, and Codable so the RNG state
/// itself is part of the save file (crucial: reload mid-game and the
/// future stays the same).
struct SeededRandomNumberGenerator: RandomNumberGenerator, Codable {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - 2. Models (sim core — pure structs, all Codable)
// ═════════════════════════════════════════════════════════════════════════

struct GameDate: Codable, Equatable, Comparable, CustomStringConvertible {
    var week: Int   // 1...52
    var year: Int   // starts at 1

    mutating func advance() {
        week += 1
        if week > 52 { week = 1; year += 1 }
    }
    var totalWeeks: Int { (year - 1) * 52 + week }
    var quarter: Int { (week - 1) / 13 + 1 }
    var description: String { "Y\(year) W\(week)" }
    static func < (l: GameDate, r: GameDate) -> Bool { l.totalWeeks < r.totalWeeks }
}

enum Country: String, Codable, CaseIterable, Identifiable {
    case india, us, uk, china, australia
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .india: "India"; case .us: "United States"; case .uk: "United Kingdom"
        case .china: "China"; case .australia: "Australia"
        }
    }
}

/// Country coefficient set — one economy, five flavors (GDD §5).
struct CountryProfile: Codable {
    var fareLevel: Double        // multiplier on reference fares
    var priceElasticity: Double  // leisure elasticity magnitude
    var laborCost: Double        // wage multiplier
    var fuelCost: Double         // fuel multiplier
    var demandGrowthPerYear: Double
    var startingTrustFund: Double
    var startingSavings: Double
}

struct City: Codable, Identifiable, Hashable {
    let id: String               // stable slug, e.g. "BLR"
    var name: String
    var population: Double       // millions
    var businessIndex: Double    // 0...1, share of demand that is business travel
    var runwayClass: Int         // 1 = regional strip ... 3 = major international
    var weeklySlots: Int
}

enum AircraftType: String, Codable, CaseIterable, Identifiable {
    case regionalTurboprop, smallNarrowbody, largeNarrowbody
    var id: String { rawValue }
}

/// Static spec sheet per archetype. Instances reference this by type.
struct AircraftSpec: Codable {
    var displayName: String
    var maxSeats: Int            // at maximum density
    var rangeKm: Double
    var cruiseKmh: Double
    var purchasePrice: Double
    var fuelBurnPerSeatKm: Double
    var pilotsPerFlight: Int
    var cabinCrewPerFlight: Int
    var baseMaintPerWeek: Double
    var requiredRunwayClass: Int
}

enum AircraftStatus: String, Codable {
    case idle, assigned, inMaintenance, onOrder
}

struct Aircraft: Codable, Identifiable {
    let id: UUID
    var type: AircraftType
    var nickname: String
    var status: AircraftStatus
    /// 0 (sardine) ... 1 (spacious). Fewer seats, more comfort.
    var comfortConfig: Double
    /// 0...100. Accumulates per flight-hour; checks reduce it.
    var wear: Double
    /// 1...100. Second-hand planes arrive with less; heavy checks restore a bit.
    var condition: Double
    var ageYears: Double
    var assignedRouteID: UUID?
    /// Weeks remaining out of service (maintenance), 0 = available.
    var groundedWeeksRemaining: Int

    func seats(spec: AircraftSpec) -> Int {
        // Spacious config gives up to 30% of seats back as legroom.
        let density = 1.0 - comfortConfig * 0.30
        return max(1, Int(Double(spec.maxSeats) * density))
    }
    /// 0...1 comfort score fed into satisfaction.
    var comfortScore: Double {
        (0.35 + comfortConfig * 0.5) * (0.7 + 0.3 * condition / 100.0)
    }
}

struct Route: Codable, Identifiable {
    let id: UUID
    var originID: String
    var destinationID: String
    var distanceKm: Double
    var weeklyFrequency: Int      // round trips per week
    var fare: Double              // one-way economy fare, player-set
    var assignedAircraftIDs: [UUID]
    /// Rolling satisfaction 0...100 for this route.
    var satisfaction: Double
    /// Last week's stats, for UI.
    var lastLoadFactor: Double
    var lastWeeklyProfit: Double
}

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case pilots, cabinCrew, ground, hq
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pilots: "Pilots"; case .cabinCrew: "Cabin Crew"
        case .ground: "Ground & Maintenance"; case .hq: "HQ & Ops"
        }
    }
    /// Weekly market-rate wage before country labor multiplier.
    var marketWage: Double {
        switch self {
        case .pilots: 3000; case .cabinCrew: 900; case .ground: 800; case .hq: 1100
        }
    }
}

struct StaffPool: Codable {
    var role: StaffRole
    var headcount: Int
    var weeklyWage: Double        // player-set, compared against market rate
    var happiness: Double         // 0...100
    var skill: Double             // 1...5
}

struct Loan: Codable, Identifiable {
    let id: UUID
    var principal: Double
    var remaining: Double
    var weeklyInterestRate: Double
    var weeklyPayment: Double
}

/// A choice card presented to the player (GDD §4.7).
struct GameEvent: Codable, Identifiable {
    let id: UUID
    var title: String
    var body: String
    var options: [EventOption]
    var firedOn: GameDate
}

struct EventOption: Codable, Identifiable {
    var id: UUID = UUID()
    var label: String
    /// Keep effects as simple typed deltas for now; grow into a proper
    /// effect system (enum with associated values) as the deck grows.
    var cashDelta: Double = 0
    var happinessDelta: Double = 0        // applied to all pools
    var satisfactionDelta: Double = 0     // applied to all routes
}

struct WeeklyReport: Codable, Identifiable {
    var id: UUID = UUID()
    var date: GameDate
    var revenue: Double
    var fuelCost: Double
    var wageCost: Double
    var maintenanceCost: Double
    var loanCost: Double
    var overheadCost: Double
    var profit: Double { revenue - fuelCost - wageCost - maintenanceCost - loanCost - overheadCost }
}

/// THE save file. Everything lives here; the engine mutates only this.
struct GameState: Codable {
    var saveVersion: Int = 1
    var seedRNG: SeededRandomNumberGenerator
    var date: GameDate
    var country: Country
    var airlineName: String

    var cash: Double
    var trustFundActive: Bool
    var trustFundDeadline: GameDate
    var consecutiveProfitableQuarters: Int
    var reputation: Double            // 1...5 stars

    var cities: [City]
    var fleet: [Aircraft]
    var routes: [Route]
    var staff: [StaffRole: StaffPool]
    var loans: [Loan]

    var pendingEvent: GameEvent?
    var reports: [WeeklyReport]       // capped ring buffer (last 52)
    var netWorthHistory: [Double]
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - 3. Balance data (sim core — future JSON)
// ═════════════════════════════════════════════════════════════════════════

enum Balance {
    static let specs: [AircraftType: AircraftSpec] = [
        .regionalTurboprop: .init(displayName: "RT-70 Turboprop", maxSeats: 78,
            rangeKm: 1500, cruiseKmh: 510, purchasePrice: 18_000_000,
            fuelBurnPerSeatKm: 0.021, pilotsPerFlight: 2, cabinCrewPerFlight: 2,
            baseMaintPerWeek: 9_000, requiredRunwayClass: 1),
        .smallNarrowbody: .init(displayName: "SN-150", maxSeats: 149,
            rangeKm: 3500, cruiseKmh: 830, purchasePrice: 55_000_000,
            fuelBurnPerSeatKm: 0.024, pilotsPerFlight: 2, cabinCrewPerFlight: 4,
            baseMaintPerWeek: 18_000, requiredRunwayClass: 2),
        .largeNarrowbody: .init(displayName: "LN-220", maxSeats: 220,
            rangeKm: 6000, cruiseKmh: 840, purchasePrice: 95_000_000,
            fuelBurnPerSeatKm: 0.022, pilotsPerFlight: 2, cabinCrewPerFlight: 6,
            baseMaintPerWeek: 28_000, requiredRunwayClass: 2),
    ]

    static let countryProfiles: [Country: CountryProfile] = [
        .india: .init(fareLevel: 0.6, priceElasticity: 1.8, laborCost: 0.4,
            fuelCost: 1.3, demandGrowthPerYear: 0.09,
            startingTrustFund: 2_000_000, startingSavings: 400_000),
        .us: .init(fareLevel: 1.3, priceElasticity: 1.2, laborCost: 1.5,
            fuelCost: 1.0, demandGrowthPerYear: 0.02,
            startingTrustFund: 6_000_000, startingSavings: 1_200_000),
        .uk: .init(fareLevel: 1.2, priceElasticity: 1.2, laborCost: 1.3,
            fuelCost: 1.1, demandGrowthPerYear: 0.015,
            startingTrustFund: 5_000_000, startingSavings: 1_000_000),
        .china: .init(fareLevel: 0.8, priceElasticity: 1.5, laborCost: 0.5,
            fuelCost: 0.9, demandGrowthPerYear: 0.08,
            startingTrustFund: 3_000_000, startingSavings: 600_000),
        .australia: .init(fareLevel: 1.4, priceElasticity: 0.9, laborCost: 1.4,
            fuelCost: 1.05, demandGrowthPerYear: 0.02,
            startingTrustFund: 5_500_000, startingSavings: 1_100_000),
    ]

    /// MVP: India only. Other countries slot in identically later.
    static let indiaCities: [City] = [
        .init(id: "DEL", name: "Delhi",     population: 32.0, businessIndex: 0.35, runwayClass: 3, weeklySlots: 60),
        .init(id: "BOM", name: "Mumbai",    population: 24.0, businessIndex: 0.45, runwayClass: 3, weeklySlots: 50),
        .init(id: "BLR", name: "Bangalore", population: 13.0, businessIndex: 0.45, runwayClass: 3, weeklySlots: 55),
        .init(id: "HYD", name: "Hyderabad", population: 10.5, businessIndex: 0.35, runwayClass: 3, weeklySlots: 55),
        .init(id: "MAA", name: "Chennai",   population: 11.5, businessIndex: 0.30, runwayClass: 3, weeklySlots: 50),
        .init(id: "CCU", name: "Kolkata",   population: 15.0, businessIndex: 0.25, runwayClass: 2, weeklySlots: 45),
        .init(id: "PNQ", name: "Pune",      population: 7.5,  businessIndex: 0.30, runwayClass: 2, weeklySlots: 30),
        .init(id: "GOI", name: "Goa",       population: 1.6,  businessIndex: 0.08, runwayClass: 2, weeklySlots: 30),
    ]

    /// Straight-line-ish distances (km) for the MVP city set.
    static let distances: [String: Double] = [
        "DEL-BOM": 1150, "DEL-BLR": 1750, "DEL-HYD": 1270, "DEL-MAA": 1770,
        "DEL-CCU": 1320, "DEL-PNQ": 1180, "DEL-GOI": 1520,
        "BOM-BLR": 840,  "BOM-HYD": 630,  "BOM-MAA": 1030, "BOM-CCU": 1660,
        "BOM-PNQ": 120,  "BOM-GOI": 420,
        "BLR-HYD": 500,  "BLR-MAA": 290,  "BLR-CCU": 1560, "BLR-PNQ": 740, "BLR-GOI": 480,
        "HYD-MAA": 520,  "HYD-CCU": 1180, "HYD-PNQ": 500,  "HYD-GOI": 590,
        "MAA-CCU": 1360, "MAA-PNQ": 910,  "MAA-GOI": 730,
        "CCU-PNQ": 1560, "CCU-GOI": 1870, "PNQ-GOI": 390,
    ]

    static func distance(_ a: String, _ b: String) -> Double {
        distances["\(a)-\(b)"] ?? distances["\(b)-\(a)"] ?? 1000
    }

    // Demand model constants (GDD §4.3)
    static let demandK = 90.0
    static let fuelPricePerUnit = 1.0
    static let hqOverheadPerWeek = 15_000.0
    static let referenceFarePerKm = 0.11    // pre country fareLevel multiplier
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - 4. GameEngine (sim core — the single mutation owner)
// ═════════════════════════════════════════════════════════════════════════

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

    // ── Init / new game ──────────────────────────────────────────────────

    init(state: GameState) { self.state = state }

    static func newGame(airlineName: String, country: Country, seed: UInt64 = .random(in: 0...UInt64.max)) -> GameEngine {
        let profile = Balance.countryProfiles[country]!
        var staff: [StaffRole: StaffPool] = [:]
        for role in StaffRole.allCases {
            staff[role] = StaffPool(role: role, headcount: role == .hq ? 3 : 0,
                                    weeklyWage: role.marketWage * profile.laborCost,
                                    happiness: 70, skill: 2.0)
        }
        let state = GameState(
            seedRNG: SeededRandomNumberGenerator(seed: seed),
            date: GameDate(week: 1, year: 1),
            country: country,
            airlineName: airlineName,
            cash: profile.startingTrustFund + profile.startingSavings,
            trustFundActive: true,
            trustFundDeadline: GameDate(week: 52, year: 3),
            consecutiveProfitableQuarters: 0,
            reputation: 3.0,
            cities: Balance.indiaCities,          // MVP: India city set for all, swap per-country later
            fleet: [], routes: [], staff: staff, loans: [],
            pendingEvent: nil, reports: [], netWorthHistory: []
        )
        return GameEngine(state: state)
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
        guard speed != .paused, state.pendingEvent == nil else { return }
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
                                  overheadCost: Balance.hqOverheadPerWeek)

        // 1. MAINTENANCE COUNTDOWN — planes return to service.
        for i in state.fleet.indices where state.fleet[i].groundedWeeksRemaining > 0 {
            state.fleet[i].groundedWeeksRemaining -= 1
            if state.fleet[i].groundedWeeksRemaining == 0 {
                state.fleet[i].status = state.fleet[i].assignedRouteID == nil ? .idle : .assigned
            }
        }

        // 2. OPERATE ROUTES — demand, revenue, fuel, wear.
        for r in state.routes.indices {
            let route = state.routes[r]
            guard route.weeklyFrequency > 0 else { continue }
            let activePlanes = state.fleet.filter {
                route.assignedAircraftIDs.contains($0.id) && $0.groundedWeeksRemaining == 0
            }
            guard !activePlanes.isEmpty else {
                state.routes[r].lastLoadFactor = 0
                state.routes[r].lastWeeklyProfit = 0
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

            // Costs: fuel scales with seats flown (empty seats still burn fuel).
            var fuel = 0.0
            for plane in activePlanes {
                let spec = Balance.specs[plane.type]!
                fuel += Double(plane.seats(spec: spec)) * route.distanceKm
                     * spec.fuelBurnPerSeatKm * Double(route.weeklyFrequency) * 2
                     * Balance.fuelPricePerUnit * profile.fuelCost
            }

            report.revenue += revenue
            report.fuelCost += fuel
            state.routes[r].lastLoadFactor = loadFactor
            state.routes[r].lastWeeklyProfit = revenue - fuel   // route-level, pre-overhead

            // Wear accumulates with flight hours; worse condition wears faster.
            for plane in activePlanes {
                if let idx = state.fleet.firstIndex(where: { $0.id == plane.id }) {
                    let spec = Balance.specs[plane.type]!
                    let hours = route.distanceKm / spec.cruiseKmh * Double(route.weeklyFrequency) * 2
                    state.fleet[idx].wear = min(100, state.fleet[idx].wear
                        + hours * 0.25 * (1.5 - state.fleet[idx].condition / 200))
                }
            }

            // Route satisfaction drifts toward its drivers (GDD §4.5).
            let crewSkill = state.staff[.cabinCrew]?.skill ?? 1
            let fairness = max(0, min(1, 1.4 - priceRatio * 0.6))
            let target = (avgComfort * 0.4 + (crewSkill / 5.0) * 0.3 + fairness * 0.3) * 100
            state.routes[r].satisfaction += (target - route.satisfaction) * 0.15
        }

        // 3. WAGES + staff happiness drift.
        for role in StaffRole.allCases {
            guard var pool = state.staff[role] else { continue }
            report.wageCost += Double(pool.headcount) * pool.weeklyWage
            let marketRate = role.marketWage * profile.laborCost
            let payFactor = pool.weeklyWage / max(marketRate, 1)   // >1 = generous
            let target = min(100, max(0, 50 + (payFactor - 1) * 120))
            pool.happiness += (target - pool.happiness) * 0.08
            // Skill creeps up slowly with tenure.
            pool.skill = min(5, pool.skill + 0.005)
            state.staff[role] = pool
        }

        // 4. MAINTENANCE base costs (grounded or not, planes cost money).
        for plane in state.fleet where plane.status != .onOrder {
            let spec = Balance.specs[plane.type]!
            report.maintenanceCost += spec.baseMaintPerWeek
                * (1 + plane.wear / 200) * (2 - plane.condition / 100)
        }

        // 5. LOANS.
        for i in state.loans.indices {
            let interest = state.loans[i].remaining * state.loans[i].weeklyInterestRate
            let payment = min(state.loans[i].weeklyPayment, state.loans[i].remaining + interest)
            report.loanCost += payment
            state.loans[i].remaining = max(0, state.loans[i].remaining + interest - payment)
        }
        state.loans.removeAll { $0.remaining <= 0.01 }

        // 6. SETTLE cash and reputation.
        state.cash += report.profit
        let paxWeightedSat = state.routes.isEmpty ? 60.0
            : state.routes.map(\.satisfaction).reduce(0, +) / Double(state.routes.count)
        let repTarget = 1 + (paxWeightedSat / 100) * 4
        state.reputation += (repTarget - state.reputation) * 0.06   // 8-week-ish smoothing

        // 7. EVENTS — simple placeholder roll; grow into a weighted deck.
        maybeFireEvent()

        // 8. BOOKKEEPING — reports, quarters, date.
        state.reports.append(report)
        if state.reports.count > 52 { state.reports.removeFirst() }
        state.netWorthHistory.append(netWorth)
        if state.netWorthHistory.count > 260 { state.netWorthHistory.removeFirst() }

        if state.date.week % 13 == 0 { closeQuarter() }
        state.date.advance()
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
            // TODO: fire the "Aunt withdraws the fund" story event here.
        }
    }

    private func maybeFireEvent() {
        // Placeholder: ~10% weekly chance of a fuel spike card after week 8.
        guard state.date.totalWeeks > 8, state.pendingEvent == nil else { return }
        if Double.random(in: 0...1, using: &state.seedRNG) < 0.10 {
            state.pendingEvent = GameEvent(
                id: UUID(),
                title: "Fuel Price Spike",
                body: "Global oil prices jumped overnight. Analysts expect elevated prices for several weeks.",
                options: [
                    EventOption(label: "Hedge fuel now (−$40,000)", cashDelta: -40_000),
                    EventOption(label: "Ride it out", cashDelta: 0, satisfactionDelta: -2),
                ],
                firedOn: state.date
            )
        }
    }

    // ── Player actions (the ONLY external mutation points) ──────────────

    func resolveEvent(option: EventOption) {
        guard state.pendingEvent != nil else { return }
        state.cash += option.cashDelta
        for role in StaffRole.allCases {
            state.staff[role]?.happiness = max(0, min(100,
                (state.staff[role]?.happiness ?? 50) + option.happinessDelta))
        }
        for i in state.routes.indices {
            state.routes[i].satisfaction = max(0, min(100,
                state.routes[i].satisfaction + option.satisfactionDelta))
        }
        state.pendingEvent = nil
        save()
    }

    @discardableResult
    func buyAircraft(type: AircraftType, nickname: String) -> Bool {
        let spec = Balance.specs[type]!
        guard state.cash >= spec.purchasePrice else { return false }
        state.cash -= spec.purchasePrice
        state.fleet.append(Aircraft(id: UUID(), type: type, nickname: nickname,
            status: .idle, comfortConfig: 0.3, wear: 0, condition: 100,
            ageYears: 0, assignedRouteID: nil, groundedWeeksRemaining: 0))
        save()
        return true
    }

    @discardableResult
    func openRoute(from originID: String, to destID: String, fare: Double, frequency: Int) -> Route? {
        guard originID != destID,
              !state.routes.contains(where: {
                  ($0.originID == originID && $0.destinationID == destID) ||
                  ($0.originID == destID && $0.destinationID == originID) })
        else { return nil }
        let route = Route(id: UUID(), originID: originID, destinationID: destID,
                          distanceKm: Balance.distance(originID, destID),
                          weeklyFrequency: frequency, fare: fare,
                          assignedAircraftIDs: [], satisfaction: 60,
                          lastLoadFactor: 0, lastWeeklyProfit: 0)
        state.routes.append(route)
        save()
        return route
    }

    func assign(aircraftID: UUID, to routeID: UUID) {
        guard let a = state.fleet.firstIndex(where: { $0.id == aircraftID }),
              let r = state.routes.firstIndex(where: { $0.id == routeID }) else { return }
        // Unassign from any previous route first.
        for i in state.routes.indices {
            state.routes[i].assignedAircraftIDs.removeAll { $0 == aircraftID }
        }
        // Range gate.
        let spec = Balance.specs[state.fleet[a].type]!
        guard spec.rangeKm >= state.routes[r].distanceKm else { return }
        state.routes[r].assignedAircraftIDs.append(aircraftID)
        state.fleet[a].assignedRouteID = routeID
        state.fleet[a].status = .assigned
        save()
    }

    func orderCheck(aircraftID: UUID, heavy: Bool) {
        guard let i = state.fleet.firstIndex(where: { $0.id == aircraftID }) else { return }
        let cost = heavy ? 250_000.0 : 30_000.0
        guard state.cash >= cost else { return }
        state.cash -= cost
        state.fleet[i].status = .inMaintenance
        state.fleet[i].groundedWeeksRemaining = heavy ? 2 : 1
        state.fleet[i].wear = heavy ? 0 : max(0, state.fleet[i].wear - 25)
        if heavy { state.fleet[i].condition = min(100, state.fleet[i].condition + 10) }
        save()
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
        state.routes[r].weeklyFrequency = max(0, min(28, frequency)); save()
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
        let fleetValue = state.fleet.reduce(0.0) {
            $0 + Balance.specs[$1.type]!.purchasePrice
               * ($1.condition / 100) * pow(0.94, $1.ageYears)
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

// ═════════════════════════════════════════════════════════════════════════
// MARK: - 5. App entry + UI shell (SwiftUI — dumb renderers only)
// ═════════════════════════════════════════════════════════════════════════
// NOTE: delete the @main struct Xcode generated for you (in <YourApp>App.swift)
// or move this @main there — a target can only have one @main.

@main
struct SkyTycoonApp: App {
    @State private var engine: GameEngine = GameEngine.load()
        ?? GameEngine.newGame(airlineName: "Aunt Air", country: .india)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .onAppear { engine.startClock() }
        }
    }
}

struct RootView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Dashboard", systemImage: "gauge") }
            FleetView().tabItem { Label("Fleet", systemImage: "airplane") }
            RoutesView().tabItem { Label("Routes", systemImage: "map") }
            PeopleView().tabItem { Label("People", systemImage: "person.3") }
            MoneyView().tabItem { Label("Money", systemImage: "banknote") }
        }
        .sheet(item: Binding(
            get: { engine.state.pendingEvent },
            set: { _ in }   // dismissal only via choosing an option
        )) { event in
            EventCardView(event: event).interactiveDismissDisabled()
        }
    }
}

// ── Dashboard ─────────────────────────────────────────────────────────────

struct DashboardView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date", value: engine.state.date.description)
                    LabeledContent("Cash", value: engine.state.cash.money)
                    LabeledContent("Net worth", value: engine.netWorth.money)
                    LabeledContent("Reputation",
                        value: String(format: "%.1f ★", engine.state.reputation))
                    if engine.state.trustFundActive {
                        LabeledContent("Trust fund deadline",
                            value: engine.state.trustFundDeadline.description)
                        LabeledContent("Profitable quarters",
                            value: "\(engine.state.consecutiveProfitableQuarters)/4")
                    }
                }
                if let report = engine.latestReport {
                    Section("Last week") {
                        LabeledContent("Revenue", value: report.revenue.money)
                        LabeledContent("Profit", value: report.profit.money)
                            .foregroundStyle(report.profit >= 0 ? .green : .red)
                    }
                }
                Section("Simulation speed") {
                    Picker("Speed", selection: Binding(
                        get: { engine.speed },
                        set: { engine.speed = $0 })) {
                        ForEach(GameEngine.SimSpeed.allCases, id: \.self) {
                            Text($0.label).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(engine.state.airlineName)
        }
    }
}

// ── Fleet ────────────────────────────────────────────────────────────────

struct FleetView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        NavigationStack {
            List {
                ForEach(engine.state.fleet) { plane in
                    let spec = Balance.specs[plane.type]!
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(plane.nickname) · \(spec.displayName)").font(.headline)
                        Text("Status: \(plane.status.rawValue) · Wear \(Int(plane.wear)) · Condition \(Int(plane.condition))")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Line check") { engine.orderCheck(aircraftID: plane.id, heavy: false) }
                            Button("Heavy check") { engine.orderCheck(aircraftID: plane.id, heavy: true) }
                        }
                        .buttonStyle(.bordered).font(.caption)
                        .disabled(plane.groundedWeeksRemaining > 0)
                    }
                }
                Section("Showroom") {
                    ForEach(AircraftType.allCases) { type in
                        let spec = Balance.specs[type]!
                        Button {
                            engine.buyAircraft(type: type,
                                nickname: "VT-\(String(UUID().uuidString.prefix(3)))")
                        } label: {
                            LabeledContent(spec.displayName, value: spec.purchasePrice.money)
                        }
                        .disabled(engine.state.cash < spec.purchasePrice)
                    }
                }
            }
            .navigationTitle("Fleet")
        }
    }
}

// ── Routes ───────────────────────────────────────────────────────────────

struct RoutesView: View {
    @Environment(GameEngine.self) private var engine
    @State private var origin = "DEL"
    @State private var destination = "BOM"

    var body: some View {
        NavigationStack {
            List {
                ForEach(engine.state.routes) { route in
                    NavigationLink {
                        RouteDetailView(routeID: route.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("\(route.originID) ⇄ \(route.destinationID)").font(.headline)
                            Text("LF \(Int(route.lastLoadFactor * 100))% · Sat \(Int(route.satisfaction)) · \(route.lastWeeklyProfit.money)/wk")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Open new route") {
                    Picker("From", selection: $origin) {
                        ForEach(engine.state.cities) { Text($0.name).tag($0.id) }
                    }
                    Picker("To", selection: $destination) {
                        ForEach(engine.state.cities) { Text($0.name).tag($0.id) }
                    }
                    Button("Open route") {
                        let dist = Balance.distance(origin, destination)
                        _ = engine.openRoute(from: origin, to: destination,
                            fare: dist * 0.09, frequency: 7)
                    }
                    .disabled(origin == destination)
                }
            }
            .navigationTitle("Routes")
        }
    }
}

struct RouteDetailView: View {
    @Environment(GameEngine.self) private var engine
    let routeID: UUID

    var body: some View {
        if let route = engine.state.routes.first(where: { $0.id == routeID }) {
            List {
                Section("Economics") {
                    LabeledContent("Distance", value: "\(Int(route.distanceKm)) km")
                    LabeledContent("Load factor", value: "\(Int(route.lastLoadFactor * 100))%")
                    Stepper("Fare: \(route.fare.money)",
                        value: Binding(get: { route.fare },
                                       set: { engine.setFare(routeID: routeID, fare: $0) }),
                        step: 5)
                    Stepper("Flights/week: \(route.weeklyFrequency)",
                        value: Binding(get: { Double(route.weeklyFrequency) },
                                       set: { engine.setFrequency(routeID: routeID, frequency: Int($0)) }),
                        in: 0...28, step: 1)
                }
                Section("Assign aircraft") {
                    ForEach(engine.state.fleet) { plane in
                        let assigned = route.assignedAircraftIDs.contains(plane.id)
                        Button {
                            engine.assign(aircraftID: plane.id, to: routeID)
                        } label: {
                            HStack {
                                Text(plane.nickname)
                                Spacer()
                                if assigned { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(route.originID) ⇄ \(route.destinationID)")
        }
    }
}

// ── People ───────────────────────────────────────────────────────────────

struct PeopleView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        NavigationStack {
            List {
                ForEach(StaffRole.allCases) { role in
                    if let pool = engine.state.staff[role] {
                        Section(role.displayName) {
                            Stepper("Headcount: \(pool.headcount)",
                                value: Binding(get: { Double(pool.headcount) },
                                    set: { engine.setHeadcount(role: role, count: Int($0)) }),
                                in: 0...500, step: 1)
                            Stepper("Wage: \(pool.weeklyWage.money)/wk",
                                value: Binding(get: { pool.weeklyWage },
                                    set: { engine.setWage(role: role, wage: $0) }),
                                step: 50)
                            LabeledContent("Happiness", value: "\(Int(pool.happiness))/100")
                            LabeledContent("Skill",
                                value: String(format: "%.1f ★", pool.skill))
                        }
                    }
                }
            }
            .navigationTitle("People")
        }
    }
}

// ── Money ────────────────────────────────────────────────────────────────

struct MoneyView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        NavigationStack {
            List {
                if let r = engine.latestReport {
                    Section("Last week P&L") {
                        LabeledContent("Revenue", value: r.revenue.money)
                        LabeledContent("Fuel", value: (-r.fuelCost).money)
                        LabeledContent("Wages", value: (-r.wageCost).money)
                        LabeledContent("Maintenance", value: (-r.maintenanceCost).money)
                        LabeledContent("Loan payments", value: (-r.loanCost).money)
                        LabeledContent("Overhead", value: (-r.overheadCost).money)
                        LabeledContent("Profit", value: r.profit.money)
                            .fontWeight(.bold)
                            .foregroundStyle(r.profit >= 0 ? .green : .red)
                    }
                }
                Section("Loans") {
                    ForEach(engine.state.loans) { loan in
                        LabeledContent("Remaining", value: loan.remaining.money)
                    }
                    Button("Take $1M loan") { engine.takeLoan(amount: 1_000_000) }
                    Button("Take $5M loan") { engine.takeLoan(amount: 5_000_000) }
                }
            }
            .navigationTitle("Money")
        }
    }
}

// ── Event card ───────────────────────────────────────────────────────────

struct EventCardView: View {
    @Environment(GameEngine.self) private var engine
    let event: GameEvent

    var body: some View {
        VStack(spacing: 20) {
            Text(event.title).font(.title2.bold())
            Text(event.body).multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            ForEach(event.options) { option in
                Button {
                    engine.resolveEvent(option: option)
                } label: {
                    Text(option.label).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}

// ── Helpers ──────────────────────────────────────────────────────────────

extension Double {
    /// "$1.2M" style compact money formatting.
    var money: String {
        let sign = self < 0 ? "-" : ""
        let v = abs(self)
        switch v {
        case 1_000_000_000...: return "\(sign)$\(String(format: "%.2f", v / 1_000_000_000))B"
        case 1_000_000...:     return "\(sign)$\(String(format: "%.2f", v / 1_000_000))M"
        case 1_000...:         return "\(sign)$\(String(format: "%.1f", v / 1_000))K"
        default:               return "\(sign)$\(String(format: "%.0f", v))"
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - 6. Where to take this next
// ═════════════════════════════════════════════════════════════════════════
//
//  SUGGESTED FOLDER SPLIT once this runs (keep sim and UI separate forever):
//
//    SkyTycoon/
//    ├── Simulation/          ← pure Swift, no SwiftUI imports, unit-tested
//    │   ├── Models.swift         (section 2)
//    │   ├── Balance.swift        (section 3)
//    │   ├── GameEngine.swift     (section 4)
//    │   └── SeededRNG.swift      (section 1)
//    ├── UI/
//    │   ├── DashboardView.swift, FleetView.swift, ...
//    │   └── Components/          (stat cards, sparklines, event cards)
//    └── SkyTycoonApp.swift
//
//  IMMEDIATE NEXT STEPS, in order:
//  1. Run it. Buy a plane, open DEL–BOM, assign, set speed 4x, watch money move.
//  2. Add a unit test target: assert that two engines with the same seed
//     produce identical cash after 100 advanceWeek() calls. This test is
//     your determinism guarantee — keep it green forever.
//  3. Crew-hours: routes should consume pilot/cabin capacity and understaffing
//     should create delays (satisfaction hit) + overtime cost.
//  4. Event deck: replace maybeFireEvent() with a weighted card deck struct
//     (cards as data, weights shifted by game state per GDD §4.7).
//  5. New-game flow: replace the hardcoded newGame with a country-select
//     screen; move city sets per country into Balance.
//  6. The seat-config editor screen — your hero UI moment.
//
