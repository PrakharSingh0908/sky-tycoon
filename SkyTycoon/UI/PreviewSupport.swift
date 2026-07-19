//
//  PreviewSupport.swift
//  SkyTycoon — UI previews
//
//  A seeded mid-game state so every design preview shows live-looking data:
//  two planes (one used clunker, one leased), two routes, a slightly
//  understaffed cabin crew (to surface warnings), 30 weeks of history.
//

import SwiftUI

extension GameEngine {
    static func previewGame() -> GameEngine {
        // §22: new games start at tier 0 with $200K. Previews need a
        // mid-game airline, so seed the state past the foundation era.
        var seeded = GameEngine.newGame(airlineName: "Aunt Air", country: .india,
                                        seed: 42).state
        seeded.unlockedFleetTier = Balance.maxFleetTier
        seeded.cash += 6_000_000
        let engine = GameEngine(state: seeded)
        engine.takeLoan(amount: 6_000_000)
        if let listing = engine.state.usedMarket.first(where: { $0.type == .propeller24 })
            ?? engine.state.usedMarket.first {
            _ = engine.buyUsedAircraft(listingID: listing.id, nickname: "VT-A")
        }
        _ = engine.leaseAircraft(type: .propeller24, nickname: "VT-B")
        let fare = Balance.distance("DEL", "BOM") * Balance.referenceFarePerKm
            * Balance.countryProfiles[.india]!.fareLevel
        if let route = engine.openRoute(from: "DEL", to: "BOM", fare: fare, frequency: 14) {
            engine.assign(aircraftID: engine.state.fleet[0].id, to: route.id)
        }
        _ = engine.openRoute(from: "BOM", to: "BLR", fare: 60, frequency: 7)
        engine.setHeadcount(role: .pilots, count: 4)
        engine.setHeadcount(role: .cabinCrew, count: 2)   // understaffed: shows warnings
        engine.setHeadcount(role: .ground, count: 4)
        for _ in 0..<30 { engine.advanceWeek() }
        // A live job ad with fresh applicants, so People previews show them.
        engine.postJobAd(role: .pilots)
        engine.advanceWeek()
        if let event = engine.state.pendingEvent {
            engine.resolveEvent(option: event.options[0])
        }
        return engine
    }
}
