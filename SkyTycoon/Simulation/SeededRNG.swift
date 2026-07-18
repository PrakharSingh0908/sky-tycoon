//
//  SeededRNG.swift
//  SkyTycoon — Simulation core (pure Swift, no SwiftUI)
//
//  Determinism via a seeded RNG. The sim never calls Int.random(); all
//  randomness flows through one SeededRandomNumberGenerator stored in
//  GameState. Same state + same seed = identical outcome, forever.
//

import Foundation

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
