//
//  AircraftPhotoView.swift
//  SkyTycoon — Design system (DESIGN_SYSTEM.md §4.1, v1.5)
//
//  The fleet photography. One photo per archetype, bundled in
//  Resources/AircraftPhotos as aircraft_<type>.png. The airline's fuselage
//  color tints the photo (colorMultiply works beautifully on the white
//  airframes); pass nil livery for natural factory paint (showroom,
//  on-order aircraft).
//

import SwiftUI

struct AircraftPhotoView: View {
    let type: AircraftType
    var livery: Livery? = nil

    var body: some View {
        if let photo = UIImage(named: "aircraft_\(type.rawValue)") {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .colorMultiply(livery.map { Color($0.fuselage) } ?? .white)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
        } else {
            Image(systemName: "airplane")
                .font(.largeTitle)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview("All archetypes") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(AircraftType.allCases) { type in
                VStack(spacing: 4) {
                    AircraftPhotoView(type: type, livery: .launch)
                        .frame(height: 110)
                    Text("\(Balance.specs[type]!.displayName) · \(Balance.specs[type]!.windowCount) windows · \(Balance.specs[type]!.maxSeats) seats")
                        .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(24)
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}
