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
                         maker: String? = nil, name: String? = nil) -> AircraftSpec {
        let seats = Int((Double(windows) * (2.0 + 0.04 * Double(windows))).rounded())

        let cruise: Double
        let burnBase: Double, burnPerSeat: Double
        let priceFactor: Double, maintFactor: Double
        let rangeFactor: Double
        let primarySeller: String, abreast: Int
        switch engine {
        case .turboprop: cruise = 500; burnBase = 0.021; burnPerSeat = 0.00004
                         priceFactor = 1.00; maintFactor = 1.00; rangeFactor = 1.0
                         primarySeller = "Orion Aeroworks"; abreast = 2
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
            displayName: name ?? "\(windows) \(engine.label)\(variantII ? " II" : "")",
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
            baseMaintPerWeek: (2_000 + 180 * Double(seats)) * maintFactor,
            // Runway needs scale with SIZE: heavies need the metros,
            // mid-size (regional jets included) need class 2, feeders
            // land anywhere.
            requiredRunwayClass: (engine == .widebody || windows >= 45) ? 3
                               : (windows >= 14 ? 2 : 1))
    }

    // Model names follow real-world conventions: Orion numbers its utility
    // line like Cessna (205/208/210), Northline names regionals for seat
    // count like ATR, Meridian's M-series tracks seats like the E-jets,
    // and Kestrel's KD/KJ lines are its Dash/CRJ-style competitors.
    static let specs: [AircraftType: AircraftSpec] = [
        .turboprop5: makeSpec(windows: 5, engine: .turboprop, name: "Orion 205"),
        .turboprop8: makeSpec(windows: 8, engine: .turboprop, name: "Orion 208"),
        .turboprop10: makeSpec(windows: 10, engine: .turboprop, name: "Orion 210"),
        .turboprop12: makeSpec(windows: 12, engine: .turboprop, name: "Orion 212"),
        .propeller24: makeSpec(windows: 24, engine: .propeller, name: "Northline NR-70"),
        .propeller24II: makeSpec(windows: 24, engine: .propeller, variantII: true, name: "Kestrel KD-72"),
        .propeller28: makeSpec(windows: 28, engine: .propeller, name: "Northline NR-85"),
        .propeller28II: makeSpec(windows: 28, engine: .propeller, variantII: true, name: "Kestrel KD-88"),
        .propeller30: makeSpec(windows: 30, engine: .propeller, name: "Northline NR-95"),
        .propeller30II: makeSpec(windows: 30, engine: .propeller, variantII: true, name: "Kestrel KD-98"),
        .propeller32: makeSpec(windows: 32, engine: .propeller, name: "Northline NR-105"),
        .propeller35: makeSpec(windows: 35, engine: .propeller, name: "Northline NR-120"),
        // Regional jets: Meridian's ladder (18/24/32/42) with Kestrel's
        // wedge sizes (26/29) competing between the rungs.
        .jet18: makeSpec(windows: 18, engine: .jet, name: "Meridian M50"),
        .jet24: makeSpec(windows: 24, engine: .jet, name: "Meridian M70"),
        .jet26: makeSpec(windows: 26, engine: .jet, maker: "Kestrel Aeronautics", name: "Kestrel KJ-80"),
        .jet29: makeSpec(windows: 29, engine: .jet, maker: "Kestrel Aeronautics", name: "Kestrel KJ-90"),
        .jet32: makeSpec(windows: 32, engine: .jet, name: "Meridian M105"),
        .jet42: makeSpec(windows: 42, engine: .jet, name: "Meridian M155"),
        .jet50: makeSpec(windows: 50, engine: .jet, name: "Meridian M200"),
        .jet60: makeSpec(windows: 60, engine: .jet, name: "Meridian M260"),
        .jet60II: makeSpec(windows: 60, engine: .jet, variantII: true, name: "Kestrel KJ-265"),
        // Widebodies: the international era's heavies.
        .widebody55: makeSpec(windows: 55, engine: .widebody, name: "Meridian M230"),
        .widebody65: makeSpec(windows: 65, engine: .widebody, name: "Meridian M300"),
        .widebody75: makeSpec(windows: 75, engine: .widebody, name: "Meridian M375"),
    ]

    // ── Fleet tiers (GDD §22): earn your way up the flight line ─────────
    // Tier 0 feeders are day one. Everything larger unlocks at a market
    // cap threshold, announced by an unlock event card. Old saves are
    // grandfathered at the top tier.

    static func fleetTier(of type: AircraftType) -> Int {
        switch type {
        case .turboprop5, .turboprop8, .turboprop10, .turboprop12:
            0
        case .propeller24, .propeller24II, .propeller28, .propeller28II,
             .propeller30, .propeller30II, .propeller32, .propeller35:
            1
        case .jet18, .jet24, .jet26, .jet29, .jet32:
            2
        case .jet42, .jet50, .jet60, .jet60II:
            3
        case .widebody55, .widebody65, .widebody75:
            4
        }
    }

    /// Market cap needed to unlock each tier (index = tier).
    static let fleetTierThresholds: [Double] = [
        0,               // 0: feeders, day one
        1_500_000,       // 1: regional props
        8_000_000,       // 2: regional jets
        40_000_000,      // 3: mainline narrowbodies
        200_000_000,     // 4: widebodies
    ]

    static let fleetTierNames = [
        "Feeder Operations",
        "Regional License",
        "Jet Certificate",
        "Mainline Authority",
        "Flag Carrier Rights",
    ]

    static let maxFleetTier = 4

    // ── Industry trend decks (GDD §14) ───────────────────────────────────
    // One LONG regime always runs (year-plus); SHORT shocks (a month or
    // three) spawn at trendChancePerWeek, at most two at a time.

    struct TrendTemplate {
        let key: String
        let name: String
        let detail: String
        let kind: IndustryTrend.Kind
        let horizon: IndustryTrend.Horizon
        let multiplier: ClosedRange<Double>
        let weeks: ClosedRange<Int>
    }

    static let trendChancePerWeek = 0.10

    static let longTrendDeck: [TrendTemplate] = [
        .init(key: "expansion", name: "Economic expansion",
              detail: "GDP running hot. Everyone flies more.",
              kind: .demand, horizon: .long, multiplier: 1.08...1.16, weeks: 52...104),
        .init(key: "slowdown", name: "Economic slowdown",
              detail: "Belt-tightening: discretionary travel dries up first.",
              kind: .demand, horizon: .long, multiplier: 0.86...0.94, weeks: 52...104),
        .init(key: "oil_supercycle", name: "Oil supercycle",
              detail: "Structural crude shortage keeps jet fuel dear.",
              kind: .fuel, horizon: .long, multiplier: 1.12...1.28, weeks: 52...104),
        .init(key: "cheap_credit", name: "Cheap credit era",
              detail: "Low rates: manufacturers and lessors sharpen pencils.",
              kind: .aircraftPrices, horizon: .long, multiplier: 0.88...0.95, weeks: 52...104),
        .init(key: "labor_squeeze", name: "Labor squeeze",
              detail: "Aviation talent is scarce industry-wide.",
              kind: .wages, horizon: .long, multiplier: 1.10...1.20, weeks: 52...104),
    ]

    static let shortTrendDeck: [TrendTemplate] = [
        .init(key: "fuel_spike", name: "Fuel spike",
              detail: "Refinery outage bites the spot market.",
              kind: .fuel, horizon: .short, multiplier: 1.15...1.35, weeks: 4...8),
        .init(key: "travel_rush", name: "Travel rush",
              detail: "Festival season packs every cabin.",
              kind: .demand, horizon: .short, multiplier: 1.10...1.22, weeks: 4...10),
        .init(key: "business_surge", name: "Business travel surge",
              detail: "Conference circuit back in full swing.",
              kind: .demand, horizon: .short, multiplier: 1.06...1.15, weeks: 6...12),
        .init(key: "safety_scare", name: "Safety scare",
              detail: "A rival's incident makes headlines; bookings dip.",
              kind: .demand, horizon: .short, multiplier: 0.84...0.92, weeks: 3...6),
        .init(key: "pilot_shortage", name: "Pilot shortage",
              detail: "Crews command a premium this quarter.",
              kind: .wages, horizon: .short, multiplier: 1.10...1.25, weeks: 6...12),
        .init(key: "metal_glut", name: "Used-metal glut",
              detail: "A failed carrier's fleet floods the market.",
              kind: .aircraftPrices, horizon: .short, multiplier: 0.85...0.93, weeks: 6...12),
        .init(key: "order_boom", name: "Order-book boom",
              detail: "Backlogs stretch; sellers stop discounting.",
              kind: .aircraftPrices, horizon: .short, multiplier: 1.06...1.15, weeks: 6...12),
    ]

    static let countryProfiles: [Country: CountryProfile] = [
        .india: .init(fareLevel: 0.6, priceElasticity: 1.8, laborCost: 0.4,
            fuelCost: 1.3, demandGrowthPerYear: 0.09,
            startingTrustFund: 2_000_000, startingSavings: 400_000),
        .us: .init(fareLevel: 1.3, priceElasticity: 1.2, laborCost: 1.5,
            fuelCost: 1.0, demandGrowthPerYear: 0.02, demandLevel: 1.5,
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

    // ── The industry ladder (2026-07-18): nine incumbent carriers to
    // climb past. Static for MVP (competitor AI is v1.0); market caps in
    // game dollars, weekly pax at game scale (~1/100 of real India).
    struct IndustryRival {
        let name: String
        let marketCap: Double
        let weeklyPax: Double
    }
    static let indiaRivals: [IndustryRival] = [
        .init(name: "Himalaya Air",      marketCap: 9_000_000_000, weeklyPax: 60_000),
        .init(name: "AirBharat",         marketCap: 4_500_000_000, weeklyPax: 38_000),
        .init(name: "Monsoon Airways",   marketCap: 2_000_000_000, weeklyPax: 24_000),
        .init(name: "Peacock Air",       marketCap: 900_000_000,   weeklyPax: 15_000),
        .init(name: "Deccan Connect",    marketCap: 400_000_000,   weeklyPax: 9_000),
        .init(name: "Saffron Skies",     marketCap: 150_000_000,   weeklyPax: 5_000),
        .init(name: "Ganga Air",         marketCap: 60_000_000,    weeklyPax: 2_800),
        .init(name: "Coastal Feeders",   marketCap: 25_000_000,    weeklyPax: 1_600),
        .init(name: "Palm Air Charters", marketCap: 8_000_000,     weeklyPax: 900),
    ]
    // US ladder: bigger caps (fares 1.3×, demand 1.5×), same nine rungs.
    static let usRivals: [IndustryRival] = [
        .init(name: "Pacific Crown",         marketCap: 18_000_000_000, weeklyPax: 90_000),
        .init(name: "TransAmerican Airways", marketCap: 10_000_000_000, weeklyPax: 58_000),
        .init(name: "Liberty National",      marketCap: 5_000_000_000,  weeklyPax: 38_000),
        .init(name: "Redwood Air",           marketCap: 2_200_000_000,  weeklyPax: 22_000),
        .init(name: "Lone Star Airways",     marketCap: 1_000_000_000,  weeklyPax: 14_000),
        .init(name: "Great Lakes Aviation",  marketCap: 400_000_000,    weeklyPax: 8_000),
        .init(name: "Bluegrass Connect",     marketCap: 150_000_000,    weeklyPax: 4_500),
        .init(name: "Cactus Feeders",        marketCap: 60_000_000,     weeklyPax: 2_500),
        .init(name: "Keys Island Charters",  marketCap: 12_000_000,     weeklyPax: 1_000),
    ]
    // ── The deep ladder (GDD §22): a $200K founder starts near the very
    // bottom of a real industry. Named anchors top the table; generated
    // regional and charter carriers fill it down to $120K, log-spaced,
    // deterministic per country. US fields 68 rivals (you start #69),
    // India 54 (#55).

    private static let fillerFirstUS = [
        "Bluebird", "Prairie", "Sequoia", "Mesa", "Tidewater", "Ozark",
        "Catalina", "Pinnacle", "Harbor", "Caribou", "Sawtooth", "Bayou",
        "Firefly", "Ridgeline", "Mustang", "Aurora", "Kodiak", "Chinook",
        "Badger", "Cypress", "Dixie", "Elkhorn", "Flatiron", "Gopher",
        "Huron", "Ivory", "Juniper", "Klondike", "Laurel", "Maverick",
        "Nomad", "Osprey", "Pecos", "Quartz", "Rushmore", "Sundance",
        "Teton", "Umpqua", "Vantage", "Wabash", "Yosemite", "Zephyr",
        "Amber", "Boulder", "Cascade", "Denali", "Emerald", "Falcon",
        "Granite", "Hickory", "Iron Range", "Jubilee", "Keystone",
        "Lakeshore", "Meadow", "Nugget", "Overland", "Palmetto",
        "Quicksilver", "Redstone",
    ]
    private static let fillerFirstIndia = [
        "Kaveri", "Aravalli", "Malabar", "Sundarban", "Chenab", "Vindhya",
        "Konkan", "Tawang", "Bastar", "Chambal", "Nilgiri", "Rann",
        "Satpura", "Teesta", "Zanskar", "Bhagirathi", "Coromandel",
        "Dandeli", "Ellora", "Gir", "Hampi", "Indrayani", "Jaisal",
        "Kanha", "Loktak", "Mahanadi", "Narmada", "Orchha", "Periyar",
        "Rewa", "Sharavati", "Tungabhadra", "Ujjain", "Valley",
        "Wular", "Yamuna", "Ajanta", "Bhilai", "Charminar", "Dooars",
        "Eravikulam", "Fatehpur", "Gomti", "Hemis",
    ]
    private static let fillerSuffixes = [
        "Air", "Airways", "Aviation", "Connect", "Express", "Link",
        "Skyways", "Charters",
    ]

    private static func buildLadder(anchors: [IndustryRival],
                                    firstNames: [String],
                                    totalCount: Int) -> [IndustryRival] {
        let floorCap = 120_000.0
        let ceilCap = anchors.map(\.marketCap).min()! * 0.85
        let fillerCount = totalCount - anchors.count
        var fillers: [IndustryRival] = []
        for i in 0..<fillerCount {
            // Log-spaced caps, biggest filler first.
            let t = Double(i) / Double(max(1, fillerCount - 1))
            let cap = ceilCap * pow(floorCap / ceilCap, t)
            let name = "\(firstNames[i % firstNames.count]) \(fillerSuffixes[(i / firstNames.count + i) % fillerSuffixes.count])"
            // Pax tracks cap sublinearly: small carriers still fly people.
            let pax = 120.0 + 22_000.0 * pow(cap / 1_000_000_000, 0.62)
            fillers.append(IndustryRival(name: name, marketCap: cap,
                                         weeklyPax: pax.rounded()))
        }
        return (anchors + fillers).sorted { $0.marketCap > $1.marketCap }
    }

    private static let indiaLadder = buildLadder(anchors: indiaRivals,
                                                 firstNames: fillerFirstIndia,
                                                 totalCount: 54)
    private static let usLadder = buildLadder(anchors: usRivals,
                                              firstNames: fillerFirstUS,
                                              totalCount: 68)

    static func rivals(for country: Country) -> [IndustryRival] {
        switch country {
        case .us: usLadder
        default: indiaLadder
        }
    }
    /// Earnings multiple in the player-valuation formula
    /// (marketCap = max(0, netWorth) + multiple × trailing-year profit).
    static let marketCapEarningsMultiple = 6.0

    // ── Route markets & competition (GDD §21) ────────────────────────────
    /// Rivals flying a city pair, 0…4: big, business-heavy markets attract
    /// competition. Deterministic (stable pair hash), so a route's market
    /// never shifts under the player.
    static func competitorCount(_ a: City, _ b: City) -> Int {
        let size = a.population + b.population            // millions
        let base = size > 20 ? 2 : size > 8 ? 1 : 0
        let biz = (a.businessIndex + b.businessIndex) / 2 > 0.35 ? 1 : 0
        let key = min(a.id, b.id) + max(a.id, b.id)
        let hash = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
        return min(4, base + biz + hash % 2)
    }
    /// The average rival's service appeal on a contested pair.
    static let rivalAppeal = 0.5

    // ── Living competition (GDD §26) ─────────────────────────────────────
    // A fat, dominant route is a magnet: rivals move IN to feed on the
    // yield, splitting the pie until you defend it (re-price, add seats,
    // lift service). Cheap or marginal routes shed rivals. This is what
    // stops "set a profitable route and walk away."
    /// Absolute ceiling on rivals a single pair can attract.
    static let rivalMaxPerRoute = 5.0
    /// How fast the rival count drifts toward its target each week (0…1).
    static let rivalDriftRate = 0.25
    /// Founder grace: rivals don't ENTER before this total week (they can
    /// still leave). A first season shouldn't be swarmed.
    static let rivalEntryGraceWeeks = 20
    /// The rival count a pair trends toward, given how appetizing it looks:
    /// busy (high load) and high-yield (fare above reference) pairs pull the
    /// full field; empty or cheap ones fall back to the structural floor.
    static func rivalTargetPressure(floor: Double, loadFactor: Double,
                                     yieldRatio: Double) -> Double {
        let loadAppeal = max(0, min(1, loadFactor))
        let yieldAppeal = max(0, min(1, (yieldRatio - 0.9) / 0.6))
        let appetite = 0.5 * loadAppeal + 0.5 * yieldAppeal      // 0…1
        return floor + appetite * (rivalMaxPerRoute - floor)
    }

    // ── Route maturity & over-supply (GDD §26 Pillar 2) ──────────────────
    // A new route's market isn't there on day one — it builds over a couple
    // of months. And dumping far more seats than the market wants forces you
    // to discount to fill them, diluting your yield. Together these make
    // opening and up-gauging routes deliberate, not free.
    /// Weeks a fresh route takes to reach its full market.
    static let routeRampWeeks = 10
    /// The fraction of full demand a route sees the week it opens.
    static let routeStartMaturity = 0.35
    /// Smoothstep ramp from `routeStartMaturity` to 1.0 over `routeRampWeeks`.
    static func routeMaturity(weeksOpen: Int) -> Double {
        guard weeksOpen < routeRampWeeks else { return 1.0 }
        let t = max(0, Double(weeksOpen) / Double(routeRampWeeks))
        let s = t * t * (3 - 2 * t)              // smoothstep (S-curve)
        return routeStartMaturity + (1 - routeStartMaturity) * s
    }
    // ── Slot scarcity: use it or lose it (GDD §26 Pillar 3) ──────────────
    // Every couple of quarters the regulator reviews slots at busy airports.
    // A half-empty route hogging a scarce slot is called out: defend it
    // (pay) or give the slots up (frequency reclaimed). Ignore the warning
    // and, like any ambient card, it unfolds to "give them up."
    /// How often (weeks) the slot review runs.
    static let slotReviewIntervalWeeks = 26
    /// An airport counts as busy when this few or fewer slots remain free.
    static let slotReviewCongestionFree = 6
    /// A route below this load factor is "under-using" its scarce slot.
    static let slotReviewLoadThreshold = 0.55
    /// Weekly frequency reclaimed when slots are given up.
    static let slotReviewFrequencyCut = 4
    /// Base cost to defend the slots (scaled with net worth like other
    /// event cash figures).
    static let slotReviewDefendCost = 25_000.0

    /// Seats-to-demand ratio below which there's no over-supply penalty.
    static let oversupplySlackThreshold = 1.25
    /// Worst-case realized-fare multiplier at heavy over-supply.
    static let oversupplyYieldFloor = 0.80
    /// Ratio at which the penalty reaches its floor.
    static let oversupplyRatioAtFloor = 2.5
    /// Realized-yield multiplier: 1.0 until seats exceed demand by the slack
    /// threshold, then fading linearly to the floor at heavy over-supply.
    static func oversupplyYieldMultiplier(seatsOffered: Double, demand: Double) -> Double {
        // No meaningful demand (or no seats) → nothing to dilute.
        guard demand > 1, seatsOffered > 0 else { return 1.0 }
        let ratio = seatsOffered / demand
        guard ratio > oversupplySlackThreshold else { return 1.0 }
        let span = oversupplyRatioAtFloor - oversupplySlackThreshold
        let t = min(1, (ratio - oversupplySlackThreshold) / span)
        return 1.0 - (1.0 - oversupplyYieldFloor) * t
    }
    /// Competition stimulates a market: total pie grows per rival, so a
    /// STRONG product barely feels the competition while a weak one
    /// collapses to its sliver.
    static let marketGrowthPerRival = 0.45

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

    /// US city set (2026-07-18): metro-area populations in millions,
    /// majors class 3, regionals class 2. Distances come from the
    /// haversine fallback. First-pass balance — the US plays long, thin,
    /// and expensive (fareLevel 1.3, laborCost 1.5).
    static let usCities: [City] = [
        .init(id: "JFK", name: "New York",      population: 19.5, businessIndex: 0.50, runwayClass: 3, weeklySlots: 60, latitude: 40.640, longitude: -73.779),
        .init(id: "LAX", name: "Los Angeles",   population: 12.5, businessIndex: 0.40, runwayClass: 3, weeklySlots: 55, latitude: 33.941, longitude: -118.409),
        .init(id: "ORD", name: "Chicago",       population: 9.0,  businessIndex: 0.42, runwayClass: 3, weeklySlots: 55, latitude: 41.978, longitude: -87.904),
        .init(id: "DFW", name: "Dallas",        population: 7.9,  businessIndex: 0.38, runwayClass: 3, weeklySlots: 55, latitude: 32.897, longitude: -97.038),
        .init(id: "ATL", name: "Atlanta",       population: 6.2,  businessIndex: 0.38, runwayClass: 3, weeklySlots: 60, latitude: 33.640, longitude: -84.427),
        .init(id: "MIA", name: "Miami",         population: 6.1,  businessIndex: 0.30, runwayClass: 3, weeklySlots: 45, latitude: 25.795, longitude: -80.279),
        .init(id: "SFO", name: "San Francisco", population: 4.7,  businessIndex: 0.50, runwayClass: 3, weeklySlots: 45, latitude: 37.621, longitude: -122.379),
        .init(id: "BOS", name: "Boston",        population: 4.9,  businessIndex: 0.45, runwayClass: 3, weeklySlots: 45, latitude: 42.366, longitude: -71.010),
        .init(id: "SEA", name: "Seattle",       population: 4.0,  businessIndex: 0.40, runwayClass: 3, weeklySlots: 45, latitude: 47.448, longitude: -122.309),
        .init(id: "PHX", name: "Phoenix",       population: 4.9,  businessIndex: 0.28, runwayClass: 3, weeklySlots: 40, latitude: 33.437, longitude: -112.008),
        .init(id: "DEN", name: "Denver",        population: 3.0,  businessIndex: 0.32, runwayClass: 3, weeklySlots: 45, latitude: 39.850, longitude: -104.674),
        .init(id: "MSP", name: "Minneapolis",   population: 3.7,  businessIndex: 0.32, runwayClass: 2, weeklySlots: 35, latitude: 44.882, longitude: -93.222),
        .init(id: "LAS", name: "Las Vegas",     population: 2.3,  businessIndex: 0.10, runwayClass: 2, weeklySlots: 40, latitude: 36.084, longitude: -115.154),
        .init(id: "AUS", name: "Austin",        population: 2.4,  businessIndex: 0.35, runwayClass: 2, weeklySlots: 30, latitude: 30.194, longitude: -97.670),
        // Expansion set (2026-07-19): the rest of the majors plus strong
        // regionals — the US map now covers both coasts, the Gulf, and
        // the mountain west.
        .init(id: "IAH", name: "Houston",       population: 7.1,  businessIndex: 0.38, runwayClass: 3, weeklySlots: 50, latitude: 29.984, longitude: -95.341),
        .init(id: "PHL", name: "Philadelphia",  population: 6.2,  businessIndex: 0.35, runwayClass: 3, weeklySlots: 40, latitude: 39.872, longitude: -75.241),
        .init(id: "DTW", name: "Detroit",       population: 4.3,  businessIndex: 0.32, runwayClass: 3, weeklySlots: 40, latitude: 42.212, longitude: -83.353),
        .init(id: "CLT", name: "Charlotte",     population: 2.8,  businessIndex: 0.35, runwayClass: 3, weeklySlots: 40, latitude: 35.214, longitude: -80.943),
        .init(id: "MCO", name: "Orlando",       population: 2.7,  businessIndex: 0.15, runwayClass: 3, weeklySlots: 40, latitude: 28.429, longitude: -81.309),
        .init(id: "SAN", name: "San Diego",     population: 3.3,  businessIndex: 0.28, runwayClass: 2, weeklySlots: 35, latitude: 32.734, longitude: -117.190),
        .init(id: "TPA", name: "Tampa",         population: 3.2,  businessIndex: 0.20, runwayClass: 2, weeklySlots: 35, latitude: 27.976, longitude: -82.533),
        .init(id: "STL", name: "St. Louis",     population: 2.8,  businessIndex: 0.25, runwayClass: 2, weeklySlots: 30, latitude: 38.749, longitude: -90.370),
        .init(id: "PDX", name: "Portland",      population: 2.5,  businessIndex: 0.30, runwayClass: 2, weeklySlots: 30, latitude: 45.589, longitude: -122.597),
        .init(id: "BNA", name: "Nashville",     population: 2.1,  businessIndex: 0.25, runwayClass: 2, weeklySlots: 30, latitude: 36.126, longitude: -86.678),
        .init(id: "SLC", name: "Salt Lake City", population: 1.3, businessIndex: 0.28, runwayClass: 2, weeklySlots: 30, latitude: 40.789, longitude: -111.978),
        .init(id: "MSY", name: "New Orleans",   population: 1.3,  businessIndex: 0.15, runwayClass: 2, weeklySlots: 25, latitude: 29.993, longitude: -90.258),
    ]

    /// The playable map for a country.
    static func cities(for country: Country) -> [City] {
        switch country {
        case .us: usCities
        default: indiaCities
        }
    }

    /// Every known airport (coordinate lookups for distance).
    static var allCities: [City] { indiaCities + usCities }

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
        guard let ca = allCities.first(where: { $0.id == a }),
              let cb = allCities.first(where: { $0.id == b }) else { return 1000 }
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
    static let demandK = 550.0  // 2026-07-18 balance pass

    /// How many daily bars the P&L chart keeps (GDD §23) — ~13 weeks.
    static let plChartDays = 91
    /// Global fuel price lever (2026-07-20): 1.0 → 1.15 → 1.38 (a further
    /// +20%). Margins still ran easy; fuel is the biggest single cost, so
    /// this keeps every route honest. Per-country `profile.fuelCost` stacks.
    static let fuelPricePerUnit = 1.38
    /// HQ overhead scales with the operation (§22): a founder's desk costs
    /// little; a fleet needs a real headquarters. Replaces the flat $15K
    /// that would end a $200K start in 13 weeks by itself.
    static let hqOverheadBase = 2_500.0
    static let hqOverheadPerAircraft = 1_400.0
    static func hqOverhead(fleetCount: Int) -> Double {
        hqOverheadBase + hqOverheadPerAircraft * Double(fleetCount)
    }
    static let referenceFarePerKm = 0.120   // §22: squeezed from 0.125

    /// The aunt's seed (GDD §22): every airline starts with this, flat,
    /// scaled only by difficulty. Small on purpose — the game is the climb.
    static let auntSeedFund = 200_000.0

    /// Economy-wide inflation (GDD §28): every cost the airline books —
    /// wages, contractors, maintenance, leases, cabin upkeep, overhead, and
    /// fuel — climbs 5% a year. Revenue is NOT inflated, so a set-and-forget
    /// fare quietly loses ground; keeping fares moving is part of the game.
    static let annualInflation = 0.05
    static func inflationFactor(yearsElapsed: Double) -> Double {
        pow(1 + annualInflation, max(0, yearsElapsed))
    }

    /// Poor condition raises fuel burn (GDD §4.1): up to +15% at condition 0.
    static func fuelConditionMultiplier(condition: Double) -> Double {
        1.0 + (100.0 - condition) / 100.0 * 0.15
    }

    // ── Fleet as rolling reinvestment (GDD §26 Pillar 4) ─────────────────
    // Airframes have a prime, then a costly dotage: past their prime years
    // maintenance escalates and condition slides faster, so an old plane
    // eventually costs more to run than it earns and must be replaced. The
    // fleet becomes a treadmill, not a one-time buy.
    /// Years before age starts to bite hard.
    static let aircraftPrimeYears = 18.0
    /// The age at which the Dashboard flags a plane for replacement.
    static let aircraftRetireFlagYears = 22.0
    /// Extra maintenance per year past prime (+6%/yr → +72% at 30 years).
    static func ageMaintenanceMultiplier(ageYears: Double) -> Double {
        1.0 + 0.06 * max(0, ageYears - aircraftPrimeYears)
    }
    /// Condition decays faster with age: +4%/yr past prime on top of base.
    static func ageConditionDecayMultiplier(ageYears: Double) -> Double {
        1.0 + 0.04 * max(0, ageYears - aircraftPrimeYears)
    }
    /// Old airframes may fall below the MVP condition floor (20) — an aged
    /// hull is allowed to become genuinely decrepit.
    static let agedConditionFloor = 12.0
    /// Time in service leaves permanent marks (GDD §26 Pillar 4): the BEST
    /// condition an airframe can ever be restored to falls with age. New for
    /// the first couple of years, then the ceiling drops ~4 points/yr — so a
    /// 6-year-old jet can never be serviced back to 100%. Irreversible: the
    /// aging tick also pulls condition down to this ceiling.
    static let conditionCeilingGraceYears = 2.0
    static let conditionCeilingDropPerYear = 4.0
    static let conditionCeilingFloor = 40.0
    static func maxCondition(ageYears: Double) -> Double {
        let over = max(0, ageYears - conditionCeilingGraceYears)
        return max(conditionCeilingFloor, 100.0 - conditionCeilingDropPerYear * over)
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
    /// Staff absorb at most this fraction of capacity as overtime (a
    /// practical +35%); demand beyond it goes to contractors — nobody
    /// works a 979% week (2026-07-19; raised 20%→35% 2026-07-22).
    static let overtimeCapFactor = 0.35
    /// Contractor hourly = market hourly × this premium.
    static let contractorPremium = 1.8
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
                           streak: Int, quartersLeft: Int,
                           country: Country = .india) -> String {
        let profit = abs(quarterProfit)
        // Her voice is local: grandfather's trade, the endearment, the units.
        let (granddad, dear, unit): (String, String, String) = switch country {
        case .us: ("pumped gas and counted pennies his whole life", "kiddo", "mile")
        case .uk: ("kept a corner shop his whole life", "love", "mile")
        case .australia: ("drove road trains his whole life", "mate", "kilometer")
        case .china: ("ran a market stall his whole life", "child", "kilometer")
        case .india: ("haggled over rickshaw fares his whole life", "beta", "kilometer")
        }
        switch tone {
        case .proud:
            return "My dear, \(streak) profitable quarters in a row. I read the numbers twice to be sure. Your grandfather \(granddad); you're out here running an airline in the black. Keep the streak alive. Only \(max(0, 4 - streak)) more and the fund is yours properly."
        case .encouraging:
            return "A profit of \(profit.money) this quarter! I won't pretend I understood every line of the report you sent, but I understood the color green. Don't get cocky: one good quarter is weather, four is climate. \(quartersLeft) quarters left before my accountants get twitchy."
        case .worried:
            return "I saw the quarter's numbers: \(profit.money) in the red. I'm not angry, I'm worried. Planes on the ground don't pay for themselves, \(dear). Look at your fares, look at your crews, and for goodness' sake do the maintenance BEFORE things break. \(quartersLeft) quarters remain."
        case .stern:
            return "We need to speak plainly. Another loss, \(profit.money), and the streak reset to nothing. The fund was not a wedding present; it came with conditions and a deadline, and both are approaching faster than you seem to believe. Show me four consecutive profitable quarters. \(quartersLeft) remain. Do not make me write the next letter."
        case .triumphant:
            return "Four profitable quarters. FOUR. I have already called the lawyers. The fund is yours, converted to a gift, with a little extra from me because I am, despite appearances, sentimental. Your grandfather would have pretended not to cry. I will not pretend. Fly far, my dear. You've earned every \(unit)."
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
        MilestoneDef(id: "flagCarrier", title: "Connect 6 {nation} cities", reward: 75_000,
                     isComplete: { state in
                         let touched = Set(state.routes.flatMap { [$0.originID, $0.destinationID] })
                         return touched.count >= 6
                     }),
    ]

    // ── The ambition ladder (GDD §26 Pillar 5) ──────────────────────────
    // Escalating, named goals beyond the aunt's four-quarter arc. Each pays
    // a one-time reward and, more importantly, names the next thing to chase
    // — a reason to plough profit back in instead of coasting. Evaluated in
    // order; the Dashboard shows the current rung with a progress bar.
    static let ambitions: [AmbitionDef] = [
        .init(id: "fleet5", title: "Build a fleet of five", reward: 40_000,
              detail: "Five aircraft is a real operation, not a hobby.", kind: .fleetSize(5)),
        .init(id: "cities8", title: "Serve eight cities", reward: 60_000,
              detail: "A network starts to look like a map.", kind: .cities(8)),
        .init(id: "cap10m", title: "A ten-million airline", reward: 100_000,
              detail: "Reach a $10M market cap.", kind: .marketCap(10_000_000)),
        .init(id: "fleet10", title: "Ten aircraft strong", reward: 150_000,
              detail: "Double digits on the flight line.", kind: .fleetSize(10)),
        .init(id: "rank50", title: "Break into the top 50", reward: 200_000,
              detail: "Climb above the 50th-ranked carrier.", kind: .beatRank(50)),
        .init(id: "rep42", title: "A trusted name", reward: 250_000,
              detail: "Reach a 4.2★ reputation.", kind: .reputation(4.2)),
        .init(id: "cap50m", title: "Fifty million", reward: 300_000,
              detail: "Reach a $50M market cap.", kind: .marketCap(50_000_000)),
        .init(id: "cities12", title: "A dozen cities", reward: 300_000,
              detail: "Twelve cities on the network.", kind: .cities(12)),
        .init(id: "rank25", title: "A top-25 carrier", reward: 500_000,
              detail: "Climb above the 25th-ranked carrier.", kind: .beatRank(25)),
        .init(id: "fleet20", title: "Twenty in the air", reward: 800_000,
              detail: "A serious mainline fleet.", kind: .fleetSize(20)),
        .init(id: "cap200m", title: "Two hundred million", reward: 800_000,
              detail: "Reach a $200M market cap.", kind: .marketCap(200_000_000)),
        .init(id: "cities16", title: "Sixteen cities", reward: 900_000,
              detail: "A genuinely national network.", kind: .cities(16)),
        .init(id: "rank10", title: "Top ten", reward: 1_500_000,
              detail: "Climb into the industry's top ten.", kind: .beatRank(10)),
        .init(id: "rep46", title: "A beloved carrier", reward: 1_500_000,
              detail: "Reach a 4.6★ reputation.", kind: .reputation(4.6)),
        .init(id: "cap500m", title: "Half a billion", reward: 2_000_000,
              detail: "Reach a $500M market cap.", kind: .marketCap(500_000_000)),
        .init(id: "cap1b", title: "A billion-dollar carrier", reward: 3_000_000,
              detail: "Reach a $1B market cap.", kind: .marketCap(1_000_000_000)),
        .init(id: "rank3", title: "The podium", reward: 3_000_000,
              detail: "Reach the industry's top three.", kind: .beatRank(3)),
        .init(id: "fleet30", title: "Thirty aircraft", reward: 3_000_000,
              detail: "A major carrier's flight line.", kind: .fleetSize(30)),
        .init(id: "rank1", title: "Top of the table", reward: 5_000_000,
              detail: "Become the country's largest carrier.", kind: .beatRank(1)),
    ]

    // ── Rival trash talk (GDD §30) ───────────────────────────────────────
    // The ladder gets a voice: a carrier reacts in the press when you pass
    // it, and the carrier just above you takes the occasional jab at the
    // upstart. Placeholders: {you} = your airline, {rival} = their name.
    static let overtakenQuotes = [
        "\"{you}? A flash in the pan. We've flown these skies for decades.\"",
        "\"Congratulations to {you}. Enjoy the view — it's windy up here.\"",
        "\"One good run doesn't make a carrier. We're not losing sleep.\"",
        "\"So {you} slipped ahead. We'll be right back on their tail.\"",
        "\"Respect to {you}. They earned it. Now the real fight begins.\"",
        "\"We wish {you} well. Briefly.\"",
    ]
    static let rivalJabs = [
        "\"{you}? Can't say the name rings a bell.\"",
        "\"A cute little airline. Call us when they leave the regionals.\"",
        "\"There's always room for a minnow. Until there isn't.\"",
        "\"We admire the ambition of {you}. Ambition is cheap.\"",
        "\"Let {you} have the scraps. We'll take the trunk routes.\"",
    ]
    static let overtakenHeadlines = ["RIVAL REACTS", "SOUR GRAPES", "PASSED, AND STINGING", "NO COMMENT (BUT PLENTY OF COMMENT)"]
    static let jabHeadlines = ["EYES ON THE UPSTART", "THE INCUMBENT SPEAKS", "PUNCHING DOWN"]

    // CEO bylines are drawn from the campaign's country name lists
    // (firstNames/lastNames) so rivals read local to the market (§34).

    // ── The event deck (GDD §4.7, M3) ────────────────────────────────────

    // ── Airworthiness (GDD §17) ──────────────────────────────────────────
    /// Wear gained per block hour (2026-07-21): eased 0.05 → 0.035 so an
    /// airframe takes noticeably longer to reach the danger zone.
    static let wearPerBlockHour = 0.035
    /// Opt-in auto-service (GDD §36) sends a plane in for a line check once
    /// its wear crosses this — comfortably below the danger zone.
    static let autoServiceWearThreshold = 78.0
    /// Above this wear, a flying airframe is a hull-loss risk — the Fleet
    /// card warns quietly; ignoring it can end in a crash.
    static let wearDangerThreshold = 90.0
    /// Per-flying-week loss probability at 100% wear (quadratic from the
    /// threshold: 92% wear ≈ 0.3%/wk, 96% ≈ 1.2%, 100% = 8%).
    static let crashRiskAt100Wear = 0.08
    /// Court settlement per life lost.
    static let settlementPerLife = 200_000.0

    // ── Incident claims & event surfacing (GDD §25) ──────────────────────
    /// A plaintiff's lawyers size the claim to the target: a fixed fine that
    /// stings a founder is a rounding error to a flag carrier. So a lawsuit
    /// claim is the greater of its base floor and a slice of the airline's
    /// public value (market cap), capped so no single suit is instantly
    /// ruinous. Rounded to a clean $10K for the headline.
    static func scaledIncidentFee(base: Double, fraction: Double, marketCap: Double) -> Double {
        let scaled = max(0, marketCap) * fraction
        let fee = max(base, min(base * 12, scaled))
        return (fee / 10_000).rounded() * 10_000
    }
    static let teaSpillMarketCapFraction = 0.020
    static let hardLandingMarketCapFraction = 0.035
    /// Event cash figures are AUTHORED at founder scale (a ~$1.5M airline)
    /// and grow with the airline so a decision stays meaningful at any size
    /// (GDD §25): a −$50K hedge is a real call on day one and a joke at
    /// $13M. Scale = netWorth / baseline, clamped to [1, cap]. Percentage
    /// effects (demand, fuel) are already scale-free and are left alone.
    static let eventCashScaleBaseline = 1_500_000.0
    static let eventCashScaleCap = 40.0
    static func eventCashScale(netWorth: Double) -> Double {
        min(eventCashScaleCap, max(1, netWorth / eventCashScaleBaseline))
    }
    /// An ambient event left unattended this many sim days unfolds on its
    /// own, taking its passive (default) option — so the Dashboard never
    /// silently stockpiles undecided cards.
    static let ambientEventGraceDays = 11

    // ── Catering (GDD §18) ───────────────────────────────────────────────
    /// One-time galley oven fit per airframe (instant — immediacy rule).
    static let galleyOvenCost = 40_000.0
    /// Satisfaction-target deltas per tray. The sandwich box backfires
    /// without ovens aboard; the platter is safe; the bento lifts most.
    static let cateringSandwichDelta = 4.0
    static let cateringSandwichColdPenalty = -8.0
    static let cateringFruitDelta = 6.0
    static let cateringBentoDelta = 10.0
    /// A cold premium tray breaks a bigger promise than a cold sandwich.
    static let cateringBentoColdPenalty = -12.0

    /// Event pacing (2026-07-19): decisions are the game, so cards arrive
    /// on a designed rhythm, not a coin flip. The weekly chance starts at
    /// the base and RAMPS with every event-free week — expected cadence
    /// ~2–3 weeks, near-guaranteed within 6 ("pity timer").
    static let eventChancePerWeek = 0.22
    static let eventPityRampPerWeek = 0.13
    static let eventChanceCap = 0.85
    static let eventGraceWeeks = 3

    /// The 12 MVP cards. Weights are shifted by game state in
    /// GameEngine.eventWeight(for:) — events feel like consequences.
    static let eventDeck: [EventCard] = [
        // ── Market ───────────────────────────────────────────────────────
        EventCard(id: "fuelSpike", category: .market,
            title: "Fuel Price Spike",
            body: "Global oil prices jumped overnight. Analysts expect elevated prices for about six weeks.",
            baseWeight: 1.0, isNegative: true, minTotalWeek: 6,
            options: [
                EventOption(label: "Hedge now · −$50K",
                            effects: [.cash(-50_000)]),
                EventOption(label: "Ride it out",
                            effects: [.fuelPrice(multiplier: 1.30, weeks: 6)]),
            ],
            isEligible: { _ in true }),
        EventCard(id: "oilGlut", category: .market,
            title: "Oil Glut",
            body: "A supply surge has fuel contracts trading cheap. Your ops chief is grinning.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 10,
            options: [
                EventOption(label: "Enjoy the cheap fuel",
                            effects: [.fuelPrice(multiplier: 0.85, weeks: 6)]),
            ],
            isEligible: { _ in true }),

        // ── Weather ──────────────────────────────────────────────────────
        EventCard(id: "cyclone", category: .weather,
            title: "Cyclone Warning",
            body: "A cyclone is tracking toward the coast. Ground the fleet and refund, or push through the system — but flying into a cyclone batters airframes, and one may come out badly enough to need the hangar.",
            baseWeight: 0.8, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Ground & refund · −$40K",
                            effects: [.cash(-40_000), .satisfaction(3)]),
                EventOption(label: "Push through the system",
                            effects: [.adjustFleetWear(20),
                                      .wearRandomAircraft(30),
                                      .groundRandomAircraft(weeks: 2),
                                      .demand(multiplier: 0.80, weeks: 2),
                                      .satisfaction(-6), .reputation(-0.1)]),
            ],
            severity: .major,
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
                EventOption(label: "One-time bonus · −$30K",
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
                EventOption(label: "Concede +6% wages",
                            effects: [.raiseWage(role: nil, factor: 1.06),
                                      .happiness(role: nil, delta: 20), .cash(-20_000)]),
                EventOption(label: "Hold the line",
                            effects: [.happiness(role: nil, delta: -10), .satisfaction(-8),
                                      .reputation(-0.3), .demand(multiplier: 0.85, weeks: 2)]),
            ],
            severity: .major,
            isEligible: { state in
                StaffRole.allCases.contains {
                    (state.staff[$0]?.headcount ?? 0) > 0
                    && (state.staff[$0]?.happiness ?? 100) < strikeRiskHappinessThreshold
                }
            }),

        // ── Technical ────────────────────────────────────────────────────
        EventCard(id: "faultFound", category: .technical,
            title: "Engine Fault Found",
            body: "Maintenance flagged a compressor issue on one airframe during a routine inspection. Deferring the fix adds wear.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Fix it now · −$80K",
                            effects: [.cash(-80_000), .groundRandomAircraft(weeks: 1)]),
                EventOption(label: "Defer the fix",
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
                EventOption(label: "To the hangar · −$40K",
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
                EventOption(label: "Accept · +$120K",
                            effects: [.cash(120_000), .demand(multiplier: 0.92, weeks: 1)]),
                // Every decision has weight: declining keeps the schedule
                // whole, and passengers feel the reliability.
                EventOption(label: "Decline politely",
                            effects: [.satisfaction(2)]),
            ],
            isEligible: { state in
                state.fleet.contains { $0.status != .onOrder }
            }),
        EventCard(id: "festivalRush", category: .opportunity,
            title: "Festival Rush",
            body: "A festival season surge is filling planes across the network for the next three weeks.",
            baseWeight: 0.8, isNegative: false, minTotalWeek: 8,
            options: [
                EventOption(label: "All hands on deck",
                            effects: [.demand(multiplier: 1.25, weeks: 3)]),
            ],
            isEligible: { !$0.routes.isEmpty }),

        // ── Regulatory ───────────────────────────────────────────────────
        EventCard(id: "safetyAudit", category: .regulatory,
            title: "Safety Audit Announced",
            body: "The regulator will audit your operation in four weeks. Preparation costs money; failure costs trust.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 16,
            options: [
                EventOption(label: "Prepare properly · −$60K",
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
                EventOption(label: "Run a campaign · −$25K",
                            effects: [.cash(-25_000), .reputation(0.35)]),
                EventOption(label: "Post a thank-you",
                            effects: [.reputation(0.15)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "baggageMeltdown", category: .pr,
            title: "Baggage Meltdown",
            body: "A sorting failure sent a day's worth of bags to the wrong cities. Passengers are posting photos.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Compensate all · −$35K",
                            effects: [.cash(-35_000), .satisfaction(2)]),
                EventOption(label: "Quietly fix it",
                            effects: [.satisfaction(-6), .reputation(-0.2)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        // ── Lawsuit incidents (GDD §19): settle quietly or gamble on court.
        // The body is personalized at present() with the accused member's
        // name, stars, and tenure — the verdict weighs exactly those.
        EventCard(id: "teaSpill", category: .pr,
            title: "Scalding Tea, Furious Passenger",
            body: "A crew member spilled hot tea on a passenger during service. Lawyers are involved.",
            baseWeight: 0.8, isNegative: true, minTotalWeek: 30,
            options: [
                EventOption(label: "Settle quietly · −$180K",
                            effects: [.cash(-180_000)]),
                EventOption(label: "Fight it in court",
                            effects: [.courtVerdict(baseFee: 180_000)]),
            ],
            severity: .major,
            // Past the opening months AND only once the airline can absorb
            // the settlement — a founder's first season shouldn't be ended
            // by a lawsuit (2026-07-20).
            isEligible: { !$0.routes.isEmpty && $0.staff[.cabinCrew]?.members.isEmpty == false
                && $0.cash >= 360_000 }),
        // ── Manufacturer recall (GDD §20): comply or fly the defect.
        // The model is chosen at present() — the type you operate most of.
        EventCard(id: "fleetRecall", category: .technical,
            title: "Manufacturer Recall",
            body: "A manufacturer has recalled one of your fleet's models over a defect.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 16,
            options: [
                EventOption(label: "Send them in · −$10K each",
                            effects: [.recallGround(weeks: 2, costPerPlane: 10_000)]),
                EventOption(label: "Defer · −$25K each",
                            effects: [.recallDefer(finePerPlane: 25_000, wearPerPlane: 12)]),
            ],
            severity: .major,
            isEligible: { state in state.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "hardLanding", category: .pr,
            title: "Hard Landing, Injured Passenger",
            body: "A hard landing injured an elderly passenger's spine. The family's lawyers are circling.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 36,
            options: [
                EventOption(label: "Settle quietly · −$300K",
                            effects: [.cash(-300_000)]),
                EventOption(label: "Fight it in court",
                            effects: [.courtVerdict(baseFee: 300_000)]),
            ],
            severity: .major,
            // Deeper into the timeline and a stiffer cushion — the $300K
            // settlement dwarfs a young airline's whole balance sheet.
            isEligible: { !$0.routes.isEmpty && $0.staff[.pilots]?.members.isEmpty == false
                && $0.cash >= 600_000 }),

        // ════════════════════════════════════════════════════════════════
        // Events expansion (GDD §25). Ambient unless marked .major; for
        // ambient cards the LAST option is the passive default that unfolds
        // on its own if the card is left unattended.
        // ════════════════════════════════════════════════════════════════

        // ── Market & economy ─────────────────────────────────────────────
        EventCard(id: "priceWar", category: .market,
            title: "Price War on Your Trunk Route",
            body: "A budget rival slashed fares on your busiest corridor. Match them and fill seats on thinner margins, or hold your price and cede the cabin.",
            baseWeight: 0.8, isNegative: true, minTotalWeek: 12,
            options: [
                EventOption(label: "Match their fares",
                            effects: [.demand(multiplier: 1.12, weeks: 8),
                                      .recurringCashFlow(weekly: -6_000, weeks: 8, label: "Fare war")]),
                EventOption(label: "Hold the line",
                            effects: [.demand(multiplier: 0.86, weeks: 8)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "landingFees", category: .market,
            title: "Hub Raises Landing Charges",
            body: "Your main hub is pushing through a hike in landing fees. You can fight it, or absorb the running cost.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 14,
            options: [
                EventOption(label: "Negotiate a cap · −$30K",
                            effects: [.cash(-30_000)]),
                EventOption(label: "Absorb the increase",
                            effects: [.recurringCashFlow(weekly: -8_000, weeks: 12, label: "Landing fees")]),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "currencySwing", category: .market,
            title: "Currency Lurches on the Markets",
            body: "A sharp move in the currency is rippling through fuel bills and ticket demand alike.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 16,
            options: [
                EventOption(label: "Hedge exposure · −$40K",
                            effects: [.cash(-40_000)]),
                EventOption(label: "Ride the swings",
                            effects: [.fuelPrice(multiplier: 1.12, weeks: 6),
                                      .demand(multiplier: 0.96, weeks: 6)]),
            ],
            isEligible: { _ in true }),
        EventCard(id: "creditDowngrade", category: .market,
            title: "Credit Rating Cut",
            body: "Lenders downgraded you on the weight of your debt. Every loan just got dearer.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 20,
            options: [
                EventOption(label: "Pay it down · −$100K",
                            effects: [.cash(-100_000)]),
                EventOption(label: "Carry the higher rate",
                            effects: [.recurringCashFlow(weekly: -6_000, weeks: 16, label: "Rate hike")]),
            ],
            isEligible: { $0.loans.reduce(0) { $0 + $1.remaining } > 1_000_000 }),

        // ── Weather & ops ────────────────────────────────────────────────
        EventCard(id: "volcanicAsh", category: .weather,
            title: "Ash Cloud Closes the Airspace",
            body: "A volcanic ash cloud has shut airspace across the region. Grounding is safe but idle; flying the gaps risks the airframes.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 10,
            options: [
                EventOption(label: "Ground the fleet",
                            effects: [.groundFleetShare(fraction: 0.6, weeks: 1), .satisfaction(-4)]),
                EventOption(label: "Push through the gaps",
                            effects: [.wearRandomAircraft(15), .reputation(-0.2), .satisfaction(-6)]),
            ],
            severity: .major,
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "heatwave", category: .weather,
            title: "Heatwave Weight Limits",
            body: "A brutal heatwave is forcing payload restrictions on departures for the next couple of weeks.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Trim payloads",
                            effects: [.demand(multiplier: 0.88, weeks: 2)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "fogSeason", category: .weather,
            title: "Fog Season Wrecks Punctuality",
            body: "Fog is rolling in daily and on-time performance is sliding. You can pad the schedule, or fly the delays.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 12,
            options: [
                EventOption(label: "Pad the schedule · −$20K",
                            effects: [.cash(-20_000), .satisfaction(2)]),
                EventOption(label: "Fly the delays",
                            effects: [.satisfaction(-6), .reputation(-0.1)]),
            ],
            isEligible: { !$0.routes.isEmpty }),

        // ── Crew & labor ─────────────────────────────────────────────────
        EventCard(id: "pilotPoach", category: .labor,
            title: "A Rival Is Poaching Your Pilot",
            body: "A rival is dangling a fat contract at one of your pilots. Match it with a raise, or let a good pilot walk.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 12,
            options: [
                // The actual raise is rolled 15–21% at fire time
                // (poachOptions); this is only the fallback label.
                EventOption(label: "Match it · +18% pilot pay",
                            effects: [.raiseWage(role: .pilots, factor: 1.18),
                                      .happiness(role: .pilots, delta: 8)]),
                EventOption(label: "Wish them well",
                            effects: [.poachStaff(role: .pilots),
                                      .happiness(role: .pilots, delta: -6)]),
            ],
            severity: .major,
            isEligible: { ($0.staff[.pilots]?.members.count ?? 0) > 1 }),
        EventCard(id: "trainingAcademy", category: .labor,
            title: "Training Academy Offer",
            body: "An academy is offering a block course to sharpen your crews. It costs, but skill sticks.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 10,
            options: [
                EventOption(label: "Enroll them · −$60K",
                            effects: [.cash(-60_000), .skillBoost(role: nil, delta: 0.4)]),
                EventOption(label: "Maybe next year",
                            effects: []),
            ],
            isEligible: { $0.staff.values.contains { $0.headcount > 0 } }),
        EventCard(id: "fluSeason", category: .labor,
            title: "Flu Sweeps the Crew Rooms",
            body: "A flu is going around and rosters are thin. Overtime will cover it, but morale takes a knock.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 8,
            options: [
                EventOption(label: "Cover with overtime",
                            effects: [.happiness(role: nil, delta: -4),
                                      .demand(multiplier: 0.94, weeks: 2)]),
            ],
            isEligible: { $0.staff.values.contains { $0.headcount > 0 } }),
        EventCard(id: "longService", category: .labor,
            title: "A Long-Service Milestone",
            body: "One of your founding crew hits a service milestone. A little recognition goes a long way.",
            baseWeight: 0.5, isNegative: false, minTotalWeek: 30,
            options: [
                EventOption(label: "Throw a party · −$15K",
                            effects: [.cash(-15_000), .happiness(role: nil, delta: 8)]),
                EventOption(label: "A quiet thank-you",
                            effects: [.happiness(role: nil, delta: 2)]),
            ],
            isEligible: { $0.staff.values.contains { $0.headcount >= 3 } }),

        // ── Technical & fleet ────────────────────────────────────────────
        EventCard(id: "birdStrike", category: .technical,
            title: "Bird Strike on Departure",
            body: "A departing aircraft took a bird strike. It needs an inspection before it flies again.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 6,
            options: [
                EventOption(label: "Inspect and clear",
                            effects: [.groundRandomAircraft(weeks: 1)]),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "airworthinessDirective", category: .technical,
            title: "Airworthiness Directive",
            body: "The regulator issued a directive on a component you fly. Comply now, or defer and let the wear build.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 12,
            options: [
                EventOption(label: "Comply now · −$45K",
                            effects: [.cash(-45_000)]),
                EventOption(label: "Defer the check",
                            effects: [.wearRandomAircraft(18)]),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "avionicsUpgrade", category: .technical,
            title: "Avionics Refresh Offer",
            body: "A supplier is offering a fleet-wide avionics refresh. It freshens every airframe and cuts strain.",
            baseWeight: 0.5, isNegative: false, minTotalWeek: 16,
            options: [
                EventOption(label: "Fit the fleet · −$120K",
                            effects: [.cash(-120_000), .adjustFleetWear(-12)]),
                EventOption(label: "Not now",
                            effects: []),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "tiredCabins", category: .pr,
            title: "Passengers Say the Cabins Look Tired",
            body: "Complaints about worn cabins are piling up. Fund a refit push, or live with the grumbling.",
            baseWeight: 0.6, isNegative: true, minTotalWeek: 14,
            options: [
                EventOption(label: "Fund a refit · −$70K",
                            effects: [.cash(-70_000), .satisfaction(8)]),
                EventOption(label: "Live with it",
                            effects: [.satisfaction(-5)]),
            ],
            isEligible: { !$0.routes.isEmpty }),

        // ── Opportunity ──────────────────────────────────────────────────
        EventCard(id: "allianceInvite", category: .opportunity,
            title: "Codeshare Alliance Invitation",
            body: "A larger carrier invites you into a codeshare alliance. The feed lifts demand across your network, for a price.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 24,
            options: [
                EventOption(label: "Join the alliance · −$80K",
                            effects: [.cash(-80_000), .demand(multiplier: 1.12, weeks: 26)]),
                EventOption(label: "Stay independent",
                            effects: [.reputation(0.05)]),
            ],
            severity: .major,
            isEligible: { $0.routes.count >= 3 }),
        EventCard(id: "cargoContract", category: .opportunity,
            title: "Belly-Cargo Contract",
            body: "A logistics firm wants belly-cargo space on your routes. Steady money for space you already fly.",
            baseWeight: 0.7, isNegative: false, minTotalWeek: 12,
            options: [
                EventOption(label: "Sign the contract",
                            effects: [.recurringCashFlow(weekly: 12_000, weeks: 16, label: "Cargo revenue")]),
                EventOption(label: "Pass",
                            effects: []),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "sportsCharter", category: .opportunity,
            title: "Sports-Team Charter Season",
            body: "A team wants a charter deal for its season. A cash windfall, though it pulls some capacity.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 10,
            options: [
                EventOption(label: "Fly the season · +$90K",
                            effects: [.cash(90_000), .demand(multiplier: 0.95, weeks: 3)]),
                EventOption(label: "Decline",
                            effects: [.satisfaction(2)]),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "liverySponsor", category: .opportunity,
            title: "Livery Sponsorship Deal",
            body: "A brand wants its name down the side of your jets. Easy money, and a little buzz.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 14,
            options: [
                EventOption(label: "Paint the tails · +$60K",
                            effects: [.cash(60_000), .reputation(0.1)]),
                EventOption(label: "Keep it classy",
                            effects: [.reputation(0.05)]),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        EventCard(id: "regionalSubsidy", category: .opportunity,
            title: "Regional Service Subsidy",
            body: "The government will subsidize service to a smaller city, but only if you commit to flying it. You fund the launch now; they top up the thin loads over the next few months. Barely pays, but it wins goodwill.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 12,
            options: [
                EventOption(label: "Commit to the service · −$60K",
                            effects: [.cash(-60_000),
                                      .recurringCashFlow(weekly: 6_000, weeks: 16, label: "Regional subsidy"),
                                      .reputation(0.15)]),
                EventOption(label: "Not our market",
                            effects: []),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),

        // ── Regulatory ───────────────────────────────────────────────────
        EventCard(id: "carbonLevy", category: .regulatory,
            title: "Carbon Levy Lands",
            body: "A carbon levy now rides on every departure. Buy offsets up front for the goodwill, or just pay it down the line.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 28,
            options: [
                EventOption(label: "Buy offsets · −$150K",
                            effects: [.cash(-150_000), .reputation(0.15)]),
                EventOption(label: "Pay the levy",
                            effects: [.recurringCashFlow(weekly: -10_000, weeks: 26, label: "Carbon levy")]),
            ],
            severity: .major,
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),
        // Slot pressure is delivered by the targeted slot review (GDD §26
        // Pillar 3), not a generic deck card.
        EventCard(id: "passengerRights", category: .regulatory,
            title: "New Passenger-Rights Rules",
            body: "New rules raise the compensation you owe for disruptions. Compliance is not optional.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 20,
            options: [
                EventOption(label: "Comply",
                            effects: [.recurringCashFlow(weekly: -5_000, weeks: 12, label: "Comp costs")]),
            ],
            isEligible: { !$0.routes.isEmpty }),

        // ── PR & brand ───────────────────────────────────────────────────
        EventCard(id: "influencerReview", category: .pr,
            title: "An Influencer Is Flying You",
            body: "A big-account traveler is reviewing your service to millions. Roll out the red carpet, or treat them like anyone.",
            baseWeight: 0.6, isNegative: false, minTotalWeek: 8,
            options: [
                EventOption(label: "Red carpet · −$10K",
                            effects: [.cash(-10_000), .reputation(0.3)]),
                EventOption(label: "Treat them normally",
                            effects: [.reputation(0.05)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "overbooking", category: .pr,
            title: "Overbooking Bump Goes Public",
            body: "A bumped passenger's story is spreading. Compensate generously, or tough it out.",
            baseWeight: 0.7, isNegative: true, minTotalWeek: 12,
            options: [
                EventOption(label: "Compensate all · −$25K",
                            effects: [.cash(-25_000), .satisfaction(3)]),
                EventOption(label: "Tough it out",
                            effects: [.satisfaction(-6), .reputation(-0.15)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "dataBreach", category: .pr,
            title: "Passenger Data Leaked",
            body: "Hackers have leaked your passenger database. Contain it fast at cost, or downplay it and hope.",
            baseWeight: 0.5, isNegative: true, minTotalWeek: 24,
            options: [
                EventOption(label: "Contain it · −$120K",
                            effects: [.cash(-120_000), .reputation(-0.1)]),
                EventOption(label: "Downplay it",
                            effects: [.reputation(-0.5), .satisfaction(-6)]),
            ],
            severity: .major,
            isEligible: { _ in true }),
        EventCard(id: "mealViral", category: .pr,
            title: "Your Meal Goes Viral",
            body: "A photo of your cabin meal is racking up millions of likes. Ride the buzz.",
            baseWeight: 0.5, isNegative: false, minTotalWeek: 10,
            options: [
                EventOption(label: "Ride the buzz",
                            effects: [.satisfaction(5), .reputation(0.1)]),
            ],
            isEligible: { !$0.routes.isEmpty }),
        EventCard(id: "maydayHandled", category: .pr,
            title: "Crew Handles an Emergency",
            body: "Your crew handled an in-flight emergency flawlessly, and the press noticed. Commend them.",
            baseWeight: 0.5, isNegative: false, minTotalWeek: 16,
            options: [
                EventOption(label: "Commend the crew",
                            effects: [.reputation(0.25), .happiness(role: .pilots, delta: 6)]),
            ],
            isEligible: { $0.fleet.contains { $0.status != .onOrder } }),

        // ── Signature ────────────────────────────────────────────────────
        // A lower-ranked carrier folds (GDD §27): buy its jets and crews at
        // a fire-sale, cherry-pick just the talent, or let the market flood.
        // The body names a real rival ranked below you at fire time.
        EventCard(id: "rivalCollapse", category: .opportunity,
            title: "A Rival Has Collapsed",
            body: "A smaller carrier has filed for bankruptcy. Its jets and crews are on the block at fire-sale prices.",
            baseWeight: 0.5, isNegative: false, minTotalWeek: 30,
            options: [
                EventOption(label: "Buy jets & crews · −$400K",
                            effects: [.cash(-400_000), .acquireUsedFleet(count: 3),
                                      .acquireStaff(pilots: 4, cabinCrew: 4, ground: 3)]),
                EventOption(label: "Hire their crews only",
                            effects: [.acquireStaff(pilots: 3, cabinCrew: 3, ground: 2)]),
                EventOption(label: "Let the market have it",
                            effects: [.aircraftMarketShock(multiplier: 0.85, weeks: 8)]),
            ],
            severity: .major,
            isEligible: { _ in true }),
        EventCard(id: "awardNod", category: .pr,
            title: "Up for an Industry Award",
            body: "You've been nominated for a carrier-of-the-year award. Recognition is its own reward.",
            baseWeight: 0.5, isNegative: false, minTotalWeek: 20,
            options: [
                EventOption(label: "Celebrate the nod",
                            effects: [.reputation(0.2), .satisfaction(2)]),
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

    // Gendered pools so names match the staff avatars (2026-07-19).
    // Country-flavored (2026-07-19): people carry names from the campaign's
    // labor market. The union lists below stay for gender inference on
    // pre-feature saves.
    static let indiaFirstNamesMale = [
        "Arjun", "Rohan", "Vikram", "Kabir", "Dev", "Farhan", "Aditya",
        "Rahul", "Imran", "Nikhil", "Sam", "Jake", "Marcus", "Diego", "Leo",
    ]
    static let indiaFirstNamesFemale = [
        "Priya", "Ananya", "Meera", "Isha", "Naina", "Zara", "Sana",
        "Divya", "Lakshmi", "Tara", "Emma", "Sofia", "Maya", "Grace", "Ava",
    ]
    static let usFirstNamesMale = [
        "James", "Tyler", "Ethan", "Mason", "Logan", "Carlos", "Marcus",
        "Jake", "Dylan", "Austin", "Caleb", "Trevor", "Miguel", "Andre", "Sam",
    ]
    static let usFirstNamesFemale = [
        "Emily", "Madison", "Ashley", "Hannah", "Olivia", "Emma", "Sofia",
        "Grace", "Ava", "Chloe", "Riley", "Jasmine", "Megan", "Brooke", "Kayla",
    ]

    static func firstNames(country: Country, male: Bool) -> [String] {
        switch country {
        case .us, .uk, .australia: male ? usFirstNamesMale : usFirstNamesFemale
        default: male ? indiaFirstNamesMale : indiaFirstNamesFemale
        }
    }

    /// Unions — used only to infer gender when backfilling old saves.
    static let firstNamesMale = indiaFirstNamesMale + usFirstNamesMale
    static let firstNamesFemale = indiaFirstNamesFemale + usFirstNamesFemale

    /// Avatar variants available per role/gender (Resources/StaffAvatars,
    /// avatar_<role>_<m|f>_<nn>.png).
    static func avatarVariants(role: StaffRole, male: Bool) -> Int {
        switch (role, male) {
        case (.pilots, true): 7
        case (.pilots, false): 7
        case (.cabinCrew, true): 6
        case (.cabinCrew, false): 7
        case (.ground, true): 6
        case (.ground, false): 5
        case (.hq, true): 6
        case (.hq, false): 6
        }
    }

    static func avatarName(role: StaffRole, male: Bool, variant: Int) -> String {
        let key: String
        switch role {
        case .pilots: key = "pilot"
        case .cabinCrew: key = "crew"
        case .ground: key = "ground"
        case .hq: key = "hq"
        }
        return String(format: "avatar_%@_%@_%02d", key, male ? "m" : "f", variant)
    }
    static let indiaLastNames = [
        "Sharma", "Patel", "Singh", "Nair", "Khan", "Iyer", "Das",
        "Mehta", "Reddy", "Kapoor", "Bose", "Menon", "Joshi", "Rao",
    ]
    static let usLastNames = [
        "Miller", "Johnson", "Carter", "Bennett", "Hayes", "Brooks",
        "Turner", "Reed", "Walker", "Cooper", "Diaz", "Nguyen",
        "Murphy", "Sullivan",
    ]
    static func lastNames(country: Country) -> [String] {
        switch country {
        case .us, .uk, .australia: usLastNames
        default: indiaLastNames
        }
    }

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
    static let leaseRatePerWeek = 0.00189   // +35% (2026-07-20); ~9.8%/yr of hull value
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
