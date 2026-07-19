//
//  CabinArchitectView.swift
//  SkyTycoon — UI (orange accent)
//
//  The cabin architect (GDD §4.2 as amended): a to-scale top-down cabin
//  drawing that IS the interface — seats, aisle, galley blocks, and
//  material colors redraw live as you adjust pitch, width, galley count,
//  wifi, and material. Slim rulers under the drawing; one readout strip
//  showing the tradeoff (seats · comfort · refit cost · weekly upkeep).
//

import SwiftUI

struct CabinArchitectView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let aircraftID: UUID
    @State private var draft: CabinLayout
    private let accent = Theme.orange

    init(aircraftID: UUID, current: CabinLayout) {
        self.aircraftID = aircraftID
        _draft = State(initialValue: current)
    }

    private var plane: Aircraft? {
        engine.state.fleet.first { $0.id == aircraftID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let plane {
                    let spec = Balance.specs[plane.type]!
                    header(plane, spec)

                    // ── The cabin itself — the interface ─────────────────
                    CabinFloorplan(spec: spec, layout: draft, accent: accent)
                        .frame(height: 330)
                        .frame(maxWidth: .infinity)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        .animation(.snappy, value: draft)

                    readoutCard(spec, current: plane.cabin)
                    controlsCard(spec)
                    applyButton(plane, spec)
                } else {
                    Text("This aircraft has left the fleet.")
                        .font(.game(.headline)).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 28)
        }
        .background(Theme.bg)
        .scrollIndicators(.hidden)
        .preferredColorScheme(.dark)
        .holdsSimClock()
    }

    // ── Pieces ───────────────────────────────────────────────────────────

    private func header(_ plane: Aircraft, _ spec: AircraftSpec) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cabin Architect")
                    .font(.display(.title)).foregroundStyle(Theme.textPrimary)
                Text("\(plane.nickname) · \(spec.displayName)")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: Theme.controlCorner))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
    }

    // ── Readouts: one instrument card, one type scale ─────────────────────

    private func readoutCard(_ spec: AircraftSpec, current: CabinLayout) -> some View {
        GameCard {
            HStack(spacing: 20) {
                StatTile(label: "Seats · limit \(spec.maxSeats)",
                         value: "\(draft.seats(spec: spec))")
                StatTile(label: "Refit", value: draft.refitCost(spec: spec).money,
                         color: draft == current ? Theme.textSecondary : Theme.warn)
                StatTile(label: "Upkeep /wk", value: draft.weeklyUpkeep(spec: spec).money)
            }
            MeterRow(label: "Comfort", value: draft.comfort,
                     display: "\(Int(draft.comfort * 100))/100",
                     color: Theme.health(0.35 + draft.comfort * 0.65))
            Divider().overlay(Theme.hairline)
            // Payload-range: heavier cabins fly shorter, airy ones further.
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.caption2.weight(.bold)).foregroundStyle(Theme.teal)
                TickerText(text: "\(Int(spec.rangeKm * draft.rangeFactor(spec: spec))) km",
                           font: .game(.caption, weight: .bold), color: Theme.teal)
                Text("effective range")
                    .font(.game(.caption)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("brochure \(Int(spec.rangeKm)) km")
                    .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // ── Controls: dimensions, seat tier, galley, wifi — one card ─────────

    private func controlsCard(_ spec: AircraftSpec) -> some View {
        GameCard {
            ruler(label: "Seat pitch", value: $draft.seatPitchInches,
                  range: 28...36, unit: "\u{2033}")
            ruler(label: "Seat width", value: $draft.seatWidthInches,
                  range: 16...20, unit: "\u{2033}")
            Divider().overlay(Theme.hairline)
            // Seat tiers — the render assets themselves are the swatches,
            // evenly distributed, and the floorplan colors follow.
            HStack(spacing: 0) {
                ForEach(CabinMaterial.allCases) { material in
                    Button {
                        draft.material = material
                    } label: {
                        VStack(spacing: 4) {
                            Group {
                                if let seat = UIImage(named: "seat_\(material.rawValue)") {
                                    Image(uiImage: seat).resizable().scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(CabinFloorplan.seatColor(for: material))
                                }
                            }
                            .frame(width: 48, height: 48)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.corner - 2)
                                    .fill(draft.material == material
                                          ? accent.opacity(0.18) : Color.white.opacity(0.04))
                            )
                            .overlay(RoundedRectangle(cornerRadius: Theme.corner - 2)
                                .strokeBorder(draft.material == material ? accent : .clear,
                                              lineWidth: 1.5))
                            Text(material.displayName)
                                .font(.game(.caption2,
                                            weight: draft.material == material ? .bold : .regular))
                                .foregroundStyle(draft.material == material
                                                 ? accent : Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: draft.material)
                }
            }
            Divider().overlay(Theme.hairline)
            PillStepper(label: "Galley ovens", value: "\(draft.galleyUnits)", accent: accent,
                onDecrement: { draft.galleyUnits = max(0, draft.galleyUnits - 1) },
                onIncrement: { draft.galleyUnits = min(3, draft.galleyUnits + 1) })
            Toggle(isOn: $draft.hasWifi) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cabin wifi")
                        .font(.game(.subheadline)).foregroundStyle(Theme.textPrimary)
                    Text("\((12 * Double(spec.maxSeats)).money)/wk service")
                        .font(.game(.caption2)).foregroundStyle(Theme.textSecondary)
                }
            }
            .tint(accent)
        }
    }

    private func ruler(label: String, value: Binding<Double>,
                       range: ClosedRange<Double>, unit: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.game(.subheadline)).foregroundStyle(Theme.textSecondary)
                .frame(width: 82, alignment: .leading)
            Slider(value: value, in: range, step: 0.5).tint(accent)
            TickerText(text: String(format: "%.1f%@", value.wrappedValue, unit),
                       font: .game(.caption, weight: .bold))
                .frame(width: 52, alignment: .trailing)
        }
    }

    private func applyButton(_ plane: Aircraft, _ spec: AircraftSpec) -> some View {
        VStack(spacing: 10) {
            if let routeID = plane.assignedRouteID,
               let route = engine.state.routes.first(where: { $0.id == routeID }),
               spec.rangeKm * draft.rangeFactor(spec: spec) < route.distanceKm {
                Label("Too heavy for \(route.originID) ✈︎ \(route.destinationID) (\(Int(route.distanceKm)) km). Refitting will unassign this aircraft.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.game(.caption, weight: .medium))
                    .foregroundStyle(Theme.warn)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.warn.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: Theme.corner))
            }
            Button(draft == plane.cabin
                   ? "No changes"
                   : "Refit · \(draft.refitCost(spec: spec).money) · grounded \(Balance.cabinRefitWeeks) wk") {
                if engine.refitCabin(aircraftID: aircraftID, layout: draft) {
                    dismiss()
                }
            }
            .buttonStyle(GameButtonStyle(color: accent, prominent: true))
            .frame(maxWidth: .infinity)
            .disabled(draft == plane.cabin
                      || engine.state.cash < draft.refitCost(spec: spec)
                      || plane.groundedWeeksRemaining > 0)
            .opacity(draft == plane.cabin ? 0.5 : 1)
        }
    }
}

// ── The floorplan — a booking-style seat map (nose at top) ───────────────
// Vertical, scrollable cabin: column letters across the top, row numbers
// down both sides, bulkhead galley shelves up front, and seat glyphs with
// backrest + cushion that visibly fatten with seat width and gain legroom
// with pitch.

struct CabinFloorplan: View {
    let spec: AircraftSpec
    let layout: CabinLayout
    let accent: Color

    /// Floorplan seat colors sampled from the seat render assets.
    static func seatColor(for material: CabinMaterial) -> Color {
        switch material {
        case .economy: Color(red: 0.45, green: 0.62, blue: 0.86)   // blue shell
        case .premium: Color(red: 0.55, green: 0.34, blue: 0.26)   // brown leather
        case .luxury: Color(red: 0.20, green: 0.21, blue: 0.25)    // black recliner
        }
    }

    private struct Metrics {
        let rows: Int, abreast: Int
        /// Seats per block, aisles between blocks: [3,3] narrowbody,
        /// [2,3,2] / [2,4,2] / [3,3,3] twin-aisle widebody.
        let blocks: [Int]
        let margin: CGFloat, cellW: CGFloat, aisleW: CGFloat
        let seatW: CGFloat, seatDepth: CGFloat, rowH: CGFloat
        let headerH: CGFloat, galleyRowH: CGFloat, tailH: CGFloat

        init(spec: AircraftSpec, layout: CabinLayout, width: CGFloat) {
            rows = layout.rows(spec: spec)
            abreast = layout.seatsAbreast(spec: spec)
            if abreast >= 7 {
                let outer = abreast / 3
                blocks = [outer, abreast - 2 * outer, outer]
            } else {
                blocks = [(abreast + 1) / 2, abreast / 2].filter { $0 > 0 }
            }
            let aisles = CGFloat(blocks.count - 1)
            // Cap the cell size so small aircraft draw a narrow fuselage
            // instead of enormous seats; center the cabin in the card.
            let ideal = (width - 60) / (CGFloat(abreast) + 0.75 * aisles)
            cellW = min(ideal, 52)
            aisleW = cellW * 0.75
            margin = (width - (CGFloat(abreast) * cellW + aisles * aisleW)) / 2
            // Seat width slider fattens the glyph inside its cell.
            seatW = cellW * (0.58 + (layout.seatWidthInches - 16) / 4 * 0.34)
            seatDepth = cellW * 0.76
            // Pitch adds visible legroom between rows.
            let legroom = cellW * 0.16
                + (layout.seatPitchInches - 28) / 8 * cellW * 0.85
            rowH = seatDepth + legroom
            headerH = 88
            galleyRowH = cellW * 0.72 + 10
            tailH = 34
        }

        var contentHeight: CGFloat {
            headerH + CGFloat(max(0, rows)) * rowH
                + CGFloat(0) + tailH   // galleys drawn inside headerH zone offset below
        }
    }

    var body: some View {
        GeometryReader { geo in
            let m = Metrics(spec: spec, layout: layout, width: geo.size.width)
            let galleyZone = CGFloat(layout.galleyUnits > 0 ? 1 : 0) * m.galleyRowH
            ScrollView(showsIndicators: false) {
                Canvas { ctx, size in
                    draw(ctx: &ctx, size: size, m: m, galleyZone: galleyZone)
                }
                .frame(width: geo.size.width,
                       height: m.contentHeight + galleyZone)
            }
        }
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize,
                      m: Metrics, galleyZone: CGFloat) {
        let w = size.width, h = size.height
        let seatBase = Self.seatColor(for: layout.material)
        let cushion = seatBase.opacity(1)   // cushion drawn lighter via overlay

        // ── Hull: nose dome at the top, walls down, tail taper ───────────
        let wallL = m.margin - 14, wallR = w - m.margin + 14
        var hull = Path()
        hull.move(to: CGPoint(x: wallL, y: h - m.tailH))
        hull.addLine(to: CGPoint(x: wallL, y: 64))
        hull.addQuadCurve(to: CGPoint(x: w / 2, y: 4),
                          control: CGPoint(x: wallL, y: 14))
        hull.addQuadCurve(to: CGPoint(x: wallR, y: 64),
                          control: CGPoint(x: wallR, y: 14))
        hull.addLine(to: CGPoint(x: wallR, y: h - m.tailH))
        hull.addQuadCurve(to: CGPoint(x: w / 2, y: h - 4),
                          control: CGPoint(x: wallR - 20, y: h - 8))
        hull.addQuadCurve(to: CGPoint(x: wallL, y: h - m.tailH),
                          control: CGPoint(x: wallL + 20, y: h - 8))
        hull.closeSubpath()
        ctx.fill(hull, with: .color(Color.white.opacity(0.05)))
        ctx.stroke(hull, with: .color(Color.white.opacity(0.15)), lineWidth: 1.5)

        // Cockpit hint + wifi in the dome.
        var door = Path()
        door.move(to: CGPoint(x: wallL + 10, y: 40))
        door.addLine(to: CGPoint(x: wallR - 10, y: 40))
        ctx.stroke(door, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
        if layout.hasWifi {
            ctx.draw(Text(Image(systemName: "wifi"))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(accent),
                     at: CGPoint(x: w / 2, y: 24))
        }

        // ── Column letters (skip I, like real airlines) ──────────────────
        let letters = Array("ABCDEFGHJK").map(String.init)
        let lettersY = 56.0
        for s in 0..<m.abreast {
            ctx.draw(Text(letters[s])
                        .font(.game(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary),
                     at: CGPoint(x: seatCenterX(s, m: m), y: lettersY))
        }

        // ── Galley shelves (bulkhead, like the reference) ────────────────
        var y = m.headerH
        if layout.galleyUnits > 0 {
            let blocks = min(layout.galleyUnits, 2)
            let blockW = (wallR - wallL - m.aisleW - 24) / 2
            for b in 0..<blocks {
                let x = b == 0 ? wallL + 12 : wallR - 12 - blockW
                let rect = CGRect(x: x, y: y, width: blockW, height: m.galleyRowH - 10)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 6),
                         with: .color(Theme.warn.opacity(0.30)))
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 6),
                           with: .color(Theme.warn.opacity(0.5)), lineWidth: 1)
                ctx.draw(Text(Image(systemName: b == 0 ? "fork.knife" : "cup.and.saucer.fill"))
                            .font(.system(size: 10)).foregroundStyle(Theme.warn),
                         at: CGPoint(x: rect.midX, y: rect.midY))
            }
            // A third oven squeezes into the aisle gap between the shelves.
            if layout.galleyUnits > 2 {
                let rect = CGRect(x: w / 2 - m.aisleW / 2 + 2, y: y,
                                  width: m.aisleW - 4, height: m.galleyRowH - 10)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 5),
                         with: .color(Theme.warn.opacity(0.30)))
                ctx.draw(Text(Image(systemName: "flame.fill"))
                            .font(.system(size: 9)).foregroundStyle(Theme.warn),
                         at: CGPoint(x: rect.midX, y: rect.midY))
            }
            y += m.galleyRowH
        }

        // ── Seat rows ────────────────────────────────────────────────────
        for row in 0..<m.rows {
            let rowY = y + CGFloat(row) * m.rowH
            let numberY = rowY + m.seatDepth / 2
            for xText in [m.margin - 26, w - m.margin + 26] {
                ctx.draw(Text("\(row + 1)")
                            .font(.game(.caption2)).foregroundStyle(Theme.textSecondary.opacity(0.7)),
                         at: CGPoint(x: xText, y: numberY))
            }
            for s in 0..<m.abreast {
                drawSeat(ctx: &ctx,
                         center: seatCenterX(s, m: m),
                         top: rowY, m: m, base: seatBase, cushion: cushion)
            }
        }
    }

    /// X center of seat index `s`, inserting an aisle gap between blocks.
    private func seatCenterX(_ s: Int, m: Metrics) -> CGFloat {
        var aislesBefore = 0, counted = 0
        for block in m.blocks {
            counted += block
            if s < counted { break }
            aislesBefore += 1
        }
        let x = m.margin + CGFloat(s) * m.cellW + CGFloat(aislesBefore) * m.aisleW
        return x + m.cellW / 2
    }

    private func drawSeat(ctx: inout GraphicsContext, center: CGFloat,
                          top: CGFloat, m: Metrics, base: Color, cushion: Color) {
        let x = center - m.seatW / 2
        // Backrest with armrest nubs.
        let back = CGRect(x: x, y: top, width: m.seatW, height: m.seatDepth * 0.78)
        ctx.fill(Path(roundedRect: back, cornerRadius: m.seatW * 0.22), with: .color(base))
        // Headrest band.
        ctx.fill(Path(roundedRect: CGRect(x: x + m.seatW * 0.16, y: top + 1.5,
                                          width: m.seatW * 0.68, height: m.seatDepth * 0.16),
                      cornerRadius: 2),
                 with: .color(.white.opacity(0.22)))
        // Cushion lip (the part you sit on), slightly wider and lighter.
        let lip = CGRect(x: x - m.seatW * 0.05, y: top + m.seatDepth * 0.66,
                         width: m.seatW * 1.1, height: m.seatDepth * 0.30)
        ctx.fill(Path(roundedRect: lip, cornerRadius: m.seatW * 0.14),
                 with: .color(base))
        ctx.fill(Path(roundedRect: lip.insetBy(dx: m.seatW * 0.10, dy: 2),
                      cornerRadius: m.seatW * 0.10),
                 with: .color(.white.opacity(0.13)))
        // Soft ground shadow.
        ctx.stroke(Path(roundedRect: back, cornerRadius: m.seatW * 0.22),
                   with: .color(.black.opacity(0.25)), lineWidth: 0.8)
    }
}

#Preview {
    let engine = GameEngine.previewGame()
    return CabinArchitectView(aircraftID: engine.state.fleet[0].id,
                              current: engine.state.fleet[0].cabin)
        .environment(engine)
}

#Preview("Widebody, twin aisle") {
    CabinFloorplan(spec: Balance.specs[.widebody75]!,
                   layout: CabinLayout(seatPitchInches: 31, seatWidthInches: 17,
                                       material: .premium, galleyUnits: 2, hasWifi: true),
                   accent: Theme.orange)
        .frame(height: 500)
        .padding(16)
        .background(Theme.card)
        .preferredColorScheme(.dark)
}
