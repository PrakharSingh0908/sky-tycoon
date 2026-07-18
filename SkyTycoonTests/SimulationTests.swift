//
//  SimulationTests.swift
//  SkyTycoonTests
//
//  Milestone 0 tests (MVP_BACKLOG.md):
//  1. Determinism — two engines, same seed, same scripted actions, identical
//     cash and full sim state after 100 advanceWeek() calls. Green forever.
//  2. Save-file versioning smoke test — encode → decode → re-encode is stable.
//  3. Aircraft aging — ageYears advances 1/52 per tick (the M0 fix).
//

import Testing
import Foundation
@testable import SkyTycoon

@MainActor
@Suite struct SimulationTests {

    /// Builds an engine with a fixed seed and runs the same scripted first
    /// moves every time: loan → lease turboprop → open DEL–BOM → assign.
    /// (Lease, not buy: it's instant and needs no listing lookup, so the
    /// script is identical for every seed.)
    private func makeScriptedEngine(seed: UInt64) -> GameEngine {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: seed)
        engine.takeLoan(amount: 5_000_000)
        #expect(engine.leaseAircraft(type: .turboprop10, nickname: "TEST-1"))
        let route = engine.openRoute(from: "DEL", to: "BOM", fare: 100, frequency: 14)
        #expect(route != nil)
        engine.assign(aircraftID: engine.state.fleet[0].id, to: route!.id)
        return engine
    }

    /// Every sim-relevant number in GameState, in a stable order.
    /// (We can't byte-compare encoded state across two engines because
    /// Aircraft/Route/Loan ids use unseeded UUID() — a known, tracked
    /// backlog item. UUIDs never feed the sim math, so this fingerprint
    /// IS the full sim state.)
    private func fingerprint(_ engine: GameEngine) -> [Double] {
        let s = engine.state
        var f: [Double] = [
            s.cash, s.reputation, Double(s.date.totalWeeks),
            Double(s.consecutiveProfitableQuarters),
            s.trustFundActive ? 1 : 0,
            Double(s.loans.count), Double(s.reports.count),
            s.pendingEvent == nil ? 0 : 1,
        ]
        for plane in s.fleet {
            f += [plane.wear, plane.condition, plane.ageYears,
                  plane.cabin.seatPitchInches, plane.cabin.seatWidthInches,
                  Double(plane.cabin.galleyUnits), plane.cabin.hasWifi ? 1 : 0,
                  Double(plane.groundedWeeksRemaining),
                  plane.weeklyLeaseCost, Double(plane.deliveryWeeksRemaining)]
        }
        for (seller, orders) in s.sellerOrders.sorted(by: { $0.key < $1.key }) {
            f += [Double(seller.count), Double(orders)]
        }
        for listing in s.usedMarket {
            f += [listing.ageYears, listing.condition, listing.price]
        }
        f.append(Double(s.weeksUntilMarketRefresh))
        for route in s.routes {
            f += [route.satisfaction, route.lastLoadFactor, route.lastWeeklyProfit,
                  route.fare, Double(route.weeklyFrequency), route.lastPunctuality]
            f += route.loadFactorHistory
        }
        for role in StaffRole.allCases {
            if let pool = s.staff[role] {
                f += [Double(pool.headcount), pool.weeklyWage, pool.happiness,
                      pool.skill, pool.lastUtilization]
            }
        }
        for loan in s.loans { f += [loan.remaining, loan.weeklyPayment] }
        for applicant in s.applicants {
            f += [applicant.skill, applicant.askingWage, applicant.flexibility,
                  applicant.irritation, Double(applicant.weeksRemaining)]
        }
        for role in StaffRole.allCases { f.append(Double(s.jobPostings[role] ?? -1)) }
        for effect in s.activeEffects {
            f += [effect.multiplier, Double(effect.weeksRemaining)]
        }
        f.append(Double(s.lastNegativeEventTotalWeek))
        f += s.netWorthHistory
        f += s.cashHistory
        f += s.reputationHistory
        f += s.reports.map(\.profit)
        return f
    }

    // ── 1. Determinism ───────────────────────────────────────────────────

    @Test func sameSeedSameActionsIdenticalStateAfter100Weeks() {
        let a = makeScriptedEngine(seed: 42)
        let b = makeScriptedEngine(seed: 42)
        for _ in 0..<100 {
            a.advanceWeek()
            b.advanceWeek()
        }
        #expect(a.state.cash == b.state.cash)
        #expect(fingerprint(a) == fingerprint(b))
    }

    @Test func differentSeedsDiverge() {
        // Sanity check that the fingerprint actually discriminates: different
        // seeds fire events on different weeks, so states should differ.
        let a = makeScriptedEngine(seed: 1)
        let b = makeScriptedEngine(seed: 99999)
        for _ in 0..<100 {
            a.advanceWeek()
            b.advanceWeek()
        }
        #expect(fingerprint(a) != fingerprint(b))
    }

    // ── 2. Save-file round trip ──────────────────────────────────────────

    @Test func saveRoundTripIsStable() throws {
        let engine = makeScriptedEngine(seed: 7)
        for _ in 0..<20 { engine.advanceWeek() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys   // stable byte output

        let first = try encoder.encode(engine.state)
        let decoded = try JSONDecoder().decode(GameState.self, from: first)
        let second = try encoder.encode(decoded)

        #expect(first == second)
        #expect(decoded.saveVersion == engine.state.saveVersion)
    }

    // ── 3. M0 fixes stay fixed ───────────────────────────────────────────

    @Test func aircraftAgeAdvancesWeekly() {
        let engine = makeScriptedEngine(seed: 3)
        #expect(engine.state.fleet[0].ageYears == 0)
        for _ in 0..<52 { engine.advanceWeek() }
        // 52 ticks × 1/52 per tick ≈ 1 year.
        #expect(abs(engine.state.fleet[0].ageYears - 1.0) < 0.001)
    }

    @Test func assignRejectsRouteBeyondRange() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 5)
        #expect(engine.leaseAircraft(type: .turboprop5, nickname: "TEST-1"))
        // DEL–MAA is 1770 km; the 5-window turboprop's range is 1,450 km.
        let route = engine.openRoute(from: "DEL", to: "MAA", fare: 100, frequency: 7)
        #expect(route != nil)
        engine.assign(aircraftID: engine.state.fleet[0].id, to: route!.id)
        #expect(engine.state.routes[0].assignedAircraftIDs.isEmpty)
        #expect(engine.state.fleet[0].status == .idle)
    }

    @Test func canOperateAndUnassignFromFleet() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 6)
        #expect(engine.leaseAircraft(type: .turboprop5, nickname: "TEST-1"))   // 1,450 km range
        let plane = engine.state.fleet[0]
        let short = engine.openRoute(from: "DEL", to: "BOM", fare: 100, frequency: 7)!   // 1,150 km
        let far = engine.openRoute(from: "DEL", to: "GOI", fare: 100, frequency: 7)!     // 1,520 km
        #expect(engine.canOperate(aircraftID: plane.id, routeID: short.id))
        #expect(!engine.canOperate(aircraftID: plane.id, routeID: far.id))

        engine.assign(aircraftID: plane.id, to: short.id)
        #expect(engine.state.fleet[0].assignedRouteID == short.id)
        engine.unassign(aircraftID: plane.id)
        #expect(engine.state.fleet[0].assignedRouteID == nil)
        #expect(engine.state.fleet[0].status == .idle)
        #expect(engine.state.routes[0].assignedAircraftIDs.isEmpty)
    }

    // ── 4. Milestone 1 — fleet acquisition ───────────────────────────────

    @Test func newOrderDeliversAfterWait() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 11)
        engine.takeLoan(amount: 20_000_000)
        #expect(engine.orderNewAircraft(type: .turboprop12, nickname: "TEST-1"))
        let plane = engine.state.fleet[0]
        #expect(plane.status == .onOrder)
        #expect(plane.deliveryWeeksRemaining == Balance.deliveryWeeks[.turboprop12]!)

        // Undelivered planes can't be assigned.
        let route = engine.openRoute(from: "DEL", to: "BOM", fare: 100, frequency: 7)!
        engine.assign(aircraftID: plane.id, to: route.id)
        #expect(engine.state.routes[0].assignedAircraftIDs.isEmpty)

        for _ in 0..<Balance.deliveryWeeks[.turboprop12]! { engine.advanceWeek() }
        #expect(engine.state.fleet[0].status == .idle)
        // Delivery week counts don't age the airframe.
        #expect(engine.state.fleet[0].ageYears < 0.001)
    }

    @Test func usedMarketIsSeededAndRefreshes() {
        let a = GameEngine.newGame(airlineName: "A", country: .india, seed: 77)
        let b = GameEngine.newGame(airlineName: "B", country: .india, seed: 77)
        #expect((Balance.usedMarketMinListings...Balance.usedMarketMaxListings)
            .contains(a.state.usedMarket.count))
        // Same seed → identical listings (content, not UUIDs).
        #expect(a.state.usedMarket.map(\.price) == b.state.usedMarket.map(\.price))
        #expect(a.state.usedMarket.map(\.condition) == b.state.usedMarket.map(\.condition))

        // Prices stay inside the GDD's 30–60%-of-new band.
        for listing in a.state.usedMarket {
            let newPrice = Balance.specs[listing.type]!.purchasePrice
            #expect(listing.price >= newPrice * 0.30 - 0.01)
            #expect(listing.price <= newPrice * 0.60 + 0.01)
        }

        // The market rotates after the refresh interval — deterministically.
        let before = a.state.usedMarket.map(\.price)
        for _ in 0..<Balance.usedMarketRefreshWeeksMax { a.advanceWeek(); b.advanceWeek() }
        #expect(a.state.usedMarket.map(\.price) != before)
        #expect(a.state.usedMarket.map(\.price) == b.state.usedMarket.map(\.price))
    }

    @Test func buyUsedTakesListingOffMarket() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 21)
        engine.takeLoan(amount: 60_000_000)
        let listing = engine.state.usedMarket[0]
        #expect(engine.buyUsedAircraft(listingID: listing.id, nickname: "TEST-U"))
        #expect(!engine.state.usedMarket.contains(where: { $0.id == listing.id }))
        let plane = engine.state.fleet[0]
        #expect(plane.acquisition == .ownedUsed)
        #expect(plane.condition == listing.condition)
        #expect(plane.ageYears == listing.ageYears)
        #expect(plane.status == .idle)   // instant delivery
    }

    @Test func leaseChargesWeeklyAndReturnChargesFee() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 31)
        #expect(engine.leaseAircraft(type: .turboprop12, nickname: "TEST-L"))
        let weekly = Balance.specs[.turboprop12]!.purchasePrice * Balance.leaseRatePerWeek
        #expect(engine.state.fleet[0].weeklyLeaseCost == weekly)

        engine.advanceWeek()
        #expect(engine.latestReport!.leaseCost == weekly)

        // Leased planes can't be sold; returning charges 4 weeks of payments.
        #expect(!engine.sellAircraft(aircraftID: engine.state.fleet[0].id))
        let cashBefore = engine.state.cash
        #expect(engine.returnLeasedAircraft(aircraftID: engine.state.fleet[0].id))
        #expect(engine.state.cash == cashBefore - weekly * Balance.leaseTerminationWeeks)
        #expect(engine.state.fleet.isEmpty)
    }

    @Test func sellReturnsDepreciatedValue() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 41)
        engine.takeLoan(amount: 60_000_000)
        let listing = engine.state.usedMarket[0]
        #expect(engine.buyUsedAircraft(listingID: listing.id, nickname: "TEST-U"))
        let plane = engine.state.fleet[0]
        let expected = Balance.resaleValue(type: plane.type, ageYears: plane.ageYears,
                                           condition: plane.condition)
        let cashBefore = engine.state.cash
        #expect(engine.sellAircraft(aircraftID: plane.id))
        #expect(abs(engine.state.cash - (cashBefore + expected)) < 0.01)
        #expect(engine.state.fleet.isEmpty)
    }

    @Test func checksCannotBeOrderedOnUndeliveredPlanes() {
        // Regression: orderCheck on an .onOrder plane flipped it to
        // .inMaintenance, and the maintenance countdown then released it to
        // service early — a delivery-skip exploit.
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 51)
        engine.takeLoan(amount: 20_000_000)
        #expect(engine.orderNewAircraft(type: .turboprop12, nickname: "TEST-1"))
        let cashBefore = engine.state.cash
        engine.orderCheck(aircraftID: engine.state.fleet[0].id, heavy: false)
        #expect(engine.state.fleet[0].status == .onOrder)   // unchanged
        #expect(engine.state.cash == cashBefore)            // not charged
    }

    // ── 5. Economy viability (the game must be winnable) ─────────────────

    @Test func workhorsePropOnTrunkRouteIsProfitable() {
        // The workhorse case — a 30 Propeller on a trunk route at reference
        // fare — must be route-level profitable over its first year, and
        // load factors must be in a healthy band. If a balance change
        // breaks this, the trust-fund arc is unwinnable and the 2-hour
        // test fails in minute five. This test is the guard.
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 61)
        engine.takeLoan(amount: 30_000_000)
        #expect(engine.orderNewAircraft(type: .propeller30, nickname: "TEST-1"))

        let profile = Balance.countryProfiles[.india]!
        let referenceFare = Balance.distance("DEL", "BOM") * Balance.referenceFarePerKm * profile.fareLevel
        let route = engine.openRoute(from: "DEL", to: "BOM", fare: referenceFare, frequency: 14)!
        engine.assign(aircraftID: engine.state.fleet[0].id, to: route.id)

        // Deliver, then fly a full year (covers the seasonality trough).
        for _ in 0..<Balance.deliveryWeeks[.propeller30]! { engine.advanceWeek() }
        engine.assign(aircraftID: engine.state.fleet[0].id, to: route.id)
        var routeProfits: [Double] = []
        var loadFactors: [Double] = []
        for _ in 0..<52 {
            engine.advanceWeek()
            routeProfits.append(engine.state.routes[0].lastWeeklyProfit)
            loadFactors.append(engine.state.routes[0].lastLoadFactor)
        }

        let avgRouteProfit = routeProfits.reduce(0, +) / Double(routeProfits.count)
        let avgLoadFactor = loadFactors.reduce(0, +) / Double(loadFactors.count)
        #expect(avgRouteProfit > 0, "trunk route must clear fuel costs on average")
        #expect(avgLoadFactor > 0.5, "planes should be more than half full at reference fare")
        #expect(avgLoadFactor < 1.0, "demand shouldn't be so high that pricing is irrelevant")
    }

    @Test func leasedTurbopropIsViableButWorseThanOwned() {
        // GDD §4.1: leasing is "the safest first plane", so a well-run
        // leased turboprop must at least roughly break even — while staying
        // clearly worse than owning (the cash-flow-vs-equity tradeoff).
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 71)
        #expect(engine.leaseAircraft(type: .propeller24, nickname: "TEST-L"))
        let profile = Balance.countryProfiles[.india]!
        let referenceFare = Balance.distance("DEL", "BOM") * Balance.referenceFarePerKm * profile.fareLevel
        let route = engine.openRoute(from: "DEL", to: "BOM", fare: referenceFare, frequency: 14)!
        engine.assign(aircraftID: engine.state.fleet[0].id, to: route.id)

        var routeProfits: [Double] = []
        for _ in 0..<52 {
            engine.advanceWeek()
            routeProfits.append(engine.state.routes[0].lastWeeklyProfit)
        }
        let avgRouteProfit = routeProfits.reduce(0, +) / Double(routeProfits.count)
        let weeklyLease = engine.state.fleet.first?.weeklyLeaseCost
            ?? Balance.specs[.propeller24]!.purchasePrice * Balance.leaseRatePerWeek

        // Route margin must cover the lease payment (≈ break even before
        // overhead), but not by so much that owning is pointless.
        #expect(avgRouteProfit > weeklyLease, "leased first plane must be able to cover its lease")
        #expect(avgRouteProfit < weeklyLease * 4, "leasing shouldn't dominate owning")
    }

    // ── 6. Milestone 2 — crews, understaffing, satisfaction ─────────────

    @Test func understaffingHurtsPunctualityAndCostsOvertime() {
        // The M2 exit criterion: hiring nobody and flying anyway must
        // visibly hurt punctuality and satisfaction — and cost overtime.
        func run(hire: Bool) -> GameEngine {
            let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 81)
            _ = engine.leaseAircraft(type: .turboprop12, nickname: "L")
            let fare = Balance.distance("DEL", "BOM") * Balance.referenceFarePerKm
                * Balance.countryProfiles[.india]!.fareLevel
            let route = engine.openRoute(from: "DEL", to: "BOM", fare: fare, frequency: 14)!
            engine.assign(aircraftID: engine.state.fleet[0].id, to: route.id)
            if hire {
                engine.setHeadcount(role: .pilots, count: 4)
                engine.setHeadcount(role: .cabinCrew, count: 4)
                engine.setHeadcount(role: .ground, count: 4)
            }
            for _ in 0..<12 { engine.advanceWeek() }
            return engine
        }
        let staffed = run(hire: true)
        let unstaffed = run(hire: false)

        #expect(unstaffed.state.routes[0].lastPunctuality
              < staffed.state.routes[0].lastPunctuality - 0.2)
        #expect(unstaffed.state.routes[0].satisfaction
              < staffed.state.routes[0].satisfaction)
        // Contractors covered the flying — at a price. HQ (3 heads) is the
        // only base wage bill, so anything above it is overtime.
        let hqWages = 3 * unstaffed.state.staff[.hq]!.weeklyWage
        #expect(unstaffed.latestReport!.wageCost > hqWages)
        // The UI can explain why: pools show >100% utilization.
        #expect(unstaffed.state.staff[.pilots]!.lastUtilization > 1.0)
    }

    @Test func overworkedPoolsLoseHappinessThenPeople() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 91)
        _ = engine.leaseAircraft(type: .propeller24, nickname: "L")
        let fare = Balance.distance("DEL", "BOM") * Balance.referenceFarePerKm
            * Balance.countryProfiles[.india]!.fareLevel
        let route = engine.openRoute(from: "DEL", to: "BOM", fare: fare, frequency: 28)!
        engine.assign(aircraftID: engine.state.fleet[0].id, to: route.id)
        // 5 pilots for ~308 pilot-hours of flying: 54% over roster, at
        // market wage — pay alone would hold happiness at 50.
        engine.setHeadcount(role: .pilots, count: 5)
        for _ in 0..<60 { engine.advanceWeek() }
        let pilots = engine.state.staff[.pilots]!
        #expect(pilots.happiness < Balance.attritionHappinessThreshold)
        #expect(pilots.headcount < 5, "chronic overwork should cause attrition")
    }

    // ── 6b. Loyalty discounts & the cabin architect ──────────────────────

    @Test func repeatOrdersEarnLoyaltyDiscounts() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 161)
        engine.takeLoan(amount: 40_000_000)
        let type = AircraftType.turboprop5
        let seller = Balance.specs[type]!.seller
        #expect(engine.loyaltyDiscount(seller: seller) == 0)

        let fullPrice = Balance.specs[type]!.purchasePrice
        #expect(engine.orderNewAircraft(type: type, nickname: "T1"))
        #expect(engine.loyaltyDiscount(seller: seller) == Balance.loyaltyDiscountPerOrder)

        // Second order from the same seller is charged 3% less.
        let cashBefore = engine.state.cash
        #expect(engine.orderNewAircraft(type: type, nickname: "T2"))
        let charged = cashBefore - engine.state.cash
        #expect(abs(charged - fullPrice * (1 - Balance.loyaltyDiscountPerOrder)) < 0.01)

        // Discount is per seller, and capped.
        #expect(engine.loyaltyDiscount(seller: "Meridian Jets") == 0)
        for i in 0..<6 { engine.orderNewAircraft(type: type, nickname: "T\(i + 3)") }
        #expect(engine.loyaltyDiscount(seller: seller) <= Balance.loyaltyDiscountCap)
    }

    @Test func cabinChoicesTradeSeatsComfortAndCost() {
        let spec = Balance.specs[.propeller30]!   // 96 dense seats, 4 abreast
        let dense = CabinLayout(seatPitchInches: 28, seatWidthInches: 16,
                                material: .economy, galleyUnits: 0, hasWifi: false)
        let plush = CabinLayout(seatPitchInches: 36, seatWidthInches: 20,
                                material: .luxury, galleyUnits: 2, hasWifi: true)
        #expect(dense.seats(spec: spec) > plush.seats(spec: spec))
        #expect(plush.comfort > dense.comfort)
        #expect(plush.weeklyUpkeep(spec: spec) > dense.weeklyUpkeep(spec: spec))
        // Galleys displace one row each.
        var withOvens = dense
        withOvens.galleyUnits = 2
        #expect(withOvens.seats(spec: spec) == dense.seats(spec: spec) - 2 * dense.seatsAbreast(spec: spec))
    }

    @Test func refittingCostsMoneyAndGroundsThePlane() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 171)
        #expect(engine.leaseAircraft(type: .propeller24, nickname: "L"))
        var layout = engine.state.fleet[0].cabin
        layout.material = .premium
        layout.seatPitchInches = 32
        let cost = layout.refitCost(spec: Balance.specs[.propeller24]!)
        let cashBefore = engine.state.cash
        #expect(engine.refitCabin(aircraftID: engine.state.fleet[0].id, layout: layout))
        #expect(abs(cashBefore - engine.state.cash - cost) < 0.01)
        #expect(engine.state.fleet[0].status == .inMaintenance)
        #expect(engine.state.fleet[0].groundedWeeksRemaining == Balance.cabinRefitWeeks)
        // No refitting while the crew is still in there.
        #expect(!engine.refitCabin(aircraftID: engine.state.fleet[0].id,
                                   layout: .standard(abreast: 4)))
    }

    @Test func exitLimitIsAHardCap() {
        // No cabin layout may exceed the airframe's certified exit limit —
        // sweep every archetype at the densest possible configuration.
        let sardine = CabinLayout(seatPitchInches: 28, seatWidthInches: 16,
                                  material: .economy, galleyUnits: 0, hasWifi: false)
        for type in AircraftType.allCases {
            let spec = Balance.specs[type]!
            #expect(sardine.seats(spec: spec) <= spec.maxSeats,
                    "\(spec.displayName) exceeded its exit limit")
        }
    }

    @Test func denseCabinsFlyShorterAiryCabinsReachFurther() {
        // Payload-range: an 8 Turboprop (1,780 km brochure) can't make
        // DEL–MAA (1,770 km) with its standard cabin — but strip it to an
        // airy "ferry" layout and it can.
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 181)
        engine.takeLoan(amount: 3_000_000)
        #expect(engine.leaseAircraft(type: .turboprop8, nickname: "L"))
        let plane = engine.state.fleet[0]
        let route = engine.openRoute(from: "DEL", to: "MAA", fare: 100, frequency: 7)!
        #expect(!engine.canOperate(aircraftID: plane.id, routeID: route.id),
                "standard cabin should be too heavy for 1,770 km")

        let ferry = CabinLayout(seatPitchInches: 36, seatWidthInches: 20,
                                material: .economy, galleyUnits: 0, hasWifi: false)
        #expect(engine.refitCabin(aircraftID: plane.id, layout: ferry))
        #expect(engine.canOperate(aircraftID: plane.id, routeID: route.id),
                "airy cabin should stretch the range past 1,770 km")

        // And the ordering always holds.
        let spec = Balance.specs[.turboprop8]!
        let dense = CabinLayout(seatPitchInches: 28, seatWidthInches: 16,
                                material: .economy, galleyUnits: 0, hasWifi: false)
        #expect(dense.rangeFactor(spec: spec) < ferry.rangeFactor(spec: spec))
    }

    @Test func refittingHeavierUnassignsAnUnreachableRoute() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 191)
        engine.takeLoan(amount: 3_000_000)
        #expect(engine.leaseAircraft(type: .turboprop8, nickname: "L"))
        let plane = engine.state.fleet[0]
        let route = engine.openRoute(from: "DEL", to: "MAA", fare: 100, frequency: 7)!

        // Ferry cabin reaches; assign; then refit dense — the engine must
        // pull the plane off the now-impossible route.
        let ferry = CabinLayout(seatPitchInches: 36, seatWidthInches: 20,
                                material: .economy, galleyUnits: 0, hasWifi: false)
        #expect(engine.refitCabin(aircraftID: plane.id, layout: ferry))
        // Wait out the refit grounding so assignment is meaningful.
        while engine.state.fleet[0].groundedWeeksRemaining > 0 { engine.advanceWeek() }
        engine.assign(aircraftID: plane.id, to: route.id)
        #expect(engine.state.fleet[0].assignedRouteID == route.id)

        let dense = CabinLayout(seatPitchInches: 28, seatWidthInches: 16,
                                material: .economy, galleyUnits: 0, hasWifi: false)
        #expect(engine.refitCabin(aircraftID: plane.id, layout: dense))
        #expect(engine.state.fleet[0].assignedRouteID == nil,
                "refit made the route unreachable — the plane must be unassigned")
        #expect(engine.state.routes[0].assignedAircraftIDs.isEmpty)
    }

    @Test func rivalManufacturerLoyaltyIsSeparate() {
        // "II" airframes are Kestrel's — buying Northline props earns no
        // discount on the Kestrel equivalent, and vice versa.
        #expect(Balance.specs[.propeller24]!.seller == "Northline Regional")
        #expect(Balance.specs[.propeller24II]!.seller == "Kestrel Aeronautics")
        #expect(Balance.specs[.jet60II]!.seller == "Kestrel Aeronautics")
        // Kestrel's wedge sizes compete between Meridian's rungs.
        #expect(Balance.specs[.jet24]!.seller == "Meridian Jets")
        #expect(Balance.specs[.jet26]!.seller == "Kestrel Aeronautics")
        #expect(Balance.specs[.jet29]!.seller == "Kestrel Aeronautics")
        #expect(Balance.specs[.widebody65]!.seller == "Meridian Jets")

        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 201)
        engine.takeLoan(amount: 60_000_000)
        #expect(engine.orderNewAircraft(type: .propeller24, nickname: "N1"))
        #expect(engine.loyaltyDiscount(seller: "Northline Regional") > 0)
        #expect(engine.loyaltyDiscount(seller: "Kestrel Aeronautics") == 0)
    }

    // ── 6c. Milestone 3 — the event deck ─────────────────────────────────

    @Test func eventDrawsAreDeterministicAcrossEngines() {
        // Same seed, same scripted resolutions (always option 0) → identical
        // event history and full state after 80 weeks.
        func run() -> GameEngine {
            let engine = makeScriptedEngine(seed: 555)
            for _ in 0..<80 {
                engine.advanceWeek()
                if let event = engine.state.pendingEvent {
                    engine.resolveEvent(option: event.options[0])
                }
            }
            return engine
        }
        let a = run(), b = run()
        #expect(fingerprint(a) == fingerprint(b))
    }

    @Test func eventsActuallyFire() {
        let engine = makeScriptedEngine(seed: 555)
        var fired = 0
        for _ in 0..<104 {
            engine.advanceWeek()
            if let event = engine.state.pendingEvent {
                fired += 1
                engine.resolveEvent(option: event.options.last!)
            }
        }
        // ~16%/week over 2 years minus the grace period: expect a healthy count.
        #expect(fired >= 5, "the deck should produce regular events (got \(fired))")
    }

    @Test func wornFleetsAttractTechnicalCards() {
        let engine = makeScriptedEngine(seed: 565)
        let faultCard = Balance.eventDeck.first { $0.id == "faultFound" }!
        let freshWeight = engine.eventWeight(for: faultCard)
        // Run unmaintained for a year — wear piles up.
        for _ in 0..<52 {
            engine.advanceWeek()
            if let event = engine.state.pendingEvent {
                engine.resolveEvent(option: event.options[0])
            }
        }
        #expect(engine.state.fleet[0].wear > 50)
        #expect(engine.eventWeight(for: faultCard) > freshWeight * 1.5,
                "high wear should raise technical card weight substantially")
    }

    @Test func yearOneGuardRailBlocksConsecutiveNegatives() {
        let engine = makeScriptedEngine(seed: 575)
        for _ in 0..<10 { engine.advanceWeek() }   // past minTotalWeek gates
        if let pending = engine.state.pendingEvent {
            engine.resolveEvent(option: pending.options[0])
        }
        // Force a negative card, then check the very next week's pool.
        let spike = Balance.eventDeck.first { $0.id == "fuelSpike" }!
        engine.present(spike)
        engine.resolveEvent(option: engine.state.pendingEvent!.options[0])
        engine.advanceWeek()
        let pool = engine.eligibleCards()
        #expect(!pool.isEmpty)
        #expect(pool.allSatisfy { !$0.isNegative },
                "the week after a negative event in year 1, only positive cards may fire")
    }

    @Test func timedEffectsApplyAndExpire() {
        let engine = makeScriptedEngine(seed: 585)
        engine.setHeadcount(role: .pilots, count: 4)
        engine.setHeadcount(role: .cabinCrew, count: 4)
        engine.setHeadcount(role: .ground, count: 4)
        for _ in 0..<8 { engine.advanceWeek() }
        if let pending = engine.state.pendingEvent {
            engine.resolveEvent(option: pending.options[0])
        }
        let baselineFuel = engine.latestReport!.fuelCost
        #expect(baselineFuel > 0)

        // Ride out a fuel spike: +30% for 6 weeks, then back to normal.
        let spike = Balance.eventDeck.first { $0.id == "fuelSpike" }!
        engine.present(spike)
        engine.resolveEvent(option: engine.state.pendingEvent!.options[1])   // ride it out
        #expect(engine.state.activeEffects.count == 1)

        engine.advanceWeek()
        if engine.state.pendingEvent != nil {   // another card may fire; clear it neutrally
            engine.resolveEvent(option: engine.state.pendingEvent!.options.last!)
        }
        let spikedFuel = engine.latestReport!.fuelCost
        #expect(spikedFuel > baselineFuel * 1.2,
                "fuel cost should jump ~30% while the spike is active")

        for _ in 0..<7 {
            engine.advanceWeek()
            if let event = engine.state.pendingEvent {
                engine.resolveEvent(option: event.options.last!)
            }
        }
        #expect(engine.state.activeEffects.isEmpty, "the spike should expire after 6 weeks")
    }

    @Test func groundingEffectSendsAPlaneToTheShop() {
        let engine = makeScriptedEngine(seed: 595)
        let fault = Balance.eventDeck.first { $0.id == "faultFound" }!
        engine.present(fault)
        let cashBefore = engine.state.cash
        engine.resolveEvent(option: engine.state.pendingEvent!.options[0])   // fix now
        #expect(engine.state.fleet[0].status == .inMaintenance)
        #expect(engine.state.fleet[0].groundedWeeksRemaining == 1)
        #expect(engine.state.cash == cashBefore - 80_000)
    }

    // ── 7. Recruitment — job ads, applicants, negotiation ────────────────

    @Test func jobAdAttractsApplicantsDeterministically() {
        let a = GameEngine.newGame(airlineName: "A", country: .india, seed: 111)
        let b = GameEngine.newGame(airlineName: "B", country: .india, seed: 111)
        for engine in [a, b] {
            #expect(engine.postJobAd(role: .pilots))
            #expect(!engine.postJobAd(role: .pilots))   // one ad at a time
            for _ in 0..<3 { engine.advanceWeek() }
        }
        #expect(!a.state.applicants.isEmpty, "an ad should attract applicants")
        #expect(a.state.applicants.map(\.askingWage) == b.state.applicants.map(\.askingWage))
        #expect(a.state.applicants.map(\.skill) == b.state.applicants.map(\.skill))
    }

    @Test func hiringBlendsIntoThePool() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 121)
        engine.postJobAd(role: .pilots)
        while engine.state.applicants.isEmpty { engine.advanceWeek() }
        let applicant = engine.state.applicants[0]
        #expect(engine.hireApplicant(applicantID: applicant.id))
        let pool = engine.state.staff[.pilots]!
        #expect(pool.headcount == 1)
        // First hire into an empty pool sets its wage and skill outright.
        #expect(abs(pool.weeklyWage - applicant.askingWage) < 0.01)
        #expect(abs(pool.skill - applicant.skill) < 0.01)
        #expect(!engine.state.applicants.contains(where: { $0.id == applicant.id }))
    }

    @Test func meetingTheAskingWageHiresOnTheSpot() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 131)
        engine.postJobAd(role: .cabinCrew)
        while engine.state.applicants.isEmpty { engine.advanceWeek() }
        let applicant = engine.state.applicants[0]
        let outcome = engine.negotiate(applicantID: applicant.id, offer: applicant.askingWage)
        #expect(outcome == .accepted)
        #expect(engine.state.staff[.cabinCrew]!.headcount == 1)
    }

    @Test func repeatedLowballsMakeApplicantsWalk() {
        // Two 40% offers push irritation past 100 — guaranteed walk,
        // regardless of the applicant's hidden flexibility.
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 141)
        engine.postJobAd(role: .ground)
        while engine.state.applicants.isEmpty { engine.advanceWeek() }
        let applicant = engine.state.applicants[0]
        let first = engine.negotiate(applicantID: applicant.id, offer: applicant.askingWage * 0.4)
        #expect(first != .accepted)
        if first != .walkedAway {   // stubborn-and-insulted may already have left
            let asking = engine.state.applicants.first { $0.id == applicant.id }!.askingWage
            let second = engine.negotiate(applicantID: applicant.id, offer: asking * 0.4)
            #expect(second == .walkedAway)
        }
        #expect(!engine.state.applicants.contains(where: { $0.id == applicant.id }))
        #expect(engine.state.staff[.ground]!.headcount == 0)
    }

    @Test func unansweredApplicantsTakeOtherJobs() {
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 151)
        engine.postJobAd(role: .hq)
        let horizon = Balance.jobPostingWeeks + Balance.applicantPatienceWeeksMax + 1
        for _ in 0..<horizon { engine.advanceWeek() }
        #expect(engine.state.applicants.isEmpty, "everyone should have moved on")
        #expect(engine.state.jobPostings[.hq] == nil, "the ad should have expired")
    }

    @Test func airportSlotsAreEnforced() {
        // Pune has 30 weekly slots. A 28/wk route leaves 2 free.
        let engine = GameEngine.newGame(airlineName: "TestAir", country: .india, seed: 101)
        let r1 = engine.openRoute(from: "DEL", to: "PNQ", fare: 80, frequency: 28)!
        #expect(engine.state.routes[0].weeklyFrequency == 28)
        let r2 = engine.openRoute(from: "BOM", to: "PNQ", fare: 30, frequency: 7)!
        #expect(engine.state.routes[1].weeklyFrequency == 2, "clamped to Pune's 2 free slots")
        // Editing frequency respects the same cap.
        engine.setFrequency(routeID: r2.id, frequency: 10)
        #expect(engine.state.routes[1].weeklyFrequency == 2)
        // Freeing slots on one route makes them available to the other.
        engine.setFrequency(routeID: r1.id, frequency: 14)
        engine.setFrequency(routeID: r2.id, frequency: 10)
        #expect(engine.state.routes[1].weeklyFrequency == 10)
    }

    @Test func usedStarterPlanesReachableOnDayOneInIndia() {
        // Backlog M1 balance requirement: a used starter plane + one loan
        // must be reachable on day one in India (~$2.4M start + the $5M loan
        // button). The small turboprops must be comfortably affordable, and
        // even the 24 Propeller's cheap end should be in reach.
        let profile = Balance.countryProfiles[.india]!
        let dayOneBudget = profile.startingTrustFund + profile.startingSavings + 5_000_000
        for type in [AircraftType.turboprop5, .turboprop8] {
            #expect(dayOneBudget >= Balance.specs[type]!.purchasePrice * 0.60)
        }
        #expect(dayOneBudget >= Balance.specs[.propeller24]!.purchasePrice * 0.40)
    }
}
