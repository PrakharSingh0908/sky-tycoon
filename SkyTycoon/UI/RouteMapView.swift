//
//  RouteMapView.swift
//  SkyTycoon — UI (teal accent)
//
//  The network globe (GDD §7 tab 3), drawn entirely in-app: an
//  orthographic world rendered from public-domain Natural Earth land
//  polygons (bundled GeoJSON, 138 KB) — dark ops-styled continents,
//  glowing great-circle route arcs, city code chips. Fully offline,
//  zero dependencies, zero tile-server terms (DESIGN_SYSTEM.md §4.3).
//
//  Drag rotates the globe, pinch zooms. Routes: thickness = frequency,
//  color = profitability, neutral while unstaffed.
//

import SwiftUI

// ── World geometry (Natural Earth, public domain) ────────────────────────

private struct WorldGeometry {
    /// Land rings as [lon, lat] in radians, preprocessed once.
    let rings: [[SIMD2<Double>]]

    static let shared: WorldGeometry = load()

    private static func load() -> WorldGeometry {
        guard let url = Bundle.main.url(forResource: "ne_110m_land", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]]
        else { return WorldGeometry(rings: []) }

        var rings: [[SIMD2<Double>]] = []
        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String,
                  let coords = geometry["coordinates"] else { continue }
            let polygons: [Any]
            switch type {
            case "Polygon": polygons = [coords]
            case "MultiPolygon": polygons = coords as? [Any] ?? []
            default: continue
            }
            for polygon in polygons {
                guard let ringList = polygon as? [[[Double]]] else { continue }
                for ring in ringList {
                    rings.append(ring.map {
                        SIMD2($0[0] * .pi / 180, $0[1] * .pi / 180)
                    })
                }
            }
        }
        return WorldGeometry(rings: rings)
    }
}

// ── Orthographic camera ──────────────────────────────────────────────────

private struct GlobeCamera: Equatable {
    var centerLon: Double   // degrees
    var centerLat: Double
    var zoom: Double        // globe radius = min(w,h)/2 × zoom

    static let india = GlobeCamera(centerLon: 77.5, centerLat: 20.0, zoom: 4.8)
}

struct RouteMapView: View {
    @Environment(GameEngine.self) private var engine
    @State private var camera: GlobeCamera = .india
    @State private var dragStart: GlobeCamera?
    @State private var zoomStart: Double?

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                draw(ctx: &ctx, size: size)
            }
            .background(Theme.bg)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? camera
                        dragStart = start
                        let radius = min(geo.size.width, geo.size.height) / 2 * camera.zoom
                        let degreesPerPoint = 60.0 / radius
                        camera.centerLon = start.centerLon - value.translation.width * degreesPerPoint
                        camera.centerLat = min(80, max(-80,
                            start.centerLat + value.translation.height * degreesPerPoint))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = zoomStart ?? camera.zoom
                        zoomStart = start
                        camera.zoom = min(9, max(1.0, start * value.magnification))
                    }
                    .onEnded { _ in zoomStart = nil }
            )
        }
    }

    // MARK: - Projection

    /// Orthographic projection. Returns nil past the horizon.
    private func project(_ lonRad: Double, _ latRad: Double,
                         size: CGSize, radius: Double) -> CGPoint? {
        let λ = lonRad - camera.centerLon * .pi / 180
        let φ = latRad
        let φ0 = camera.centerLat * .pi / 180
        let cosC = sin(φ0) * sin(φ) + cos(φ0) * cos(φ) * cos(λ)
        guard cosC > -0.02 else { return nil }   // small overshoot for edge continuity
        let x = cos(φ) * sin(λ)
        let y = cos(φ0) * sin(φ) - sin(φ0) * cos(φ) * cos(λ)
        return CGPoint(x: size.width / 2 + radius * x,
                       y: size.height / 2 - radius * y)
    }

    // MARK: - Drawing

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        let radius = Double(min(size.width, size.height)) / 2 * camera.zoom
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))

        // Atmosphere rim + ocean.
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 10))
            layer.stroke(disc, with: .color(Theme.teal.opacity(0.35)), lineWidth: 5)
        }
        ctx.fill(disc, with: .color(Color(red: 0.055, green: 0.10, blue: 0.17)))

        // Everything on the sphere clips to the disc.
        var globe = ctx
        globe.clip(to: disc)

        // Graticule.
        var grid = Path()
        for lonDeg in stride(from: -180.0, to: 180.0, by: 15.0) {
            addPolyline(to: &grid, points: stride(from: -85.0, through: 85.0, by: 5.0).map {
                (lonDeg * .pi / 180, $0 * .pi / 180)
            }, size: size, radius: radius)
        }
        for latDeg in stride(from: -75.0, through: 75.0, by: 15.0) {
            addPolyline(to: &grid, points: stride(from: -180.0, through: 180.0, by: 5.0).map {
                ($0 * .pi / 180, latDeg * .pi / 180)
            }, size: size, radius: radius)
        }
        globe.stroke(grid, with: .color(.white.opacity(0.05)), lineWidth: 0.7)

        // Land.
        var land = Path()
        for ring in WorldGeometry.shared.rings {
            var subpath: [CGPoint] = []
            var anyVisible = false
            for point in ring {
                if let p = project(point.x, point.y, size: size, radius: radius) {
                    subpath.append(p); anyVisible = true
                } else if !subpath.isEmpty {
                    land.addLines(subpath); land.closeSubpath()
                    subpath = []
                }
            }
            if anyVisible, subpath.count > 2 {
                land.addLines(subpath); land.closeSubpath()
            }
        }
        globe.fill(land, with: .color(Color(red: 0.13, green: 0.19, blue: 0.28)))
        globe.stroke(land, with: .color(.white.opacity(0.10)), lineWidth: 0.8)

        // Route arcs: flight-map bows (a quadratic curve lifted from the
        // chord) — at domestic zoom, true geodesics read as straight lines,
        // and straight lines read as train tracks, not flights.
        for route in engine.state.routes {
            guard let origin = engine.city(route.originID),
                  let dest = engine.city(route.destinationID),
                  let p1 = project(origin.longitude * .pi / 180, origin.latitude * .pi / 180,
                                   size: size, radius: radius),
                  let p2 = project(dest.longitude * .pi / 180, dest.latitude * .pi / 180,
                                   size: size, radius: radius) else { continue }
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
            globe.stroke(arc, with: .color(color.opacity(0.30)),
                         style: StrokeStyle(lineWidth: coreWidth + 4, lineCap: .round))
            globe.stroke(arc, with: .color(color),
                         style: StrokeStyle(lineWidth: coreWidth, lineCap: .round))
        }

        // City markers + code chips.
        for city in engine.state.cities {
            guard let p = project(city.longitude * .pi / 180, city.latitude * .pi / 180,
                                  size: size, radius: radius) else { continue }
            let isServed = engine.state.routes.contains {
                $0.originID == city.id || $0.destinationID == city.id
            }
            let dotR: CGFloat = isServed ? 4.5 : 3
            globe.fill(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR,
                                              width: dotR * 2, height: dotR * 2)),
                       with: .color(isServed ? Theme.teal : .white.opacity(0.5)))
            globe.draw(
                Text(city.id)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isServed ? Theme.textPrimary : Theme.textSecondary),
                at: CGPoint(x: p.x, y: p.y + 11))
        }
    }

    /// Projects a lon/lat polyline, breaking the path across the horizon.
    private func addPolyline(to path: inout Path,
                             points: [(Double, Double)],
                             size: CGSize, radius: Double) {
        var previousVisible = false
        for (lon, lat) in points {
            if let p = project(lon, lat, size: size, radius: radius) {
                if previousVisible { path.addLine(to: p) } else { path.move(to: p) }
                previousVisible = true
            } else {
                previousVisible = false
            }
        }
    }

    /// GDD §7: color = profitability; neutral while nothing flies it.
    private func color(for route: Route) -> Color {
        if route.lastLoadFactor == 0 && route.lastWeeklyProfit == 0 {
            return .white.opacity(0.55)
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
