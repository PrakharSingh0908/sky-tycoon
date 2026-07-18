//
//  SkyTycoonApp.swift
//  SkyTycoon
//
//  App entry. The engine is created once (loaded from save, or a fresh
//  new game) and injected into the environment. Views are dumb renderers
//  of engine state.
//

import SwiftUI

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
