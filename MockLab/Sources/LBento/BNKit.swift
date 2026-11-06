import SwiftUI

// Bento: each widget is a box of separate painted tiles set into the scene. This file holds the grid
// (one inset, one gutter, nested corners), the three tile materials (a raised slab cut from the espresso
// board, a well carved into the scene, and a framed window onto the scene) and the gilt studs that sit
// where gutters meet.

enum BN {
    /// Grid edge to widget edge. The tiles' corners nest inside the widget's 22 pt corners.
    static let inset: CGFloat = 9
    static let gutter: CGFloat = 7
    static let radius: CGFloat = 22 - inset
    /// Text inside a tile: inset + pad keeps it 18 pt from the widget edge (WidgetKit asks for 16).
    static let pad: CGFloat = 9

    static func grid(_ size: CGSize) -> CGRect {
        CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
    }

    /// A point given in fractions of a tile, returned in fractions of the widget (the scene's coordinates).
    static func unit(_ x: CGFloat, _ y: CGFloat, in r: CGRect, of size: CGSize) -> CGPoint {
        CGPoint(x: (r.minX + x * r.width) / size.width, y: (r.minY + y * r.height) / size.height)
    }

    /// A ridge composed for a window tile: key points are fractions of the window; the crest carries on at
    /// its end heights to both widget edges, so the gutters beside the window show the same range.
    static func ridge(_ keys: [(CGFloat, CGFloat)], window r: CGRect, size: CGSize, seed: UInt64,
                      roughness: CGFloat = 0.2) -> RidgeProfile {
        var pts = keys.map { unit($0.0, $0.1, in: r, of: size) }
        if let first = pts.first, first.x > 0.001 {
            let n = max(1, Int((first.x / 0.06).rounded(.up)))
            pts.insert(contentsOf: (0..<n).map { CGPoint(x: first.x * CGFloat($0) / CGFloat(n), y: first.y) }, at: 0)
        }
        if let last = pts.last, last.x < 0.999 {
            let n = max(1, Int(((1 - last.x) / 0.06).rounded(.up)))
            pts += (1...n).map { CGPoint(x: last.x + (1 - last.x) * CGFloat($0) / CGFloat(n), y: last.y) }
        }
        return RidgeProfile(keys: pts, seed: seed, roughness: roughness)
    }
}

/// A grid track: fixed points, or a share of what is left.
enum BNTrack {
    case pt(CGFloat)
    case fr(CGFloat)
}

extension CGRect {
    func bnColumns(_ tracks: [BNTrack]) -> [CGRect] { bnSplit(tracks, vertical: false) }
    func bnRows(_ tracks: [BNTrack]) -> [CGRect] { bnSplit(tracks, vertical: true) }

    private func bnSplit(_ tracks: [BNTrack], vertical: Bool) -> [CGRect] {
        let length = (vertical ? height : width) - BN.gutter * CGFloat(max(0, tracks.count - 1))
        var fixed: CGFloat = 0, shares: CGFloat = 0
        for t in tracks {
            switch t {
            case .pt(let v): fixed += v
            case .fr(let v): shares += v
            }
        }
        let perShare = shares > 0 ? max(0, length - fixed) / shares : 0
        var cursor = vertical ? minY : minX
        var out: [CGRect] = []
        for t in tracks {
            let len: CGFloat
            switch t {
            case .pt(let v): len = v
            case .fr(let v): len = v * perShare
            }
            out.append(vertical ? CGRect(x: minX, y: cursor, width: width, height: len)
                                : CGRect(x: cursor, y: minY, width: len, height: height))
            cursor += len + BN.gutter
        }
        return out
    }
}

extension View {
    /// Sets a tile at its rect (points of the widget) inside the widget's ZStack.
    func bnPlace(_ r: CGRect) -> some View {
        frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
    }

    /// A raised espresso tile: brushed face cut from one board, lit chamfer, gold inlay, cut side, one shadow.
    func bnSlab(_ r: CGRect, inlay: Bool = true) -> some View {
        background(BNSlab(rect: r, inlay: inlay))
    }

    /// A well carved into the scene; the painting shows through, darkened.
    func bnWell(tint: Double = 0.34) -> some View {
        background(BNWell(tint: tint))
    }
}

// MARK: - Materials

/// The espresso board. Every slab in a widget is cut from the same painted board at the same brush scale,
/// each showing its own part of it, so small tiles don't magnify the strokes and neighbours don't repeat.
struct BNBoard: View {
    var rect: CGRect

    var body: some View {
        // PaintPanel is 330 x 250 px: about 1 px per point, the scale the shipped task slab shows.
        let tex = CGSize(width: 330, height: 250)
        let k = max(1, rect.width / tex.width, rect.height / tex.height)
        let board = CGSize(width: tex.width * k, height: tex.height * k)
        let slackX = max(0, board.width - rect.width), slackY = max(0, board.height - rect.height)
        let dx = slackX > 0 ? rect.minX.truncatingRemainder(dividingBy: slackX) : 0
        let dy = slackY > 0 ? (rect.minY * 1.7).truncatingRemainder(dividingBy: slackY) : 0
        StoneMaterial.panel.base
            .overlay(alignment: .topLeading) {
                Image(StoneMaterial.panel.imageName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: board.width, height: board.height)
                    .offset(x: -dx, y: -dy)
            }
            .overlay(CanvasWeave())
            .clipped()
    }
}

struct BNSlab: View {
    var rect: CGRect
    var inlay: Bool = true
    var depth: CGFloat = 2.5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BN.radius, style: .continuous)
        ZStack {
            // The cut side under the face, and one tight cast shadow into the gutter.
            shape
                .fill(LinearGradient(colors: StoneMaterial.panel.edge, startPoint: .top, endPoint: .bottom))
                .offset(y: depth)
                .shadow(color: Stone.shadow.opacity(0.65), radius: 3.5, x: 0, y: depth + 1)
            BNBoard(rect: rect)
                .overlay(StoneMaterial.panel.lighting)
                .clipShape(shape)
                .overlay(ChamferRim(shape: shape))
            if inlay {
                shape.inset(by: 3.5).stroke(Stone.gold.opacity(0.3), lineWidth: 0.6)
            }
        }
    }
}

struct BNWell: View {
    var radius: CGFloat = BN.radius
    var tint: Double = 0.34

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(Stone.night.opacity(tint))
            .overlay(CarvedRecess(shape: shape))
    }
}

/// The frame round a window tile: the cut into the scene (shadow under the top lip, lit lower lip), a gold
/// hairline just inside, and a sparkle set into its top edge like the storybook plate frame.
struct BNWindowFrame: View {
    var radius: CGFloat = BN.radius
    var ornament: Bool = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .top) {
            shape
                .stroke(Stone.shadow.opacity(0.8), lineWidth: 7)
                .blur(radius: 3)
                .offset(y: 2.2)
                .clipShape(shape)
            shape.strokeBorder(
                LinearGradient(colors: [Stone.shadow.opacity(0.75), .clear, Stone.goldBright.opacity(0.3)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
            shape.inset(by: 3.5)
                .stroke(Stone.gold.opacity(0.5), lineWidth: 0.7)
            if ornament {
                BNStud(size: 8)
                    .offset(y: 3.5 - 4.8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A small gilt sparkle in a dark halo, set where gutters meet and into window frames.
struct BNStud: View {
    var size: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Stone.night.opacity(0.85), Stone.night.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.95))
                .frame(width: size * 1.9, height: size * 1.9)
            Circle()
                .fill(RadialGradient(colors: [Stone.goldBright.opacity(0.5), Stone.goldBright.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.75))
                .frame(width: size * 1.5, height: size * 1.5)
            Sparkle()
                .fill(Stone.gold)
                .frame(width: size, height: size * 1.2)
        }
        .frame(width: size, height: size * 1.2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The widget's rim over the whole box: the gold hairline round the plate and the lit and shaded edge.
struct BNRim: View {
    var body: some View {
        ZStack {
            GoldFrame(inset: 4.5, ornament: false)
            SlabBevel()
        }
        .allowsHitTesting(false)
    }
}
