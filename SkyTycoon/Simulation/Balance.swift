//
//  Balance.swift
//  SkyTycoon — Simulation core (pure Swift, no SwiftUI)
//
//  Balance as data. Aircraft specs, city lists, and tuning constants live
//  here — one place to tweak, and trivially movable to bundled JSON later
//  so balancing never requires touching sim code.
//

import Foundation

enum Balance {
    // ── Everything about an airframe follows from its WINDOW COUNT and
    // ENGINE KIND — exactly the two facts in each asset's name
    // (design pillar 4: count the windows in the photo, read the engine,
    // and you can derive the plane).
    //
    //   seats  = windows × (2 + 0.04 × windows)   more windows → wider body
    //   range  = 900 + 110 × windows              km
    //   price  = $150k × seats × (1 + seats/80) × engine factor
    //   burn   = engine base − seats-based efficiency gain
    //   maint  = ($2k + $250 × seat) × engine factor / week
    //   cabin  = none under 20 seats, then 1 per 50 seats
    //   runway = jets need class 3 (metros); windows ≥ 24 need class 2
    //   "II"   = newer variant of the same airframe: 4% less burn, 6% dearer
    static func makeSpec(windows: Int, engine: EngineKind, variantII: Bool = false,
                         maker: String? = nil) -> AircraftSpec {
        let seats = Int((Double(windows) * (2.0 + 0.04 * Double(windows))).rounded())

        let cruise: Double
        let burnBase: Double, burnPerSeat: Double
        let priceFactor: Double, maintFactor: Double
        let rangeFactor: Double
        let primarySeller: String, abreast: Int
        switch engine {
        case .turboprop: cruise = 500; burnBase = 0.021; burnPerSeat = 0.00004
                         priceFactor = 1.00; maintFactor = 1.00; rangeFactor = 1.0
                         primarySeller = "Vayu Aeroworks"; abreast = 2
        case .propeller: cruise = 480; burnBase = 0.019; burnPerSeat = 0.00004
                         priceFactor = 0.85; maintFactor = 1.15; rangeFactor = 1.0
                         primarySeller = "Northline Regional"; abreast = 4
        case .jet:       cruise = 830; burnBase = 0.026; burnPerSeat = 0.00006
                         priceFactor = 1.30; maintFactor = 1.10; rangeFactor = 1.0
                         primarySeller = "Meridian Jets"; abreast = 6
        case .widebody:  cruise = 900; burnBase = 0.024; burnPerSeat = 0.00003
                         priceFactor = 1.60; maintFactor = 1.40; rangeFactor = 1.6
                         primarySeller = "Meridian Jets"; abreast = 9
        }
        // Competing makers (the Airbus-vs-Boeing dynamic): "II" airframes
        // and wedge sizes come from rivals, so loyalty discounts pull
        // against each other — commit to one lineup, or split the fleet
        // and forfeit the discounts.
        let seller = maker ?? (variantII ? "Kestrel Aeronautics" : primarySeller)

        let price = 150_000.0 * Double(seats) * (1.0 + Double(seats) / 80.0) * priceFactor
        let burn = burnBase - Double(seats) * burnPerSeat
        return AircraftSpec(
            displayName: "\(windows) \(engine.label)\(variantII ? " II" : "")",
            windowCount: windows,
            engine: engine,
            seller: seller,
            seatsAbreast: abreast,
            maxSeats: seats,
            rangeKm: (900 + 110 * Double(windows)) * rangeFactor,
            cruiseKmh: cruise,
            purchasePrice: price * (variantII ? 1.06 : 1.0),
            fuelBurnPerSeatKm: burn * (variantII ? 0.96 : 1.0),
            pilotsPerFlight: 2,
            cabinCrewPerFlight: seats < 20 ? 0 : max(1, Int((Double(seats) / 50.0).rounded(.up))),
            baseMaintPerWeek: (2_000 + 250 * Double(seats)) * maintFactor,
            // Runway needs scale with SIZE: heavies need the metros,
            // mid-size (regional jets included) need class 2, feeders
            // land anywhere.
            requiredRunwayClass: (engine == .widebody || windows >= 45) ? 3
                               : (windows >= 14 ? 2 : 1))
    }

    static let specs: [AircraftType: AircraftSpec] = [
        .turboprop5: makeSpec(windows: 5, engine: .turboprop),
        .turboprop8: makeSpec(windows: 8, engine: .turboprop),
        .turboprop10: makeSpec(windows: 10, engine: .turboprop),
        .turboprop12: makeSpec(windows: 12, engine: .turboprop),
        .propeller24: makeSpec(windows: 24, engine: .propeller),
        .propeller24II: makeSpec(windows: 24, engine: .propeller, variantII: true),
        .propeller28: makeSpec(windows: 28, engine: .propeller),
        .propeller28II: makeSpec(windows: 28, engine: .propeller, variantII: true),
        .propeller30: makeSpec(windows: 30, engine: .propeller),
        .propeller30II: makeSpec(windows: 30, engine: .propeller, variantII: true),
        .propeller32: makeSpec(windows: 32, engine: .propeller),
        .propeller35: makeSpec(windows: 35, engine: .propeller),
        // Regional jets: Meridian's ladder (18/24/32/42) with Kestrel's
        // wedge sizes (26/29) competing between the rungs.
        .jet18: makeSpec(windows: 18, engine: .jet),
        .jet24: makeSpec(windows: 24, engine: .jet),
        .jet26: makeSpec(windows: 26, engine: .jet, maker: "Kestrel Aeronautics"),
        .jet29: makeSpec(windows: 29, engine: .jet, maker: "Kestrel Aeronautics"),
        .jet32: makeSpec(windows: 32, engine: .jet),
        .jet42: makeSpec(windows: 42, engine: .jet),
        .jet50: makeSpec(windows: 50, engine: .jet),
        .jet60: makeSpec(windows: 60, engine: .jet),
        .jet60II: makeSpec(windows: 60, engine: .jet, variantII: true),
        // Widebodies: the international era's heavies.
        .widebody55: makeSpec(windows: 55, engine: .widebody),
        .widebody65: makeSpec(windows: 65, engine: .widebody),
        .widebody75: makeSpec(windows: 75, engine: .widebody),
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
    /// Coordinates are the real airports (IGI, CSMIA, Kempegowda, …).
    static let indiaCities: [City] = [
        .init(id: "DEL", name: "Delhi",     population: 32.0, businessIndex: 0.35, runwayClass: 3, weeklySlots: 60, latitude: 28.556, longitude: 77.100),
        .init(id: "BOM", name: "Mumbai",    population: 24.0, businessIndex: 0.45, runwayClass: 3, weeklySlots: 50, latitude: 19.089, longitude: 72.868),
        .init(id: "BLR", name: "Bangalore", population: 13.0, businessIndex: 0.45, runwayClass: 3, weeklySlots: 55, latitude: 13.199, longitude: 77.706),
        .init(id: "HYD", name: "Hyderabad", population: 10.5, businessIndex: 0.35, runwayClass: 3, weeklySlots: 55, latitude: 17.240, longitude: 78.429),
        .init(id: "MAA", name: "Chennai",   population: 11.5, businessIndex: 0.30, runwayClass: 3, weeklySlots: 50, latitude: 12.990, longitude: 80.169),
        .init(id: "CCU", name: "Kolkata",   population: 15.0, businessIndex: 0.25, runwayClass: 2, weeklySlots: 45, latitude: 22.655, longitude: 88.447),
        .init(id: "PNQ", name: "Pune",      population: 7.5,  businessIndex: 0.30, runwayClass: 2, weeklySlots: 30, latitude: 18.582, longitude: 73.920),
        .init(id: "GOI", name: "Goa",       population: 1.6,  businessIndex: 0.08, runwayClass: 2, weeklySlots: 30, latitude: 15.381, longitude: 73.839),
        // Expansion set (2026-07-18): tier-2 metros and regional fields —
        // distances for these come from the haversine fallback below.
        .init(id: "AMD", name: "Ahmedabad", population: 8.6,  businessIndex: 0.30, runwayClass: 3, weeklySlots: 40, latitude: 23.077, longitude: 72.634),
        .init(id: "JAI", name: "Jaipur",    population: 4.1,  businessIndex: 0.22, runwayClass: 2, weeklySlots: 30, latitude: 26.824, longitude: 75.812),
        .init(id: "LKO", name: "Lucknow",   population: 3.9,  businessIndex: 0.20, runwayClass: 2, weeklySlots: 30, latitude: 26.760, longitude: 80.889),
        .init(id: "COK", name: "Kochi",     population: 3.6,  businessIndex: 0.22, runwayClass: 2, weeklySlots: 35, latitude: 10.152, longitude: 76.402),
        .init(id: "NAG", name: "Nagpur",    population: 2.9,  businessIndex: 0.20, runwayClass: 2, weeklySlots: 25, latitude: 21.092, longitude: 79.047),
        .init(id: "TRV", name: "Trivandrum", population: 2.5, businessIndex: 0.18, runwayClass: 2, weeklySlots: 25, latitude: 8.482,  longitude: 76.920),
        .init(id: "GAU", name: "Guwahati",  population: 1.2,  businessIndex: 0.15, runwayClass: 2, weeklySlots: 25, latitude: 26.106, longitude: 91.586),
        .init(id: "BBI", name: "Bhubaneswar", population: 1.2, businessIndex: 0.18, runwayClass: 2, weeklySlots: 25, latitude: 20.244, longitude: 85.818),
        .init(id: "IXC", name: "Chandigarh", population: 1.1, businessIndex: 0.25, runwayClass: 2, weeklySlots: 20, latitude: 30.673, longitude: 76.788),
        .init(id: "SXR", name: "Srinagar",  population: 1.5,  businessIndex: 0.10, runwayClass: 1, weeklySlots: 20, latitude: 33.987, longitude: 74.774),
        .init(id: "VNS", name: "Varanasi",  population: 1.6,  businessIndex: 0.12, runwayClass: 1, weeklySlots: 20, latitude: 25.452, longitude: 82.859),
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
        if let d = distances["\(a)-\(b)"] ?? distances["\(b)-\(a)"] { return d }
        // Haversine from airport coordinates × 1.06 route factor — new
        // airports never need hand-tabled pairs. Deterministic.
        guard let ca = indiaCities.first(where: { $0.id == a }),
              let cb = indiaCities.first(where: { $0.id == b }) else { return 1000 }
        let φ1 = ca.latitude * .pi / 180, φ2 = cb.latitude * .pi / 180
        let dφ = (cb.latitude - ca.latitude) * .pi / 180
        let dλ = (cb.longitude - ca.longitude) * .pi / 180
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        let greatCircle = 6371.0 * 2 * atan2(sqrt(h), sqrt(1 - h))
        return (greatCircle * 1.06).rounded()
    }

    // Demand model constants (GDD §4.3)
    //
    // demandK calibration (first-hour viability): DEL–BOM gravity term is
    // (32×24)^0.55 / 1150^0.35 ≈ 3.27, so weekly base demand = k × 3.27
    // ≈ 1,700 at k = 520 (≈1,960 with 3.0★ brand). That fills a 30
    // Propeller (84 seats × 14 round trips × 2 directions ≈ 2,350 seats)
    // to ~84%, and caps out the smaller props — so upgrading capacity on
    // trunk routes stays the growth lever. At the original k = 90 every
    // possible opening move lost money; at 450 the trust-fund arc (four
    // P&L-positive quarters) was unreachable even for a well-run airline
    // (verified by 160-week sims). Tune further in the M8 playtest pass.
    static let demandK = 520.0
    static let fuelPricePerUnit = 1.0
    static let hqOverheadPerWeek = 15_000.0
    static let referenceFarePerKm = 0.11    // pre country fareLevel multiplier

    /// Poor condition raises fuel burn (GDD §4.1): up to +15% at condition 0.
    static func fuelConditionMultiplier(condition: Double) -> Double {
        1.0 + (100.0 - condition) / 100.0 * 0.15
    }

    // ── Crew-hours model (GDD §4.4, M2) ──────────────────────────────────

    static let weeklyHoursPerStaff = 40.0
    /// Ground time added to each leg's block hours for pilot/cabin duty.
    static let turnaroundHoursPerLeg = 0.5
    /// Ground/maintenance crew hours consumed per departure.
    static let groundHoursPerDeparture = 5.0
    /// HQ workload: a base plus per-aircraft and per-route admin.
    static let hqBaseHours = 60.0
    static let hqHoursPerAircraft = 15.0
    static let hqHoursPerRoute = 10.0
    /// Hours beyond roster capacity are paid at this multiple.
    static let overtimeMultiplier = 1.5
    /// A pool's over-roster strain is capped here (200% over = as bad as it gets).
    static let maxStrainPerPool = 1.5
    /// How much each pool's overwork drives flight delays (HQ doesn't
    /// directly delay flights; it hurts via happiness/attrition instead).
    static func strainWeight(_ role: StaffRole) -> Double {
        switch role {
        case .pilots: 0.40; case .ground: 0.35; case .cabinCrew: 0.25; case .hq: 0.0
        }
    }
    static let basePunctuality = 0.97
    static let strainDelayFactor = 0.45
    static let skillDelayFactor = 0.10
    /// Happiness-target penalty per unit of over-roster strain.
    static let workloadHappinessPenalty = 50.0
    /// Below this happiness, staff quit each week (GDD §4.4).
    static let attritionHappinessThreshold = 40.0
    /// Below this happiness, the pool is a strike risk (feeds M3 event weights).
    static let strikeRiskHappinessThreshold = 25.0
    /// Weekly attrition rate at happiness 0 (scales linearly up to the threshold).
    static let attritionMaxRatePerWeek = 0.03

    // ── Marketing (GDD §4.8, M5) ─────────────────────────────────────────

    /// Awareness gained per week from spend, with diminishing returns:
    /// gain = 8 × spend / (spend + $60k). Holding 100 costs ~$36k/week.
    static func awarenessGain(spend: Double) -> Double {
        guard spend > 0 else { return 0 }
        return 8.0 * spend / (spend + 60_000)
    }
    /// Awareness decays 3%/week without spend.
    static let awarenessDecay = 0.03
    static let marketingSpendMax = 60_000.0
    static let startingAwareness = 25.0

    /// Awareness scales the brand multiplier around a neutral point of 25
    /// (a young airline's default): −3% demand at zero awareness, +9% at
    /// full. Bounded tight so the M6 arc calibration holds.
    static func awarenessMultiplier(_ awareness: Double) -> Double {
        0.97 + 0.12 * awareness / 100.0
    }

    // ── The bank (GDD §3.2 MVP slice, M7) ────────────────────────────────

    struct LoanOffer: Identifiable {
        let id: String
        let name: String
        let amount: Double
        let weeklyRate: Double
        let weeks: Int
    }
    static let loanOffers: [LoanOffer] = [
        LoanOffer(id: "starter", name: "Starter credit", amount: 2_000_000,
                  weeklyRate: 0.0012, weeks: 156),
        LoanOffer(id: "expansion", name: "Expansion loan", amount: 8_000_000,
                  weeklyRate: 0.0015, weeks: 260),
        LoanOffer(id: "fleet", name: "Fleet facility", amount: 20_000_000,
                  weeklyRate: 0.0018, weeks: 260),
    ]
    /// Total debt may not exceed $2M + 1.2 × net worth.
    static func borrowingLimit(netWorth: Double) -> Double {
        2_000_000 + max(0, netWorth) * 1.2
    }

    // ── The objectives layer (GDD §3.1 + §6, M6) ─────────────────────────

    /// Success: the fund converts to a gift on top of what you kept.
    static let trustFundSuccessGift = 500_000.0
    static let trustFundSuccessReputationBonus = 0.25
    static let lettersKept = 16

    static func auntLetter(tone: QuarterlyLetter.Tone, quarterProfit: Double,
                           streak: Int, quartersLeft: Int) -> String {
        let profit = abs(quarterProfit)
        switch tone {
        case .proud:
            return "My dear, \(streak) profitable quarters in a row. I read the numbers twice to be sure. Your grandfather haggled over rickshaw fares his whole life; you're out here running an airline in the black. Keep the streak alive. Only \(max(0, 4 - streak)) more and the fund is yours properly."
        case .encouraging:
            return "A profit of \(profit.money) this quarter! I won't pretend I understood every line of the report you sent, but I understood the color green. Don't get cocky: one good quarter is weather, four is climate. \(quartersLeft) quarters left before my accountants get twitchy."
        case .worried:
            return "I saw the quarter's numbers: \(profit.money) in the red. I'm not angry, I'm worried. Planes on the ground don't pay for themselves, beta. Look at your fares, look at your crews, and for goodness' sake do the maintenance BEFORE things break. \(quartersLeft) quarters remain."
        case .stern:
            return "We need to speak plainly. Another loss, \(profit.money), and the streak reset to nothing. The fund was not a wedding present; it came with conditions and a deadline, and both are approaching faster than you seem to believe. Show me four consecutive profitable quarters. \(quartersLeft) remain. Do not make me write the next letter."
        case .triumphant:
            return "Four profitable quarters. FOUR. I have already called the lawyers. The fund is yours, converted to a gift, with a little extra from me because I am, despite appearances, sentimental. Your grandfather would have pretended not to cry. I will not pretend. Fly far, my dear. You've earned every kilometer."
        case .heartbroken:
            return "The deadline passed this week. You know what that means and so do I: the accountants have withdrawn what remained of the fund. I want you to hear this from me and not from them: I am not disappointed in you, I am disappointed for you. What you build from here is truly yours alone. Prove the old woman wrong. I would love nothing more."
        }
    }

    /// Layer-1 milestones: ~10 contextual nudges, small cash rewards,
    /// never blocking (GDD §6). Checked every tick, paid once.
    static let milestones: [MilestoneDef] = [
        MilestoneDef(id: "wings", title: "Field your first aircraft", reward: 15_000,
                     isComplete: { !$0.fleet.isEmpty }),
        MilestoneDef(id: "openForBusiness", title: "Open your first route", reward: 15_000,
                     isComplete: { !$0.routes.isEmpty }),
        MilestoneDef(id: "crewedUp", title: "Build a crew of 8", reward: 20_000,
                     isComplete: { state in
                         StaffRole.allCases.filter { $0 != .hq }
                             .reduce(0) { $0 + (state.staff[$1]?.headcount ?? 0) } >= 8
                     }),
        MilestoneDef(id: "inTheBlack", title: "Post a profitable week", reward: 20_000,
                     isComplete: { ($0.reports.last?.profit ?? 0) > 0 }),
        MilestoneDef(id: "networkEffect", title: "Run 3 routes at once", reward: 30_000,
                     isComplete: { $0.routes.count >= 3 }),
        MilestoneDef(id: "packedHouse", title: "Hit 80% load factor on a route", reward: 30_000,
                     isComplete: { $0.routes.contains { $0.lastLoadFactor >= 0.8 } }),
        MilestoneDef(id: "growingFleet", title: "Operate 3 aircraft", reward: 40_000,
                     isComplete: { $0.fleet.count >= 3 }),
        MilestoneDef(id: "bigWeek", title: "Bank $50K profit in one week", reward: 50_000,
                     isComplete: { ($0.reports.last?.profit ?? 0) >= 50_000 }),
        MilestoneDef(id: "wellRegarded", title: "Reach a 4.0★ reputation", reward: 60_000,
                     isComplete: { $0.reputation >= 4.0 }),
        MilestoneDef(id: "flagCarrier", title: "Connect 6 of India's cities", reward: 75_000,
                     isComplete: { state in
                         let touched = Set(state.routes.flatMap { [$0.originID, $0.destinationID] })
                         return touched.count >= 6
                     }),
    ]

    // ── The event deck (GDD §4.7, M3) ────────────────────────────────────

    /// Weekly chance that a card fires (after the opening grace weeks).
    static let eventChancePerWeek = 0.16
    static let eventGraceWeeks = 6

    /// The 12 MVP cards. Weights are shifted by game state in
    /// GameEngine.eventWeight(for:) — events feel like consequences.
    static let eventDeck: [EventCard] = [
        // ── Market ───────────────────────────────────────────────────────
        EventCard(id: "fuelSpike", category: .market,
            title: "Fuel Price Spike",
            body: "Global oil prices jumped overnight. Analysts expect elevated prices for about six weeks.",
            baseWeight: 1.0, isNegative: true, minTotalWeek: 6,
            options: [
                EventOption(label: "Hedge now (−$50,000)",
                            effects: [.cash(-50_000)]),
                EventOption(label: "Ride it out (fuel +30% for 6 wk)",
                            effects: [.fuelPrice(multiplier: 1.30, weeks: 6)]),
            ],
            isEligible: { _ in true }),
        EventCard(id: "oilGlut", category: .market,
            title: "Oil Glut",
            body: "A supply surge has fuel contracts trading cheap. Your ops chief is grinning.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 10,
            options: [
                EventOption(label: "Enjoy it (fuel −15% for 6 wk)",
                            effects: [.fuelPrice(multiplier: 0.85, weeks: 6)]),
            ],
            isEligible: { _ in true }),

        // ── Weather ──────────────────────────────────────────────────────
        EventCard(id: "cyclone", category: .weather,
            title: "Cyclone Warning",
            body: "A cyclone is tracking toward the coast. Airports in its path will be disrupted for two weeks.",
            baseWeight: 0.8, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Cancel early & refund (−$40,000, goodwill)",
                            effects: [.cash(-40_000), .satisfaction(3)]),
                EventOption(label: "Fly partial ops (demand −20% for 2 wk)",
                            effects: [.demand(multiplier: 0.80, weeks: 2), .satisfaction(-4)]),
            ],
            isEligible: { !$0.routes.isEmpty }),

        // ── Labor ────────────────────────────────────────────────────────
        EventCard(id: "cabinRaise", category: .labor,
            title: "Cabin Crew Demand a Raise",
            body: "The cabin crew association is asking for 8%. They've seen the load factors.",
            baseWeight: 0.8, isNegative: true, minTotalWeek: 10,
            options: [
                EventOption(label: "Grant the 8%",
                            effects: [.raiseWage(role: .cabinCrew, factor: 1.08),
                                      .happiness(role: .cabinCrew, delta: 12)]),
                EventOption(label: "One-time bonus instead (−$30,000)",
                            effects: [.cash(-30_000), .happiness(role: .cabinCrew, delta: 6)]),
                EventOption(label: "Refuse",
                            effects: [.happiness(role: .cabinCrew, delta: -18)]),
            ],
            isEligible: { ($0.staff[.cabinCrew]?.headcount ?? 0) > 0 }),
        EventCard(id: "strikeVote", category: .labor,
            title: "Strike Vote at the Gates",
            body: "Morale has cratered and a strike vote is underway. This is what neglect costs.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 12,
            options: [
                EventOption(label: "Concede: +6% wages across the board (−$20,000)",
                            effects: [.raiseWage(role: nil, factor: 1.06),
                                      .happiness(role: nil, delta: 20), .cash(-20_000)]),
                EventOption(label: "Hold the line (disruption, reputation hit)",
                            effects: [.happiness(role: nil, delta: -10), .satisfaction(-8),
                                      .reputation(-0.3), .demand(multiplier: 0.85, weeks: 2)]),
            ],
            isEligible: { state in
                StaffRole.allCases.contains {
                    (state.staff[$0]?.headcount ?? 0) > 0
                    && (state.staff[$0]?.happiness ?? 100) < strikeRiskHappinessThreshold
                }
            }),

        // ── Technical ────────────────────────────────────────────────────
        EventCard(id: "faultFound", category: .technical,
            title: "Engine Fault Found",
            body: "Maintenance flagged a compressor issue on one airframe during a routine inspection.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Fix now (−$80,000, plane down 1 wk)",
                            effects: [.cash(-80_000), .groundRandomAircraft(weeks: 1)]),
                EventOption(label: "Defer it (wear +25 on that airframe)",
                            effects: [.wearRandomAircraft(25), .satisfaction(-2)]),
            ],
            isEligible: { state in
                state.fleet.contains { $0.status != .onOrder }
            }),
        EventCard(id: "surpriseGrounding", category: .technical,
            title: "Unscheduled Grounding",
            body: "A neglected airframe failed its pre-flight checks outright. It's out of service, no options this time.",
            baseWeight: 0.10, isNegative: true, minTotalWeek: 10,
            options: [
                EventOption(label: "Get it to the hangar (−$40,000, down 2 wk)",
                            effects: [.cash(-40_000), .groundRandomAircraft(weeks: 2),
                                      .satisfaction(-5)]),
            ],
            isEligible: { state in
                state.fleet.contains { $0.status != .onOrder && $0.wear > 60 }
            }),

        // ── Opportunity ──────────────────────────────────────────────────
        EventCard(id: "vipCharter", category: .opportunity,
            title: "VIP Charter Offer",
            body: "A film production wants a plane for a weekend shoot: triple the usual revenue, but it pulls capacity.",
            baseWeight: 0.7, isNegative: false, minTotalWeek: 10,
            options: [
                EventOption(label: "Accept (+$120,000, demand −8% for 1 wk)",
                            effects: [.cash(120_000), .demand(multiplier: 0.92, weeks: 1)]),
                EventOption(label: "Decline politely",
                            effects: []),
            ],
            isEligible: { state in
                state.fleet.contains { $0.status != .onOrder }
            }),
        EventCard(id: "festivalRush", category: .opportunity,
            title: "Festival Rush",
            body: "A festival season surge is filling planes across the network for the next three weeks.",
            baseWeight: 0.8, isNegative: false, minTotalWeek: 8,
            options: [
                EventOption(label: "All hands on deck (demand +25% for 3 wk)",
                            effects: [.demand(multiplier: 1.25, weeks: 3)]),
            ],
            isEligible: { !$0.routes.isEmpty }),

        // ── Regulatory ───────────────────────────────────────────────────
        EventCard(id: "safetyAudit", category: .regulatory,
            title: "Safety Audit Announced",
            body: "The regulator will audit your operation in four weeks. Preparation costs money; failure costs trust.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 16,
            options: [
                EventOption(label: "Invest in preparation (−$60,000)",
                            effects: [.cash(-60_000), .reputation(0.1)]),
                EventOption(label: "Wing it",
                            effects: [.satisfaction(-3), .reputation(-0.15)]),
            ],
            isEligible: { _ in true }),

        // ── PR ───────────────────────────────────────────────────────────
        EventCard(id: "viralCrew", category: .pr,
            title: "Crew Goes Viral",
            body: "A video of your crew helping a stranded family is everywhere. The internet loves you, for now.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 8,
            options: [
                EventOption(label: "Amplify with a campaign (−$25,000)",
                            effects: [.cash(-25_000), .reputation(0.35)]),
                EventOption(label: "A modest thank-you post",
                            effects: [.reputation(0.15)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "baggageMeltdown", category: .pr,
            title: "Baggage Meltdown",
            body: "A sorting failure sent a day's worth of bags to the wrong cities. Passengers are posting photos.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Compensate everyone (−$35,000)",
                            effects: [.cash(-35_000), .satisfaction(2)]),
                EventOption(label: "Quietly fix it",
                            effects: [.satisfaction(-6), .reputation(-0.2)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
    ]

    // ── Recruitment (GDD §4.4 as amended) ────────────────────────────────

    /// Cost to run a job ad, and how long it stays up.
    static let jobAdFee = 2_000.0
    static let jobPostingWeeks = 4
    /// Cap on waiting applicants per role — beyond this, new ones don't apply.
    static let maxApplicantsPerRole = 6
    /// Applicants wait 3–5 weeks before taking another job.
    static let applicantPatienceWeeksMin = 3
    static let applicantPatienceWeeksMax = 5
    /// Offer ≥ 97% of asking is a yes on the spot.
    static let negotiationAcceptRatio = 0.97
    /// Irritation gained per unit of lowball: (1 − offer/asking) × this.
    static let negotiationIrritationFactor = 120.0
    /// Below 75% of asking, a stubborn applicant may walk immediately.
    static let negotiationInsultRatio = 0.75

    /// Asking wage: market rate scaled by skill plus personal noise.
    static func askingWage(marketRate: Double, skill: Double, noise: Double) -> Double {
        marketRate * (0.70 + 0.16 * skill + noise)   // noise ±0.08
    }

    static let applicantFirstNames = [
        "Arjun", "Priya", "Rohan", "Ananya", "Vikram", "Meera", "Kabir",
        "Isha", "Dev", "Naina", "Farhan", "Zara", "Aditya", "Sana",
        "Rahul", "Divya", "Imran", "Lakshmi", "Nikhil", "Tara",
    ]
    static let applicantLastNames = [
        "Sharma", "Patel", "Singh", "Nair", "Khan", "Iyer", "Das",
        "Mehta", "Reddy", "Kapoor", "Bose", "Menon", "Joshi", "Rao",
    ]

    // ── Fleet acquisition (GDD §4.1, M1) ─────────────────────────────────

    /// Fixed delivery wait per archetype for factory-new orders:
    /// 4 weeks + half a week per window (bigger plane, longer backlog),
    /// capped at the GDD's 40-week maximum.
    static let deliveryWeeks: [AircraftType: Int] = Dictionary(
        uniqueKeysWithValues: AircraftType.allCases.map {
            ($0, min(40, 4 + specs[$0]!.windowCount / 2))
        })

    /// Manufacturer loyalty (GDD §4.1): every factory-new order from the
    /// same seller earns 3% off the next one, capped at 12%.
    static let loyaltyDiscountPerOrder = 0.03
    static let loyaltyDiscountCap = 0.12

    /// A cabin refit grounds the aircraft this long (GDD §4.2).
    static let cabinRefitWeeks = 1

    /// Weekly lease payment as a fraction of new price. The GDD's 0.25%
    /// starting point priced a turboprop lease above its best-case route
    /// margin — a leased first plane could NEVER break even, contradicting
    /// "the safest first plane for a cautious player" (§4.1). 0.18% makes a
    /// well-run leased turboprop marginally profitable: viable, but clearly
    /// worse than owning — the intended cash-flow-vs-equity tradeoff.
    static let leaseRatePerWeek = 0.0018
    /// Returning a leased aircraft costs this many weeks of payments.
    static let leaseTerminationWeeks = 4.0

    /// Used market tuning: listing count, refresh cadence, condition range.
    static let usedMarketMinListings = 3
    static let usedMarketMaxListings = 5
    static let usedMarketRefreshWeeksMin = 3
    static let usedMarketRefreshWeeksMax = 4
    static let usedConditionRange = 40.0...90.0
    static let usedAgeRange = 3.0...15.0

    /// Used price = new price × condition/age discount, clamped to the
    /// GDD's 30–60% of new band.
    static func usedPrice(type: AircraftType, ageYears: Double, condition: Double) -> Double {
        let spec = specs[type]!
        let raw = (condition / 100.0) * pow(0.94, ageYears)
        return spec.purchasePrice * min(0.60, max(0.30, raw))
    }

    /// Resale value of an owned airframe (also the fleet-value formula
    /// used by netWorth — the two must agree so selling is never an exploit).
    static func resaleValue(type: AircraftType, ageYears: Double, condition: Double) -> Double {
        specs[type]!.purchasePrice * (condition / 100.0) * pow(0.94, ageYears)
    }
}
