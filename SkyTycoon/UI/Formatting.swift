//
//  Formatting.swift
//  SkyTycoon — UI helpers
//

import Foundation

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
