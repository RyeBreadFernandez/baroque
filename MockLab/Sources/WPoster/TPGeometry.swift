import SwiftUI

// The Matterhorn as a screen print: flat ink shapes built from its traced skyline (TPProfile), in pyramid units
// (summit at 0,0, x right, y down, 1 = the drop to the foot of the steep left face), mapped to a widget by one
// uniform scale. The face structure follows Old Master Cover's painter (Textures/old-master-cover/make.py, flanks()
// and matterhorn()): the left face in shadow, the lit east face, the dark band under the summit ridge that runs on
// down from the notch as the Hornli ridge, and the north face's snow under the shoulder.

/// Deterministic SplitMix64, so every print is the same print.
struct TPRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat { CGFloat(next() >> 11) / CGFloat(UInt64(1) << 53) }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }
}

/// Piecewise-linear interpolation over ascending xs (ends held level).
func tpInterp(_ v: CGFloat, _ xs: [CGFloat], _ ys: [CGFloat]) -> CGFloat {
    guard let first = xs.first, let last = xs.last else { return 0 }
    if v <= first { return ys[0] }
    if v >= last { return ys[ys.count - 1] }
    var lo = 0, hi = xs.count - 1
    while hi - lo > 1 {
        let mid = (lo + hi) / 2
        if xs[mid] <= v { lo = mid } else { hi = mid }
    }
    let span = xs[hi] - xs[lo]
    let t = span > 0 ? (v - xs[lo]) / span : 0
    return ys[lo] + (ys[hi] - ys[lo]) * t
}

enum TPPeak {
    /// The skyline's depth below the summit at `u` pyramid heights across.
    static func skyline(_ u: CGFloat) -> CGFloat { tpInterp(u, TPProfile.x, TPProfile.y) }

    /// The steep left face as depth -> x, made monotone (the edge only ever widens going down).
    static let left: (depth: [CGFloat], x: [CGFloat]) = {
        var d: [CGFloat] = [], x: [CGFloat] = []
        var deepest: CGFloat = 0
        for i in stride(from: TPProfile.x.count - 1, through: 0, by: -1) where TPProfile.x[i] <= 0 && TPProfile.x[i] >= TPProfile.foot.x {
            deepest = max(deepest, TPProfile.y[i])
            if let last = d.last, deepest <= last { continue }
            d.append(deepest); x.append(TPProfile.x[i])
        }
        return (d, x)
    }()

    /// The summit ridge, the notch and the shoulder as depth -> x, made monotone.
    static let right: (depth: [CGFloat], x: [CGFloat]) = {
        var d: [CGFloat] = [], x: [CGFloat] = []
        var deepest: CGFloat = 0
        for i in TPProfile.x.indices where TPProfile.x[i] >= 0 && TPProfile.x[i] <= TPProfile.shoulder.x {
            deepest = max(deepest, TPProfile.y[i])
            if let last = d.last, deepest <= last { continue }
            d.append(deepest); x.append(TPProfile.x[i])
        }
        return (d, x)
    }()

    static func leftEdge(_ v: CGFloat) -> CGFloat {
        v <= TPProfile.foot.y ? tpInterp(v, left.depth, left.x) : TPProfile.foot.x - 0.45 * (v - TPProfile.foot.y)
    }

    static func rightEdge(_ v: CGFloat) -> CGFloat {
        let end = right.depth.last ?? 1.3
        return v <= end ? tpInterp(v, right.depth, right.x) : (right.x.last ?? 1.3) + 1.2 * (v - end)
    }

    /// Edge of the shadowed left face: from just right of the summit, leaning down to the left.
    static func shadowLine(_ v: CGFloat) -> CGFloat { 0.03 - 0.33 * v }

    /// The Hornli ridge below the notch (its centre line).
    static func hornli(_ v: CGFloat) -> CGFloat {
        tpInterp(v, [TPProfile.notch.y, 0.825, 1.026, 1.226, 1.6], [TPProfile.notch.x - 0.02, 0.579, 0.723, 0.838, 1.1])
    }
    static func hornliHalfWidth(_ v: CGFloat) -> CGFloat { tpInterp(v, [TPProfile.notch.y, 0.9, 1.3], [0.05, 0.035, 0.03]) }
    static func summitBand(_ v: CGFloat) -> CGFloat { tpInterp(v, [0, 0.12, 0.35, TPProfile.notch.y], [0, 0.03, 0.06, 0.07]) }
}

/// One placement of the mountain on a canvas, with every ink separation as a path in points.
struct TPMountain {
    var summit: CGPoint
    var height: CGFloat
    var size: CGSize

    let land: Path        // everything below the skyline (lower ridges and the pyramid)
    let pyramid: Path
    let shadowFace: Path
    let band: Path        // under the summit ridge, then the Hornli ridge
    let northFace: Path
    let eastFace: Path    // what is left of the pyramid: the lit east face
    let crest: Path       // the lit rim of the summit ridge
    let rock: Path        // dark streaks on the lit faces
    let ledges: Path      // snow ledges on the shadowed face
    let ridgeSnow: Path   // snowcaps on the lower ridges
    let ridgeShade: Path  // the shaded flanks of the lower ridges

    init(summit: CGPoint, height: CGFloat, size: CGSize, seed: UInt64 = 4478) {
        self.summit = summit
        self.height = height
        self.size = size
        let H = height
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: summit.x + u * H, y: summit.y + v * H) }
        let vBottom = (size.height - summit.y) / H + 0.3
        let uMin = (-4 - summit.x) / H, uMax = (size.width + 4 - summit.x) / H

        // Land: the skyline across the canvas, every traced point inside it, then down to the bottom.
        var land = Path()
        land.move(to: p(uMin, TPPeak.skyline(uMin)))
        for (x, y) in zip(TPProfile.x, TPProfile.y) where x > uMin && x < uMax { land.addLine(to: p(x, y)) }
        land.addLine(to: p(uMax, TPPeak.skyline(uMax)))
        land.addLine(to: p(uMax, vBottom))
        land.addLine(to: p(uMin, vBottom))
        land.closeSubpath()
        self.land = land

        let steps = 90
        func depths(_ a: CGFloat, _ b: CGFloat) -> [CGFloat] { (0...steps).map { a + (b - a) * CGFloat($0) / CGFloat(steps) } }

        var pyr = Path()
        pyr.move(to: p(0, 0))
        for v in depths(0, vBottom) { pyr.addLine(to: p(TPPeak.rightEdge(v), v)) }
        for v in depths(0, vBottom).reversed() { pyr.addLine(to: p(TPPeak.leftEdge(v), v)) }
        pyr.closeSubpath()
        let pyramid = pyr.intersection(land)
        self.pyramid = pyramid

        var shadow = Path()
        shadow.move(to: p(0.03, -0.05))
        for v in depths(0, vBottom) { shadow.addLine(to: p(TPPeak.shadowLine(v), v)) }
        shadow.addLine(to: p(uMin - 1, vBottom))
        shadow.addLine(to: p(uMin - 1, -0.05))
        shadow.closeSubpath()
        shadowFace = shadow.intersection(pyramid)

        // The band: under the summit ridge to the notch, then either side of the Hornli ridge.
        let ny = TPProfile.notch.y
        var b = Path()
        let upper = depths(0.05, ny), lower = depths(ny, vBottom)
        b.move(to: p(TPPeak.rightEdge(0.05) - TPPeak.summitBand(0.05), 0.05))
        for v in upper { b.addLine(to: p(TPPeak.rightEdge(v) - TPPeak.summitBand(v), v)) }
        for v in lower { b.addLine(to: p(TPPeak.hornli(v) - TPPeak.hornliHalfWidth(v), v)) }
        for v in lower.reversed() { b.addLine(to: p(TPPeak.hornli(v) + TPPeak.hornliHalfWidth(v), v)) }
        for v in upper.reversed() { b.addLine(to: p(TPPeak.rightEdge(v) + 0.4, v)) }
        b.closeSubpath()
        band = b.intersection(pyramid)

        var n = Path()
        n.move(to: p(TPPeak.hornli(ny) + TPPeak.hornliHalfWidth(ny), ny))
        for v in lower { n.addLine(to: p(TPPeak.hornli(v) + TPPeak.hornliHalfWidth(v), v)) }
        n.addLine(to: p(uMax + 1, vBottom))
        n.addLine(to: p(uMax + 1, ny))
        n.closeSubpath()
        northFace = n.intersection(pyramid)
        eastFace = pyramid.subtracting(shadowFace).subtracting(band).subtracting(northFace)

        // The crest of the summit ridge catches the light, from just under the summit to the notch.
        let rim = max(0.018, 1.4 / H)
        var c = Path()
        let crestDepths = depths(0.0, ny + 0.01)
        c.move(to: p(TPPeak.rightEdge(0), 0))
        for v in crestDepths { c.addLine(to: p(TPPeak.rightEdge(v) + 0.01, v)) }
        for v in crestDepths.reversed() {
            let w = rim * (0.6 + 0.8 * min(1, v / 0.2))
            c.addLine(to: p(TPPeak.rightEdge(v) - w, v))
        }
        c.closeSubpath()
        crest = c.intersection(pyramid)

        var rng = TPRandom(seed)
        // Rock on the lit east face: streaks down its fall line (down and a little left), thick and many near the
        // summit, thinning out where the snow lies deeper below.
        var r = Path()
        for _ in 0..<46 {
            let v0 = pow(rng.unit(), 1.5) * 0.95 + 0.04
            let lo = TPPeak.shadowLine(v0), hi = TPPeak.rightEdge(v0) - TPPeak.summitBand(v0)
            guard hi > lo else { continue }
            let u0 = lo + (hi - lo) * rng.range(0.02, 1.0)
            let len = rng.range(0.07, 0.24) * (1.1 - 0.5 * v0)
            let w = rng.range(0.010, 0.026) * (1.15 - 0.6 * v0)
            TPMountain.streak(&r, from: (u0, v0), angle: .pi / 2 + 0.36 + rng.range(-0.16, 0.16), length: len, width: w,
                              wobble: rng.range(-0.25, 0.25), map: p)
        }
        // Rock ribs high on the east face, where the snow can't hold: angular patches along the fall line.
        for _ in 0..<11 {
            let v0 = rng.range(0.07, 0.5)
            let lo = TPPeak.shadowLine(v0), hi = TPPeak.rightEdge(v0) - TPPeak.summitBand(v0)
            guard hi > lo + 0.04 else { continue }
            let u0 = lo + (hi - lo) * rng.range(0.08, 0.85)
            TPMountain.rib(&r, from: (u0, v0), angle: .pi / 2 + 0.34 + rng.range(-0.1, 0.1), length: rng.range(0.07, 0.17),
                           width: rng.range(0.022, 0.045), rng: &rng, map: p)
        }
        // The north face: streaks down to the right, fewer.
        for _ in 0..<16 {
            let v0 = rng.range(ny + 0.04, 1.25)
            let u0 = TPPeak.hornli(v0) + TPPeak.hornliHalfWidth(v0) + rng.range(0.02, 0.5)
            TPMountain.streak(&r, from: (u0, v0), angle: .pi / 2 - 0.62 + rng.range(-0.1, 0.1),
                              length: rng.range(0.05, 0.16), width: rng.range(0.008, 0.02), wobble: rng.range(-0.2, 0.2), map: p)
        }
        rock = r.intersection(pyramid.subtracting(shadowFace).subtracting(band))

        // Snow on the ledges of the shadowed face: pale slivers leaning steeply down to the left.
        var l = Path()
        for _ in 0..<30 {
            let v0 = rng.range(0.08, 1.05)
            let lo = TPPeak.leftEdge(v0), hi = TPPeak.shadowLine(v0)
            guard hi > lo else { continue }
            let u0 = lo + (hi - lo) * rng.range(0.1, 1.0)
            TPMountain.streak(&l, from: (u0, v0), angle: .pi / 2 + 0.6 + rng.range(-0.12, 0.12),
                              length: rng.range(0.05, 0.17), width: rng.range(0.008, 0.02), wobble: rng.range(-0.3, 0.3), map: p)
        }
        // And a few catching the light on the band.
        for _ in 0..<10 {
            let v0 = rng.range(0.15, 1.2)
            let centre = v0 < ny ? TPPeak.rightEdge(v0) - TPPeak.summitBand(v0) * 0.5 : TPPeak.hornli(v0)
            TPMountain.streak(&l, from: (centre + rng.range(-0.03, 0.03), v0), angle: .pi / 2 - 0.5,
                              length: rng.range(0.04, 0.1), width: rng.range(0.006, 0.014), wobble: 0, map: p)
        }
        ledges = l.intersection(shadowFace.union(band))

        // The lower ridges either side: snowcaps a little way down from the crest with a torn lower edge, and the
        // flanks that face away from the light.
        var snow = Path(), shade = Path()
        let ridgeSteps = Int((uMax - uMin) * 60)
        var top: [CGPoint] = [], low: [CGPoint] = []
        for i in 0...ridgeSteps {
            let u = uMin + (uMax - uMin) * CGFloat(i) / CGFloat(ridgeSteps)
            let v = TPPeak.skyline(u)
            top.append(p(u, v - 0.02))
            let tear = rng.range(0.0, 1.0)
            let depth = 0.035 + 0.05 * (0.5 + 0.5 * sin(u * 9.3 + 1.7)) + 0.035 * tear * tear
            low.append(p(u, v + depth))
        }
        snow.move(to: top[0])
        for q in top.dropFirst() { snow.addLine(to: q) }
        for q in low.reversed() { snow.addLine(to: q) }
        snow.closeSubpath()
        // Shaded flanks: under each local summit of the lower skyline, a wedge falling away to the left.
        var lastPeak: CGFloat? = nil
        for i in stride(from: 4, to: TPProfile.x.count - 4, by: 1) {
            let x = TPProfile.x[i], y = TPProfile.y[i]
            guard x > uMin, x < uMax, x < TPProfile.foot.x - 0.05 || x > TPProfile.shoulder.x - 0.1 else { continue }
            let isPeak = y < TPProfile.y[i - 4] && y < TPProfile.y[i + 4] && y <= TPProfile.y[i - 1] && y <= TPProfile.y[i + 1]
            guard isPeak, lastPeak.map({ x - $0 > 0.12 }) ?? true else { continue }
            lastPeak = x
            var wedge = Path()
            wedge.move(to: p(x, y - 0.01))
            wedge.addLine(to: p(x - 0.05, y + 0.4))
            wedge.addLine(to: p(x - 0.5, y + 0.4))
            wedge.addLine(to: p(x - 0.5, y - 0.05))
            wedge.closeSubpath()
            shade.addPath(wedge)
        }
        let lowerRidges = land.subtracting(pyramid)
        ridgeSnow = snow.intersection(lowerRidges)
        ridgeShade = shade.intersection(lowerRidges)
    }

    /// An angular rock rib: a jagged sliver, widest a third of the way down, pointed at both ends.
    static func rib(_ path: inout Path, from start: (CGFloat, CGFloat), angle: CGFloat, length: CGFloat, width: CGFloat,
                    rng: inout TPRandom, map: (CGFloat, CGFloat) -> CGPoint) {
        let (u0, v0) = start
        let dx = cos(angle), dy = sin(angle)
        let nx = -dy, ny = dx
        let profile: [(CGFloat, CGFloat)] = [(0, 0.15), (0.18, 0.9), (0.38, 1.0), (0.62, 0.7), (0.82, 0.45), (1, 0)]
        var left: [CGPoint] = [], right: [CGPoint] = []
        for (t, k) in profile {
            let cu = u0 + dx * length * t, cv = v0 + dy * length * t
            let a = width * 0.5 * k * rng.range(0.6, 1.2), b = width * 0.5 * k * rng.range(0.6, 1.2)
            left.append(map(cu + nx * a, cv + ny * a))
            right.append(map(cu - nx * b, cv - ny * b))
        }
        path.move(to: left[0])
        for q in left.dropFirst() { path.addLine(to: q) }
        for q in right.reversed() { path.addLine(to: q) }
        path.closeSubpath()
    }

    /// A tapered brush streak: wide at its head, a point at its tail, bowed a little.
    static func streak(_ path: inout Path, from start: (CGFloat, CGFloat), angle: CGFloat, length: CGFloat, width: CGFloat,
                       wobble: CGFloat, map: (CGFloat, CGFloat) -> CGPoint) {
        let (u0, v0) = start
        let dx = cos(angle), dy = sin(angle)
        let nx = -dy, ny = dx
        let mid = (u0 + dx * length * 0.5 + nx * wobble * width * 2, v0 + dy * length * 0.5 + ny * wobble * width * 2)
        let tail = (u0 + dx * length, v0 + dy * length)
        path.move(to: map(u0 + nx * width * 0.5, v0 + ny * width * 0.5))
        path.addQuadCurve(to: map(tail.0, tail.1), control: map(mid.0 + nx * width * 0.45, mid.1 + ny * width * 0.45))
        path.addQuadCurve(to: map(u0 - nx * width * 0.5, v0 - ny * width * 0.5), control: map(mid.0 - nx * width * 0.45, mid.1 - ny * width * 0.45))
        path.closeSubpath()
    }
}

/// A halftone screen: dots on a 45-degree lattice, each as big as `radius` says (skipped when tiny).
func tpHalftone(in rect: CGRect, pitch: CGFloat, radius: (CGPoint) -> CGFloat) -> Path {
    var path = Path()
    let rowStep = pitch / 2
    var j = 0
    var y = rect.minY
    while y <= rect.maxY + rowStep {
        var x = rect.minX + (j % 2 == 0 ? 0 : pitch / 2)
        while x <= rect.maxX + pitch {
            let c = CGPoint(x: x, y: y)
            let r = radius(c)
            if r > 0.14 { path.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)) }
            x += pitch
        }
        y += rowStep
        j += 1
    }
    return path
}
