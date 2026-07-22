//
//  RouteMapView.swift
//  SkyTycoon — UI (teal accent)
//
//  The satellite globe (GDD §7 tab 3): NASA Blue Marble imagery (public
//  domain, bundled, fully offline) textured onto a GPU-rendered SceneKit
//  sphere — the 3D orthographic projection with real terrain, at zero
//  per-frame CPU cost. Route arcs, city dots, and code chips draw in a
//  SwiftUI Canvas overlay whose orthographic math matches the SceneKit
//  camera exactly (both are true orthographic, same radius), so overlay
//  and terrain can never drift apart.
//
//  Drag rotates, pinch zooms. Routes: thickness = frequency, color =
//  profitability, neutral + dashed while unstaffed.
//

import SwiftUI
import SceneKit

// ── Camera ────────────────────────────────────────────────────────────────

private struct GlobeCamera: Equatable {
    var centerLon: Double   // degrees
    var centerLat: Double
    var zoom: Double        // sphere screen radius = min(w,h)/2 × zoom

    static let india = GlobeCamera(centerLon: 77.5, centerLat: 20.0, zoom: 4.8)

    /// Home framing for the campaign's market (the map opens on YOUR
    /// country). Zooms sized to each network's spread.
    static func home(for country: Country) -> GlobeCamera {
        switch country {
        case .us: GlobeCamera(centerLon: -96.5, centerLat: 38.5, zoom: 2.3)
        case .uk: GlobeCamera(centerLon: -2.0, centerLat: 54.0, zoom: 6.5)
        case .china: GlobeCamera(centerLon: 104.0, centerLat: 35.0, zoom: 2.6)
        case .australia: GlobeCamera(centerLon: 134.0, centerLat: -26.0, zoom: 2.8)
        case .india: india
        }
    }
}

// ── The GPU globe: textured sphere, unlit, ops-dark multiplied ───────────

private struct GlobeSceneView: UIViewRepresentable {
    var camera: GlobeCamera
    /// The view's size from SwiftUI geometry — NOT view.bounds, which is
    /// zero at makeUIView/first-update time and left the terrain at a
    /// wrong scale until the first pan (dots drifted off their airports
    /// on first load).
    var size: CGSize

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false   // SwiftUI owns the gestures
        view.rendersContinuously = false        // static scene: draw on change only

        let scene = SCNScene()
        // Custom sphere with EXPLICIT UVs: local point for (lam, phi) is
        // (cos phi * sin lam, sin phi, cos phi * cos lam), so lon 0 faces +Z
        // and u/v map the equirect texture exactly. No dependence on
        // SCNSphere's undocumented seam; the Canvas overlay matches by
        // construction.
        let sphere = Self.buildGlobeGeometry(bands: 96)
        let material = SCNMaterial()
        if let url = Bundle.main.url(forResource: "bluemarble_world", withExtension: "jpg"),
           let image = UIImage(contentsOfFile: url.path) {
            material.diffuse.contents = image
        } else {
            material.diffuse.contents = UIColor(red: 0.13, green: 0.19, blue: 0.28, alpha: 1)
        }
        material.lightingModel = .constant     // a map, not a lit planet
        // Ops-dark scrim, done in the material so arcs stay bright above.
        material.multiply.contents = UIColor(red: 0.60, green: 0.67, blue: 0.80, alpha: 1)
        sphere.firstMaterial = material
        let globe = SCNNode(geometry: sphere)
        globe.name = "globe"
        scene.rootNode.addChildNode(globe)

        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        let cam = SCNCamera()
        cam.usesOrthographicProjection = true  // matches the overlay math exactly
        cam.zNear = 0.1
        cam.zFar = 10
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0, 3)
        scene.rootNode.addChildNode(cameraNode)

        view.scene = scene
        apply(camera: camera, to: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        apply(camera: camera, to: view)
    }

    private func apply(camera: GlobeCamera, to view: SCNView) {
        guard let globe = view.scene?.rootNode.childNode(withName: "globe", recursively: false),
              let cameraNode = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        else { return }
        // Kill SceneKit's implicit 0.25s ease: the Canvas overlay moves
        // instantly, so ANY animation here makes dots slide off the
        // terrain during drags (glaring at device frame rates).
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        defer { SCNTransaction.commit() }
        // Rotate so (centerLon, centerLat) faces the camera on +Z. Built
        // as an explicit quaternion product (pitch AFTER yaw, in world
        // space) so SceneKit's euler order can't surprise us.
        let lon = Float(camera.centerLon * .pi / 180)
        let lat = Float(camera.centerLat * .pi / 180)
        let yaw = simd_quatf(angle: -lon, axis: SIMD3(0, 1, 0))
        let pitch = simd_quatf(angle: lat, axis: SIMD3(1, 0, 0))
        globe.simdOrientation = pitch * yaw
        // Orthographic scale: world-unit half-height of the view such that
        // the unit sphere projects to min(w,h)/2 × zoom points. Sized from
        // SwiftUI geometry so the very first frame matches the overlay.
        guard size.height > 0 else { return }
        let minSide = min(size.width, size.height)
        cameraNode.camera?.orthographicScale =
            Double(size.height) / (Double(minSide) * camera.zoom)
    }

    /// Unit sphere with our own equirect UVs. Index-limited well below
    /// UInt16; built once at view creation.
    private static func buildGlobeGeometry(bands: Int) -> SCNGeometry {
        var positions: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [UInt32] = []
        let rings = bands / 2
        for r in 0...rings {
            let phi = Double.pi / 2 - Double(r) / Double(rings) * .pi   // +90 ... -90
            for b in 0...bands {
                let lam = -Double.pi + Double(b) / Double(bands) * 2 * .pi
                positions.append(SCNVector3(cos(phi) * sin(lam),
                                            sin(phi),
                                            cos(phi) * cos(lam)))
                uvs.append(CGPoint(x: (lam + .pi) / (2 * .pi),
                                   y: (Double.pi / 2 - phi) / .pi))
            }
        }
        let stride = bands + 1
        for r in 0..<rings {
            for b in 0..<bands {
                let a = UInt32(r * stride + b)
                let bIdx = UInt32(r * stride + b + 1)
                let c = UInt32((r + 1) * stride + b)
                let d = UInt32((r + 1) * stride + b + 1)
                indices.append(contentsOf: [a, c, bIdx, bIdx, c, d])
            }
        }
        let vertexSource = SCNGeometrySource(vertices: positions)
        let uvSource = SCNGeometrySource(textureCoordinates: uvs)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [vertexSource, uvSource], elements: [element])
    }
}

// ── The map: GPU globe underneath, Canvas overlay on top ─────────────────

struct RouteMapView: View {
    @Environment(GameEngine.self) private var engine
    // The map is dark satellite imagery — a floating artifact. It keeps its
    // own palette instead of the paper theme's ink tokens.
    private let mapTeal = Color(red: 0.251, green: 0.839, blue: 0.788)
    private let mapLabel = Color.white
    /// When set, the map shows only this route's arc and labels only its
    /// two endpoints, and the camera frames the pair. The full-network
    /// map (nil) draws every arc and no code labels.
    var focusRouteID: UUID? = nil
    @State private var camera: GlobeCamera = .india
    @State private var dragStart: GlobeCamera?
    @State private var zoomStart: Double?
    // A3 living map: a monotonic display-time phase that advances planes
    // along the arcs. Scaled by sim speed and frozen on pause, so the map's
    // tempo matches the clock and nothing moves while the player isn't
    // watching. Purely visual — never touches the simulation.
    @State private var flightPhase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GlobeSceneView(camera: camera, size: geo.size)
                // The animation schedule is paused (zero cost, back to a
                // static globe) whenever time isn't running or the player
                // has Reduce Motion on; otherwise it drives one repaint per
                // frame so planes glide.
                TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                        paused: engine.speed == .paused || reduceMotion)) { timeline in
                    Canvas { ctx, size in
                        drawOverlay(ctx: &ctx, size: size)
                    }
                    .onChange(of: timeline.date) { old, new in
                        // Clamp the step so returning from the background (a
                        // huge gap) nudges rather than teleports the planes.
                        let dt = min(new.timeIntervalSince(old), 1.0 / 20.0)
                        flightPhase += dt * engine.speed.rawValue
                    }
                }
            }
            .background(Color(red: 0.043, green: 0.071, blue: 0.125))
            .onAppear {
                if focusRouteID != nil {
                    frameFocusRoute()
                } else {
                    camera = .home(for: engine.state.country)
                }
            }
            // ONE high-priority simultaneous pair: the map owns every touch
            // that starts on it. Splitting pan/pinch across .gesture and
            // .highPriorityGesture let the page ScrollView win vertical
            // drags — the globe would pan a few points, then snap back as
            // the scroll stole the touch.
            .highPriorityGesture(pan(in: geo.size).simultaneously(with: pinch))
        }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? camera
                dragStart = start
                // Pan speed from the gesture-start zoom, so a simultaneous
                // pinch can't warp the pan mid-drag.
                let radius = min(size.width, size.height) / 2 * start.zoom
                let degreesPerPoint = 60.0 / radius
                camera.centerLon = start.centerLon - value.translation.width * degreesPerPoint
                camera.centerLat = min(80, max(-80,
                    start.centerLat + value.translation.height * degreesPerPoint))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? camera.zoom
                zoomStart = start
                camera.zoom = min(12, max(0.85, start * value.magnification))
            }
            .onEnded { _ in zoomStart = nil }
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
        camera = GlobeCamera(
            centerLon: (o.longitude + d.longitude) / 2,
            // Nudge up so the northward arc bow stays in frame.
            centerLat: (o.latitude + d.latitude) / 2 + angle * 6,
            zoom: min(9, max(1.5, 1.05 / max(angle, 0.02))))
    }

    // MARK: - Projection (orthographic, mirrors the SceneKit camera)

    /// Returns nil past the horizon.
    private func project(_ lonDeg: Double, _ latDeg: Double,
                         size: CGSize, radius: Double) -> CGPoint? {
        let λ = (lonDeg - camera.centerLon) * .pi / 180
        let φ = latDeg * .pi / 180
        let φ0 = camera.centerLat * .pi / 180
        let cosC = sin(φ0) * sin(φ) + cos(φ0) * cos(φ) * cos(λ)
        guard cosC > 0 else { return nil }
        let x = cos(φ) * sin(λ)
        let y = cos(φ0) * sin(φ) - sin(φ0) * cos(φ) * cos(λ)
        return CGPoint(x: size.width / 2 + radius * x,
                       y: size.height / 2 - radius * y)
    }

    // MARK: - Overlay drawing (arcs + dots only; terrain is the GPU's job)

    private func drawOverlay(ctx: inout GraphicsContext, size: CGSize) {
        let radius = Double(min(size.width, size.height)) / 2 * camera.zoom
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Atmosphere rim, when the whole disc is in frame.
        if radius < Double(max(size.width, size.height)) {
            let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                              width: radius * 2, height: radius * 2))
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 10))
                layer.stroke(disc, with: .color(mapTeal.opacity(0.35)), lineWidth: 5)
            }
        }

        // Route arcs: flight-map bows. Unstaffed routes draw dashed:
        // planned, not flying.
        let staffedRouteIDs = Set(engine.state.fleet.compactMap(\.assignedRouteID))
        let focusRoute = focusRouteID.flatMap { id in
            engine.state.routes.first { $0.id == id }
        }
        let routesToDraw = focusRoute.map { [$0] } ?? engine.state.routes
        for route in routesToDraw {
            guard let (p1, control, p2) = arcPoints(for: route, size: size,
                                                    radius: radius) else { continue }
            var arc = Path()
            arc.move(to: p1)
            arc.addQuadCurve(to: p2, control: control)

            let color = color(for: route)
            let coreWidth = 1.5 + CGFloat(route.weeklyFrequency) / 28.0 * 3.0
            let staffed = staffedRouteIDs.contains(route.id)
            let dash: [CGFloat] = staffed ? [] : [6, 6]
            // Load-factor "breathing": a fuller staffed route pulses a wider,
            // brighter glow; planned routes stay steady. Per-route phase so
            // the network doesn't throb in unison.
            var glowAlpha = 0.30
            var glowWidth = coreWidth + 4
            if staffed && !reduceMotion {
                let lf = min(1, max(0, route.lastLoadFactor))
                let off = Double(abs(route.id.hashValue) % 997) / 997.0 * 2 * .pi
                let pulse = 0.5 + 0.5 * sin(flightPhase * 1.4 + off)
                glowAlpha = 0.30 + 0.28 * lf * pulse
                glowWidth = coreWidth + 4 + CGFloat(7 * lf * pulse)
            }
            ctx.stroke(arc, with: .color(color.opacity(glowAlpha)),
                       style: StrokeStyle(lineWidth: glowWidth, lineCap: .round, dash: dash))
            ctx.stroke(arc, with: .color(color),
                       style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, dash: dash))
        }

        // Living map (A3): aircraft in flight on staffed routes, above the
        // arcs and beneath the city dots (which stay crisp anchors).
        drawFlights(ctx: &ctx, size: size, radius: radius)

        // City markers. Codes label only a focused route's two endpoints;
        // the network map stays label-free (dots + arcs tell the story).
        for city in engine.state.cities {
            guard let p = project(city.longitude, city.latitude,
                                  size: size, radius: radius) else { continue }
            let isServed = engine.state.routes.contains {
                $0.originID == city.id || $0.destinationID == city.id
            }
            let isEndpoint = focusRoute.map {
                city.id == $0.originID || city.id == $0.destinationID
            } ?? false
            let dotR: CGFloat = isEndpoint ? 5 : (isServed ? 4.5 : 3)
            let connected = isServed || isEndpoint
            // Halo so dots read on bright terrain — quieter for airports
            // you haven't connected yet, so the network pops.
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - dotR - 1.5, y: p.y - dotR - 1.5,
                                            width: (dotR + 1.5) * 2, height: (dotR + 1.5) * 2)),
                     with: .color(Color.black.opacity(connected ? 0.45 : 0.22)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR,
                                            width: dotR * 2, height: dotR * 2)),
                     with: .color(connected ? mapTeal : .white.opacity(0.28)))
            if isEndpoint {
                ctx.draw(
                    Text(city.id)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(mapLabel),
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

    // MARK: - Living map (A3): planes gliding the arcs

    /// The drawn bow for a route — the same quad-bezier the arcs use, so a
    /// plane rides exactly the line the player sees. nil past the horizon.
    private func arcPoints(for route: Route, size: CGSize,
                           radius: Double) -> (CGPoint, CGPoint, CGPoint)? {
        guard let origin = engine.city(route.originID),
              let dest = engine.city(route.destinationID),
              let p1 = project(origin.longitude, origin.latitude,
                               size: size, radius: radius),
              let p2 = project(dest.longitude, dest.latitude,
                               size: size, radius: radius) else { return nil }
        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let dx = p2.x - p1.x, dy = p2.y - p1.y
        let chord = max(hypot(dx, dy), 1)
        // Perpendicular offset, always bowing toward the top of the map.
        var normal = CGPoint(x: -dy / chord, y: dx / chord)
        if normal.y > 0 { normal = CGPoint(x: -normal.x, y: -normal.y) }
        let control = CGPoint(x: mid.x + normal.x * chord * 0.22,
                              y: mid.y + normal.y * chord * 0.22)
        return (p1, control, p2)
    }

    private func bezier(_ p1: CGPoint, _ c: CGPoint, _ p2: CGPoint,
                        _ t: Double) -> CGPoint {
        let mt = 1 - t
        let a = mt * mt, b = 2 * mt * t, d = t * t
        return CGPoint(x: a * p1.x + b * c.x + d * p2.x,
                       y: a * p1.y + b * c.y + d * p2.y)
    }

    private func bezierTangent(_ p1: CGPoint, _ c: CGPoint, _ p2: CGPoint,
                               _ t: Double) -> CGPoint {
        CGPoint(x: 2 * (1 - t) * (c.x - p1.x) + 2 * t * (p2.x - c.x),
                y: 2 * (1 - t) * (c.y - p1.y) + 2 * t * (p2.y - c.y))
    }

    /// Draws aircraft in flight. Plane COUNT encodes frequency (a trunk
    /// route buzzes, a feeder trickles); every plane moves at the same calm
    /// pace so the map never looks frantic. Budgeted so a huge network stays
    /// smooth — the busiest routes get planes first.
    private func drawFlights(ctx: inout GraphicsContext, size: CGSize, radius: Double) {
        guard !reduceMotion else { return }
        let staffed = Set(engine.state.fleet.compactMap(\.assignedRouteID))
        let focusRoute = focusRouteID.flatMap { id in
            engine.state.routes.first { $0.id == id }
        }
        let candidates = (focusRoute.map { [$0] } ?? engine.state.routes)
            .filter { staffed.contains($0.id) && $0.weeklyFrequency > 0 }
            .sorted { $0.weeklyFrequency > $1.weeklyFrequency }
        let roundTrip = 8.0          // seconds out-and-back at x1
        var budget = 40              // global plane cap (perf)
        for route in candidates {
            guard budget > 0,
                  let (p1, c, p2) = arcPoints(for: route, size: size, radius: radius)
            else { continue }
            // ~1 plane per daily departure, capped at 3.
            let daily = Int((Double(route.weeklyFrequency) / 7.0).rounded())
            let count = min(budget, min(3, max(1, daily)))
            let col = color(for: route)
            // A stable per-route offset spaces this route's planes around the
            // cycle and desyncs routes from one another.
            let jitter = Double(abs(route.id.hashValue) % 997) / 997.0
            for i in 0..<count {
                budget -= 1
                let offset = (Double(i) / Double(count) + jitter)
                    .truncatingRemainder(dividingBy: 1.0)
                // One lap is a full round trip: out (0→0.5) then back
                // (0.5→1), so a plane shuttles smoothly and never teleports,
                // and a single plane naturally shows both directions.
                let lap = (flightPhase / roundTrip + offset)
                    .truncatingRemainder(dividingBy: 1.0)
                let outbound = lap < 0.5
                let t = outbound ? lap * 2 : (1 - lap) * 2
                let paramDir = outbound ? 1.0 : -1.0
                let pos = bezier(p1, c, p2, t)
                var tan = bezierTangent(p1, c, p2, t)
                if !outbound { tan = CGPoint(x: -tan.x, y: -tan.y) }

                drawArrivalRipple(ctx: &ctx, lap: lap, origin: p1, dest: p2, color: col)
                drawTrail(ctx: &ctx, p1: p1, c: c, p2: p2, t: t, paramDir: paramDir)
                drawPlane(ctx: &ctx, at: pos, angle: atan2(tan.y, tan.x))
            }
        }
    }

    /// A short fading streak trailing the plane along the arc.
    private func drawTrail(ctx: inout GraphicsContext, p1: CGPoint, c: CGPoint,
                           p2: CGPoint, t: Double, paramDir: Double) {
        let steps = 6
        let dl = 0.03
        var pts = [bezier(p1, c, p2, t)]
        for k in 1...steps {
            let tt = min(1, max(0, t - paramDir * dl * Double(k)))
            pts.append(bezier(p1, c, p2, tt))
        }
        var path = Path()
        path.addLines(pts)
        ctx.stroke(path,
                   with: .linearGradient(
                       Gradient(colors: [.white.opacity(0.5), .white.opacity(0)]),
                       startPoint: pts.first!, endPoint: pts.last!),
                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    /// A quick expanding ring at whichever endpoint the plane just reached —
    /// destination at the half-lap, origin at the wrap.
    private func drawArrivalRipple(ctx: inout GraphicsContext, lap: Double,
                                   origin: CGPoint, dest: CGPoint, color: Color) {
        let w = 0.09
        let hit: (CGPoint, Double)?
        if lap >= 0.5 && lap < 0.5 + w {
            hit = (dest, (lap - 0.5) / w)
        } else if lap < w {
            hit = (origin, lap / w)
        } else {
            hit = nil
        }
        guard let (center, prog) = hit else { return }
        let rr = 3 + prog * 9
        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr,
                                          width: rr * 2, height: rr * 2)),
                   with: .color(color.opacity(0.5 * (1 - prog))),
                   lineWidth: 1.5)
    }

    /// A small dart, nose along +x at angle 0, with a dark outline so it
    /// reads on bright terrain.
    private func drawPlane(ctx: inout GraphicsContext, at p: CGPoint, angle: Double) {
        let len: CGFloat = 5.5, wide: CGFloat = 3.2
        var dart = Path()
        dart.move(to: CGPoint(x: len, y: 0))
        dart.addLine(to: CGPoint(x: -len * 0.7, y: wide))
        dart.addLine(to: CGPoint(x: -len * 0.3, y: 0))
        dart.addLine(to: CGPoint(x: -len * 0.7, y: -wide))
        dart.closeSubpath()
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(angle))
        g.stroke(dart, with: .color(.black.opacity(0.55)), lineWidth: 2)
        g.fill(dart, with: .color(.white))
    }
}

#Preview {
    RouteMapView()
        .environment(GameEngine.previewGame())
        .frame(height: 340)
        .background(Color(red: 0.043, green: 0.071, blue: 0.125))
        .preferredColorScheme(.dark)
}
