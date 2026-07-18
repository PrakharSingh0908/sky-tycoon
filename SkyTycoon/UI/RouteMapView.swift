//
//  RouteMapView.swift
//  SkyTycoon — UI (teal accent)
//
//  The network map (GDD §7 tab 3): NASA Blue Marble satellite imagery
//  (public domain, bundled — fully offline, zero tile servers) draped
//  under the ops-dark scrim, with glowing route arcs, city dots, and
//  code chips on top. Flat equirectangular camera: drag pans, pinch
//  zooms; at domestic zoom flat vs globe is indistinguishable, and a
//  flat projection is what makes real imagery drapeable in one draw.
//
//  Routes: thickness = frequency, color = profitability, neutral +
//  dashed while unstaffed.
//

import SwiftUI

// ── Satellite base (NASA Blue Marble, public domain — see CREDITS.md) ────

private enum SatelliteBase {
    static let image: UIImage? = {
        guard let url = Bundle.main.url(forResource: "bluemarble_world",
                                        withExtension: "jpg"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        return img
    }()
}

// ── Camera ────────────────────────────────────────────────────────────────

private struct MapCamera: Equatable {
    var centerLon: Double   // degrees
    var centerLat: Double
    var zoom: Double        // points per degree = min(w,h)/2 × zoom × π/180

    static let india = MapCamera(centerLon: 77.5, centerLat: 20.0, zoom: 4.8)
}

struct RouteMapView: View {
    @Environment(GameEngine.self) private var engine
    /// When set, the map shows only this route's arc and labels only its
    /// two endpoints, and the camera frames the pair. The full-network
    /// map (nil) draws every arc and no code labels.
    var focusRouteID: UUID? = nil
    @State private var camera: MapCamera = .india
    @State private var dragStart: MapCamera?
    @State private var zoomStart: Double?

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                draw(ctx: &ctx, size: size)
            }
            .background(Theme.bg)
            .onAppear { frameFocusRoute() }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? camera
                        dragStart = start
                        let ppd = pointsPerDegree(size: geo.size)
                        camera.centerLon = max(-180, min(180,
                            start.centerLon - value.translation.width / ppd))
                        camera.centerLat = max(-75, min(75,
                            start.centerLat + value.translation.height / ppd))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = zoomStart ?? camera.zoom
                        zoomStart = start
                        camera.zoom = min(12, max(1.2, start * value.magnification))
                    }
                    .onEnded { _ in zoomStart = nil }
            )
        }
    }

    /// Centers between the focused route's endpoints, zoomed so the pair
    /// fills the view comfortably.
    private func frameFocusRoute() {
        guard let focusRouteID,
              let route = engine.state.routes.first(where: { $0.id == focusRouteID }),
              let o = engine.city(route.originID),
              let d = engine.city(route.destinationID) else { return }
        let φ1 = o.latitude * .pi / 180, φ2 = d.latitude * .pi / 180
        let Δλ = (d.longitude - o.longitude) * .pi / 180
        let angle = acos(max(-1, min(1, sin(φ1) * sin(φ2) + cos(φ1) * cos(φ2) * cos(Δλ))))
        camera = MapCamera(
            centerLon: (o.longitude + d.longitude) / 2,
            // Nudge up so the northward arc bow stays in frame.
            centerLat: (o.latitude + d.latitude) / 2 + angle * 6,
            zoom: min(12, max(1.5, 1.05 / max(angle, 0.02))))
    }

    // MARK: - Projection (flat equirectangular)

    private func pointsPerDegree(size: CGSize) -> Double {
        Double(min(size.width, size.height)) / 2 * camera.zoom * .pi / 180
    }

    private func project(_ lonDeg: Double, _ latDeg: Double, size: CGSize) -> CGPoint {
        let ppd = pointsPerDegree(size: size)
        return CGPoint(x: size.width / 2 + (lonDeg - camera.centerLon) * ppd,
                       y: size.height / 2 - (latDeg - camera.centerLat) * ppd)
    }

    // MARK: - Drawing

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        let ppd = pointsPerDegree(size: size)

        // ── Satellite base: the whole equirect world in one draw call,
        // positioned so the camera window shows the right patch.
        if let base = SatelliteBase.image {
            let worldRect = CGRect(
                x: size.width / 2 - (camera.centerLon + 180) * ppd,
                y: size.height / 2 - (90 - camera.centerLat) * ppd,
                width: 360 * ppd,
                height: 180 * ppd)
            ctx.draw(Image(uiImage: base), in: worldRect)
            // Ops-dark scrim: multiply toward the theme so the imagery sits
            // behind the arcs instead of competing with them.
            ctx.blendMode = .multiply
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.55, green: 0.63, blue: 0.78)))
            ctx.blendMode = .normal
        }

        // ── Route arcs: flight-map bows. Unstaffed routes draw dashed:
        // planned, not flying.
        let staffedRouteIDs = Set(engine.state.fleet.compactMap(\.assignedRouteID))
        let focusRoute = focusRouteID.flatMap { id in
            engine.state.routes.first { $0.id == id }
        }
        let routesToDraw = focusRoute.map { [$0] } ?? engine.state.routes
        for route in routesToDraw {
            guard let origin = engine.city(route.originID),
                  let dest = engine.city(route.destinationID) else { continue }
            let p1 = project(origin.longitude, origin.latitude, size: size)
            let p2 = project(dest.longitude, dest.latitude, size: size)
            let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            let dx = p2.x - p1.x, dy = p2.y - p1.y
            let chord = max(hypot(dx, dy), 1)
            // Perpendicular offset, always bowing toward the top of the map.
            var normal = CGPoint(x: -dy / chord, y: dx / chord)
            if normal.y > 0 { normal = CGPoint(x: -normal.x, y: -normal.y) }
            let control = CGPoint(x: mid.x + normal.x * chord * 0.22,
                                  y: mid.y + normal.y * chord * 0.22)
            var arc = Path()
            arc.move(to: p1)
            arc.addQuadCurve(to: p2, control: control)

            let color = color(for: route)
            let coreWidth = 1.5 + CGFloat(route.weeklyFrequency) / 28.0 * 3.0
            let dash: [CGFloat] = staffedRouteIDs.contains(route.id) ? [] : [6, 6]
            ctx.stroke(arc, with: .color(color.opacity(0.30)),
                       style: StrokeStyle(lineWidth: coreWidth + 4, lineCap: .round, dash: dash))
            ctx.stroke(arc, with: .color(color),
                       style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, dash: dash))
        }

        // ── City markers. Codes label only a focused route's two endpoints;
        // the network map stays label-free (dots + arcs tell the story).
        for city in engine.state.cities {
            let p = project(city.longitude, city.latitude, size: size)
            guard p.x > -20, p.x < size.width + 20,
                  p.y > -20, p.y < size.height + 20 else { continue }
            let isServed = engine.state.routes.contains {
                $0.originID == city.id || $0.destinationID == city.id
            }
            let isEndpoint = focusRoute.map {
                city.id == $0.originID || city.id == $0.destinationID
            } ?? false
            let dotR: CGFloat = isEndpoint ? 5 : (isServed ? 4.5 : 3)
            // Halo so dots read on bright terrain.
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - dotR - 1.5, y: p.y - dotR - 1.5,
                                            width: (dotR + 1.5) * 2, height: (dotR + 1.5) * 2)),
                     with: .color(Theme.bg.opacity(0.55)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR,
                                            width: dotR * 2, height: dotR * 2)),
                     with: .color(isServed || isEndpoint ? Theme.teal : .white.opacity(0.6)))
            if isEndpoint {
                ctx.draw(
                    Text(city.id)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary),
                    at: CGPoint(x: p.x, y: p.y + 13))
            }
        }
    }

    /// GDD §7: color = profitability; neutral while nothing flies it.
    private func color(for route: Route) -> Color {
        if route.lastLoadFactor == 0 && route.lastWeeklyProfit == 0 {
            return .white.opacity(0.75)
        }
        return route.lastWeeklyProfit >= 0 ? Theme.profit : Theme.loss
    }
}

#Preview {
    RouteMapView()
        .environment(GameEngine.previewGame())
        .frame(height: 340)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
}
