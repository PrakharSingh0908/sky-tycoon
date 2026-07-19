//
//  Models.swift
//  SkyTycoon — Simulation core (pure Swift, no SwiftUI)
//
//  Value-type state, single mutation owner. All models are structs
//  (Codable, Identifiable). The only class is GameEngine, which owns the
//  one GameState and is the only thing allowed to mutate it.
//

import Foundation

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
    /// The trust fund's voice belongs to the campaign's market: the aunt
    /// writing the quarterly letters is local (GDD §3).
    var auntName: String {
        switch self {
        case .india: "Meera"; case .us: "Margaret"; case .uk: "Beatrice"
        case .china: "Mei"; case .australia: "Maggie"
        }
    }
    /// "Indian cities", "American cities" — campaign-aware copy.
    var adjective: String {
        switch self {
        case .india: "Indian"; case .us: "American"; case .uk: "British"
        case .china: "Chinese"; case .australia: "Australian"
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
    /// Propensity-to-fly multiplier on gravity demand (demandK was
    /// calibrated on India's 30M metros; smaller-metro/high-income
    /// markets fly more per capita).
    var demandLevel: Double = 1.0
    var startingTrustFund: Double
    var startingSavings: Double
}

struct City: Codable, Identifiable, Hashable {
    let id: String               // stable slug, e.g. "BLR"
    var name: String
    var population: Double        // millions
    var businessIndex: Double     // 0...1, share of demand that is business travel
    var runwayClass: Int          // 1 = regional strip ... 3 = major international
    var weeklySlots: Int
    /// Airport position (plain degrees — the sim stays UI-framework-free;
    /// the map layer converts). Also the future source for computed
    /// distances when more countries arrive.
    var latitude: Double
    var longitude: Double
}

/// Engine class — the second half of every asset's name ("24 Propeller").
/// Drives speed, burn, price and maintenance character (see Balance.makeSpec).
enum EngineKind: String, Codable {
    case turboprop   // small single/twin props — cheap feeders
    case propeller   // large regional props (ATR class) — efficient workhorses
    case jet         // regional & mainline narrowbodies — fast, expensive
    case widebody    // twin-aisle long-haul — the international era

    var label: String {
        switch self {
        case .turboprop: "Turboprop"; case .propeller: "Propeller"
        case .jet: "Jet"; case .widebody: "Widebody"
        }
    }
}

/// The fleet catalog, one case per photo asset. Named exactly like the
/// assets: window count + engine kind (II = second variant of the same
/// size). Window count drives every spec (§Balance.makeSpec).
enum AircraftType: String, Codable, CaseIterable, Identifiable {
    case turboprop5, turboprop8, turboprop10, turboprop12
    case propeller24, propeller24II, propeller28, propeller28II
    case propeller30, propeller30II, propeller32, propeller35
    case jet18, jet24, jet26, jet29, jet32, jet42
    case jet50, jet60, jet60II
    case widebody55, widebody65, widebody75
    var id: String { rawValue }
}

/// A livery color as plain RGB (0...1) — the sim stays UI-framework-free;
/// the UI layer converts to/from SwiftUI Color.
struct LiveryColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
}

/// The airline's paint scheme (GDD §4.8 branding): applied to every
/// aircraft profile in the UI. Three paintable regions.
struct Livery: Codable, Equatable {
    var fuselage: LiveryColor
    var tail: LiveryColor
    var stripe: LiveryColor

    /// Unpainted factory scheme — used for showroom aircraft that haven't
    /// joined the fleet yet.
    static let factory = Livery(
        fuselage: LiveryColor(red: 0.93, green: 0.94, blue: 0.96),
        tail: LiveryColor(red: 0.63, green: 0.67, blue: 0.72),
        stripe: LiveryColor(red: 0.55, green: 0.58, blue: 0.63))

    /// Default scheme for a new airline (teal tail, navy cheatline).
    static let launch = Livery(
        fuselage: LiveryColor(red: 0.93, green: 0.94, blue: 0.96),
        tail: LiveryColor(red: 0.25, green: 0.84, blue: 0.79),
        stripe: LiveryColor(red: 0.10, green: 0.18, blue: 0.32))
}

/// Static spec sheet per archetype, derived entirely from the airframe's
/// window count (see Balance.makeSpec). Instances reference this by type.
struct AircraftSpec: Codable {
    var displayName: String
    var windowCount: Int         // the number you can see in the photo
    var engine: EngineKind
    var seller: String           // manufacturer — repeat orders earn loyalty discounts
    var seatsAbreast: Int        // at 17" seats; cabin width is fixed by the airframe
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

// ── Cabin architecture (GDD §4.2 as amended) ─────────────────────────────

/// Seat tiers, matching the seat render assets (Resources/SeatPhotos).
enum CabinMaterial: String, Codable, CaseIterable, Identifiable {
    case economy, premium, luxury
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .economy: "Economy"; case .premium: "Premium"; case .luxury: "Luxury"
        }
    }
    /// Comfort contribution (0...1 scale component).
    var comfort: Double {
        switch self { case .economy: 0; case .premium: 0.12; case .luxury: 0.20 }
    }
    /// Install cost per seat and weekly upkeep per seat.
    var costPerSeat: Double {
        switch self { case .economy: 800; case .premium: 1_600; case .luxury: 2_800 }
    }
    var upkeepPerSeatPerWeek: Double {
        switch self { case .economy: 6; case .premium: 9; case .luxury: 14 }
    }
}

/// The interior of one airframe: seat dimensions, galley (ovens for hot
/// meals), wifi, and cabin material. Every choice trades install cost,
/// weekly running cost, seat count, and passenger comfort.
struct CabinLayout: Codable, Equatable {
    var seatPitchInches: Double    // 28 (sardine) ... 36 (spacious)
    var seatWidthInches: Double    // 16 (slim) ... 20 (armchair)
    var material: CabinMaterial
    var galleyUnits: Int           // 0...3 — each takes a seat row, enables hot meals
    var hasWifi: Bool

    static func standard(abreast: Int) -> CabinLayout {
        CabinLayout(seatPitchInches: 30, seatWidthInches: 17,
                    material: .economy, galleyUnits: abreast >= 4 ? 1 : 0,
                    hasWifi: false)
    }

    // ── Derived geometry (from the spec's densest configuration) ────────

    /// Rows available at this pitch: cabin length is fixed by the airframe
    /// (densest rows × 28"), and each galley unit displaces one row.
    func rows(spec: AircraftSpec) -> Int {
        let denseRows = Double(spec.maxSeats) / Double(spec.seatsAbreast)
        let cabinLength = denseRows * 28.0
        return max(1, Int(cabinLength / seatPitchInches) - galleyUnits)
    }

    /// Seats abreast at this seat width (17" is the airframe's natural fit).
    func seatsAbreast(spec: AircraftSpec) -> Int {
        max(1, Int(Double(spec.seatsAbreast) * 17.0 / seatWidthInches))
    }

    /// Seats installed — hard-capped at the airframe's certified exit
    /// limit (spec.maxSeats): no layout may exceed it, ever.
    func seats(spec: AircraftSpec) -> Int {
        min(spec.maxSeats, rows(spec: spec) * seatsAbreast(spec: spec))
    }

    /// Payload-range tradeoff: a denser cabin is a heavier airplane.
    /// Configuration fill drives the factor — a certified-limit sardine
    /// layout pays −15% range; an airy cabin gains up to +10% (the
    /// "ferry configuration" trick for stretching a marginal route).
    func rangeFactor(spec: AircraftSpec) -> Double {
        let fill = Double(seats(spec: spec)) / Double(max(spec.maxSeats, 1))
        return min(1.10, 1.15 - 0.30 * fill)
    }

    /// 0...1 passenger comfort from the interior choices alone.
    var comfort: Double {
        let pitch = (seatPitchInches - 28) / 8 * 0.45
        let width = (seatWidthInches - 16) / 4 * 0.25
        let meals = galleyUnits > 0 ? 0.05 + Double(galleyUnits - 1) * 0.03 : 0
        let wifi = hasWifi ? 0.05 : 0
        return min(1, pitch + width + material.comfort + meals + wifi)
    }

    // ── Money ────────────────────────────────────────────────────────────

    /// One-time refit cost (also grounds the aircraft — see engine).
    func refitCost(spec: AircraftSpec) -> Double {
        Double(seats(spec: spec)) * material.costPerSeat
            + Double(galleyUnits) * 40_000
            + (hasWifi ? 1_500 * Double(spec.maxSeats) : 0)
    }

    /// Weekly running cost: cleaning/upkeep per seat, catering ops per
    /// galley, wifi service.
    func weeklyUpkeep(spec: AircraftSpec) -> Double {
        Double(seats(spec: spec)) * material.upkeepPerSeatPerWeek
            + Double(galleyUnits) * 600
            + (hasWifi ? 12 * Double(spec.maxSeats) : 0)
    }
}

/// How an airframe entered the fleet (GDD §4.1). Drives P&L (lease line),
/// sellability (leased planes can't be sold), and netWorth (leased planes
/// aren't assets).
enum AcquisitionType: String, Codable {
    case ownedNew, ownedUsed, leased
}

struct Aircraft: Codable, Identifiable {
    let id: UUID
    var type: AircraftType
    var nickname: String
    var status: AircraftStatus
    var acquisition: AcquisitionType
    /// Weekly lease payment; 0 unless acquisition == .leased.
    var weeklyLeaseCost: Double
    /// Weeks until a new-plane order is delivered; 0 = delivered/in service.
    var deliveryWeeksRemaining: Int
    /// The interior (GDD §4.2 as amended) — seats, galley, wifi, material.
    var cabin: CabinLayout
    /// 0...100. Accumulates per flight-hour; checks reduce it.
    var wear: Double
    /// 1...100. Second-hand planes arrive with less; heavy checks restore a bit.
    var condition: Double
    var ageYears: Double
    var assignedRouteID: UUID?
    /// Weeks remaining out of service (maintenance), 0 = available.
    var groundedWeeksRemaining: Int

    /// Galley oven fitted (GDD §18): required for hot-meal catering.
    /// Optional for save-compat: nil = not fitted.
    var hasGalleyOven: Bool? = nil

    func seats(spec: AircraftSpec) -> Int {
        cabin.seats(spec: spec)
    }
    /// What this airframe can actually fly with its current interior —
    /// the brochure range corrected for payload (GDD §4.2 as amended).
    func effectiveRangeKm(spec: AircraftSpec) -> Double {
        spec.rangeKm * cabin.rangeFactor(spec: spec)
    }
    /// 0...1 comfort score fed into satisfaction: the interior sets it,
    /// airframe condition caps it (old planes rattle).
    var comfortScore: Double {
        (0.32 + cabin.comfort * 0.60) * (0.7 + 0.3 * condition / 100.0)
    }
}

/// A second-hand aircraft for sale (GDD §4.1). MVP: condition is visible
/// on every listing; hidden condition + inspections arrive in v1.0.
struct UsedListing: Codable, Identifiable {
    let id: UUID
    var type: AircraftType
    var ageYears: Double
    var condition: Double        // 40...90, visible in MVP
    var price: Double
}

/// In-flight catering per route (GDD §18): the three trays. The sandwich
/// box is the budget option but needs a galley oven on EVERY aircraft
/// flying the route — served cold, customers get frustrated. The fruit
/// platter is delicate and pricier but oven-agnostic. The Asian bento is
/// the premium tray with the biggest lift — at the biggest cost.
enum CateringLevel: String, Codable, CaseIterable, Identifiable {
    case none, sandwichBox, fruitPlatter, asianBento
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: "No service"
        case .sandwichBox: "Sandwich box"
        case .fruitPlatter: "Fruit platter"
        case .asianBento: "Asian bento"
        }
    }
    /// Catering cost per passenger carried, charged weekly.
    var costPerPax: Double {
        switch self {
        case .none: 0; case .sandwichBox: 2.0
        case .fruitPlatter: 5.0; case .asianBento: 9.0
        }
    }
    /// The trays that need the hardware: toasted sandwiches and bento
    /// mains board cold without an oven, and it shows in satisfaction.
    /// Only the fruit platter is oven-agnostic.
    var requiresOven: Bool { self == .sandwichBox || self == .asianBento }
    /// SF fallback if an asset ever fails to load (Resources/Food).
    var icon: String {
        switch self {
        case .none: "nosign"
        case .sandwichBox: "takeoutbag.and.cup.and.straw.fill"
        case .fruitPlatter: "leaf.fill"
        case .asianBento: "fork.knife"
        }
    }
    var assetName: String? {
        switch self {
        case .none: nil
        case .sandwichBox: "food_sandwich_box"
        case .fruitPlatter: "food_fruit_platter"
        case .asianBento: "food_asian_bento"
        }
    }

    /// Decode-compat with the short-lived snacks/hotMeals tiers.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "snacks": self = .fruitPlatter
        case "hotMeals": self = .asianBento
        default: self = CateringLevel(rawValue: raw) ?? .none
        }
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
    /// Last week's stats, for UI and unit economics.
    var lastLoadFactor: Double
    var lastWeeklyProfit: Double
    var lastWeeklyRevenue: Double
    var lastWeeklyFuel: Double
    /// Load factor per week, newest last (capped ring buffer, ~26 weeks)
    /// — feeds the route sparkline (GDD §7 tab 3).
    var loadFactorHistory: [Double]
    /// Last week's on-time rate 0...1, driven by staffing strain and ops
    /// skill (GDD §4.4). Airline-wide in MVP, stored per route for the UI.
    var lastPunctuality: Double
    /// In-flight service level (GDD §18). Optional for save-compat: nil = none.
    var catering: CateringLevel? = nil
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

/// Someone who answered a job ad (GDD §4.4 as amended): individual skill
/// and asking wage; can be hired outright, or negotiated down — which
/// raises irritation, and irritated applicants walk.
struct JobApplicant: Codable, Identifiable {
    let id: UUID
    var role: StaffRole
    var name: String
    var avatar: String? = nil
    var skill: Double          // 1...5
    var askingWage: Double     // weekly
    /// 0...1 hidden willingness to meet a counter-offer in the middle.
    var flexibility: Double
    /// 0...100, rises with lowball offers; at 100 they walk.
    var irritation: Double
    /// Weeks before they take another job and withdraw.
    var weeksRemaining: Int
}

/// One person on the roster. The sim runs on the pool's aggregates
/// (averages of these members); identity is for the player.
struct StaffMember: Codable, Identifiable {
    let id: UUID
    var name: String
    var skill: Double             // 1...5
    var weeklyWage: Double
    var hiredOn: GameDate
    /// Asset name in Resources/StaffAvatars (nil in pre-avatar saves →
    /// UI falls back to a monogram).
    var avatar: String? = nil
}

struct StaffPool: Codable {
    var role: StaffRole
    var headcount: Int
    var weeklyWage: Double        // pool average — kept in sync with members
    var happiness: Double         // 0...100
    var skill: Double             // pool average — kept in sync with members
    /// Last week's EMPLOYEE workload ÷ capacity, capped at the overtime
    /// ceiling (1.2): contractors absorb the rest.
    var lastUtilization: Double
    /// Share of last week's demand flown by contractors (0…1). Optional
    /// for save-compat with pre-contractor saves.
    var lastContractorShare: Double? = nil
    /// The individuals (invariant: members.count == headcount).
    var members: [StaffMember]
}

struct Loan: Codable, Identifiable {
    let id: UUID
    var principal: Double
    var remaining: Double
    var weeklyInterestRate: Double
    var weeklyPayment: Double
}

// ── Events (GDD §4.7, M3) ────────────────────────────────────────────────

enum EventCategory: String, Codable, CaseIterable {
    case market, weather, labor, technical, opportunity, regulatory, pr
    case story   // trust-fund arc beats — never drawn from the deck
}

/// One concrete consequence of choosing an event option.
enum EventEffect: Codable, Equatable {
    case cash(Double)
    /// nil role = every pool.
    case happiness(role: StaffRole?, delta: Double)
    case satisfaction(Double)             // all routes
    case reputation(Double)
    /// nil role = every pool; factor multiplies the weekly wage.
    case raiseWage(role: StaffRole?, factor: Double)
    /// Timed world modifiers, applied during the tick while active.
    case fuelPrice(multiplier: Double, weeks: Int)
    case demand(multiplier: Double, weeks: Int)
    /// A seeded-random delivered aircraft goes to the shop.
    case groundRandomAircraft(weeks: Int)
    /// A seeded-random delivered aircraft takes wear (deferred fixes bite).
    case wearRandomAircraft(Double)
    /// Take the incident to court (GDD §19). The verdict resolves from the
    /// accused employee's credibility — skill stars plus tenure — at choice
    /// time: cleared = legal costs only and the press runs your side;
    /// liable = 1.5× the fee and a public reputation bruise.
    case courtVerdict(baseFee: Double)
    /// Manufacturer recall, complied (GDD §20): every delivered airframe of
    /// the event's subject type is grounded for the retrofit; the shop
    /// visit also freshens wear. Cost is logistics per airframe.
    case recallGround(weeks: Int, costPerPlane: Double)
    /// Manufacturer recall, deferred: fly on with the defect — fines per
    /// airframe, wear added to each, and a regulatory reputation scratch.
    case recallDefer(finePerPlane: Double, wearPerPlane: Double)
}

/// A running timed modifier ("Fuel +30% · 4 wk"), applied each tick.
struct TimedEffect: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: Kind
    var multiplier: Double
    var weeksRemaining: Int
    var label: String

    enum Kind: String, Codable { case fuelPrice, demand }
}

// ── Industry trends (GDD §14) ────────────────────────────────────────────
// The market breathes on two horizons: one LONG economic regime is always
// in force (expansion, slowdown, oil supercycle…), and up to two SHORT
// shocks (fuel spike, travel rush, pilot shortage…) come and go. Each
// multiplies one lever of the economy while it runs.

struct IndustryTrend: Codable, Identifiable, Equatable {
    let id: UUID
    var key: String            // template key (dedup on respawn)
    var name: String           // "Economic expansion"
    var detail: String         // one-line story for the UI
    var kind: Kind             // which lever it moves
    var horizon: Horizon
    var multiplier: Double     // applied to that lever while active
    var weeksRemaining: Int

    enum Kind: String, Codable {
        case demand            // route demand
        case fuel              // fuel price
        case wages             // wage bill (labor market premium)
        case aircraftPrices    // new orders, lease signings, used listings

        var label: String {
            switch self {
            case .demand: "demand"; case .fuel: "fuel"
            case .wages: "wages"; case .aircraftPrices: "aircraft prices"
            }
        }
    }
    enum Horizon: String, Codable { case short, long }

    /// Whether this trend helps the player (colors the UI): more demand is
    /// good; pricier fuel, wages, or metal is not.
    var favorsPlayer: Bool {
        kind == .demand ? multiplier >= 1 : multiplier < 1
    }
}

/// A card template in the deck (lives in Balance as data; eligibility
/// closures keep it out of the save — only fired GameEvents persist).
struct EventCard: Identifiable {
    let id: String
    let category: EventCategory
    let title: String
    let body: String
    /// Base draw weight; the engine shifts it by game state.
    let baseWeight: Double
    /// Negative cards respect the year-one guard rail.
    let isNegative: Bool
    /// Earliest week (total) this card can appear.
    let minTotalWeek: Int
    let options: [EventOption]
    /// Extra eligibility beyond minTotalWeek (fleet exists, strike risk…).
    let isEligible: (GameState) -> Bool
}

/// A fired choice card presented to the player (GDD §4.7).
struct GameEvent: Codable, Identifiable {
    let id: UUID
    var cardID: String
    var category: EventCategory
    var isNegative: Bool
    var title: String
    var body: String
    var options: [EventOption]
    var firedOn: GameDate
    /// The roster member at the center of the incident, when there is one
    /// (lawsuit cards, GDD §19). Optional for save-compat.
    var subjectID: UUID? = nil
    /// The aircraft model at the center of the incident, when there is one
    /// (recall cards, GDD §20). Optional for save-compat.
    var subjectAircraftType: AircraftType? = nil
}

struct EventOption: Codable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var effects: [EventEffect]
}

/// A line in the airline's history book: when a card fired and what it
/// was — drawn as rules on the finance charts (GDD §4.7).
struct EventLogEntry: Codable, Identifiable {
    let id: UUID
    var totalWeek: Int
    var title: String
    var isNegative: Bool
}

struct WeeklyReport: Codable, Identifiable {
    var id: UUID = UUID()
    var date: GameDate
    var revenue: Double
    var fuelCost: Double
    var wageCost: Double
    var maintenanceCost: Double
    var loanCost: Double
    var leaseCost: Double
    var cabinCost: Double        // interior upkeep + catering + wifi service
    var marketingCost: Double    // the M5 awareness budget
    var overheadCost: Double
    var profit: Double { revenue - fuelCost - wageCost - maintenanceCost - loanCost - leaseCost - cabinCost - marketingCost - overheadCost }
}

// ── The objectives layer (GDD §3.1 + §6, M6) ─────────────────────────────

/// Player-chosen difficulty (2026-07-18). Three levers, all multiplicative,
/// all 1.0 on standard so the calibrated balance IS standard. Optional in
/// GameState so pre-difficulty saves decode (nil reads as .standard).
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case relaxed, standard, tycoon
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed: "Relaxed"; case .standard: "Standard"; case .tycoon: "Tycoon"
        }
    }
    var blurb: String {
        switch self {
        case .relaxed: "Forgiving margins and a bigger fund. Fly for the fun of it."
        case .standard: "The calibrated game. Competent play wins the fund."
        case .tycoon: "Thin margins, smaller fund. Every seat has to earn."
        }
    }
    /// Starting cash multiplier.
    var startingCashFactor: Double {
        switch self { case .relaxed: 1.25; case .standard: 1.0; case .tycoon: 0.75 }
    }
    /// Route demand multiplier.
    var demandFactor: Double {
        switch self { case .relaxed: 1.10; case .standard: 1.0; case .tycoon: 0.93 }
    }
    /// Maintenance + lease + overhead multiplier.
    var costFactor: Double {
        switch self { case .relaxed: 0.90; case .standard: 1.0; case .tycoon: 1.10 }
    }
}

enum TrustFundResolution: String, Codable {
    case pending, succeeded, failed
}

/// A quarterly letter from Aunt Meera — the tutorial voice of years 1–3.
struct QuarterlyLetter: Codable, Identifiable {
    let id: UUID
    var date: GameDate
    var tone: Tone
    var quarterProfit: Double
    var body: String

    enum Tone: String, Codable {
        case proud, encouraging, worried, stern
        case triumphant     // the fund converts — arc complete
        case heartbroken    // the fund is withdrawn — hard mode
    }
}

/// A Layer-1 milestone definition (lives in Balance; completion ids
/// persist in the save). Contextual nudges with small cash rewards —
/// they never block anything.
struct MilestoneDef: Identifiable {
    let id: String
    let title: String
    let reward: Double
    let isComplete: (GameState) -> Bool

    /// Campaign-aware title: "{nation}" resolves to the campaign country's
    /// adjective, so no milestone can talk about the wrong market.
    func displayTitle(for country: Country) -> String {
        title.replacingOccurrences(of: "{nation}", with: country.adjective)
    }
}

/// One week of a route's economics, decomposed term by term — the tick
/// runs on this AND the UI explains from it, so the "tap any number"
/// breakdowns (design pillar 4) can never drift from the sim.
struct RouteEconomics {
    var gravity: Double          // k × (popA·popB)^0.55 / dist^0.35
    var growth: Double           // country demand growth compounding
    var season: Double           // ±20% sinusoidal
    var brand: Double            // reputation × awareness multiplier
    var eventDemand: Double      // timed event modifiers
    var referenceFare: Double
    var priceRatio: Double
    var priceResponse: Double
    var demand: Double
    var seatsOffered: Int
    var pax: Double
    var loadFactor: Double
    var revenue: Double
    var fuel: Double
    var fairness: Double         // the fare↔satisfaction link, 0...1
    /// Load factor needed for revenue to cover this route's fuel.
    var breakevenLoadFactor: Double
    // ── The route's market (GDD §21) ─────────────────────────────────────
    /// Rival carriers on this pair (0 = your monopoly).
    var competitors: Int = 0
    /// Endpoint affluence 0…1 (business-traveler share): affluent pairs
    /// weigh comfort over price; budget pairs the reverse.
    var affluence: Double = 0
    /// Your captured share of the pair's demand (1.0 on a monopoly).
    var captureShare: Double = 1
}

/// THE save file. Everything lives here; the engine mutates only this.
struct GameState: Codable {
    var saveVersion: Int = 1
    var seedRNG: SeededRandomNumberGenerator
    var date: GameDate
    var country: Country
    /// Optional so saves from before difficulty existed still decode.
    var difficulty: Difficulty? = nil
    var airlineName: String

    var cash: Double
    var livery: Livery
    var trustFundActive: Bool
    var trustFundDeadline: GameDate
    var trustFundResolution: TrustFundResolution
    var consecutiveProfitableQuarters: Int
    var reputation: Double            // 1...5 stars

    /// Marketing (GDD §4.8, M5): awareness 0–100, fed by weekly spend
    /// with diminishing returns, decaying ~3%/week without it.
    var brandAwareness: Double
    var weeklyMarketingSpend: Double

    /// The objectives layer (M6).
    var letters: [QuarterlyLetter]            // newest last, capped
    var completedMilestones: Set<String>
    /// Consecutive weeks with negative cash; 8 with no sellable assets = bankrupt.
    var weeksInsolvent: Int
    var isBankrupt: Bool

    var cities: [City]
    var fleet: [Aircraft]
    var routes: [Route]
    var staff: [StaffRole: StaffPool]
    var loans: [Loan]

    /// Rotating second-hand market (GDD §4.1): 3–5 seeded listings,
    /// refreshed every few weeks from the seeded RNG.
    var usedMarket: [UsedListing]
    var weeksUntilMarketRefresh: Int

    /// Recruitment (GDD §4.4 as amended): active job ads (weeks remaining
    /// per role) and the people who've applied so far.
    var jobPostings: [StaffRole: Int]
    var applicants: [JobApplicant]

    /// Factory-new orders per manufacturer — drives loyalty discounts.
    var sellerOrders: [String: Int]

    var pendingEvent: GameEvent?
    /// Running timed modifiers from resolved events (fuel spikes, demand
    /// surges) — applied every tick, aged in bookkeeping.
    var activeEffects: [TimedEffect]
    /// Industry trends in force (GDD §14). Optional for save-compat:
    /// pre-feature saves decode nil and the first settle seeds the regime.
    var industryTrends: [IndustryTrend]? = nil
    /// Guard rail: never two negative events in consecutive weeks in year 1.
    var lastNegativeEventTotalWeek: Int
    /// Pity-timer anchor: the last week ANY card fired (GDD §4.7 pacing).
    /// Optional for save-compat.
    var lastEventTotalWeek: Int? = nil
    /// Fired-event history (capped ~120) — the charts' event rules and the
    /// Major events list. Optional for save-compat.
    var eventLog: [EventLogEntry]? = nil
    var reports: [WeeklyReport]       // capped ring buffer (last 52)

    /// Per-week history buffers for trend charts, newest last
    /// (capped at 260 weeks = 5 in-game years).
    var netWorthHistory: [Double]
    var cashHistory: [Double]
    var reputationHistory: [Double]
}
