import SwiftUI

// The Battery widget in rococo (2026-11-04, after "can we get spotify or battery percentage related widgets"): the
// iPhone's own charge as gold inlaid along an arc carved into the limestone, the figure in Didot below it. iOS gives
// widgets the phone's battery only (never AirPods or a Watch), and only when the widget refreshes, so the time of the
// reading is written under it.

struct BatteryReading: Codable, Hashable {
    /// 0...1, or nil when iOS won't say (the simulator).
    var level: Double?
    var charging: Bool
    var at: Date
}

struct RococoBatteryView: View {
    var reading: BatteryReading

    var body: some View {
        RococoFrame(size: .small) {
            RococoBattery(reading: reading)
        }
    }
}

struct RococoBattery: View {
    var reading: BatteryReading

    var body: some View {
        let size = BaroqueSize.small.designSize
        let arc = SkyArc(centerX: 0.5, horizon: 0.64, radiusX: 0.36, radiusY: 0.38)
        let level = reading.level.map { min(1, max(0, $0)) }
        let low = (level ?? 1) <= 0.2 && !reading.charging
        ZStack(alignment: .topLeading) {
            RococoSlab()
            Text("Battery").font(RococoType.serif(15.5)).foregroundStyle(RococoInk.ink)
                .rococoBaseline(x: 16, y: 27, in: size)
            RococoCarve(shape: RococoArcPath(arc: arc, from: 0, to: 1), width: 1.8)
            if let level {
                RococoArcPath(arc: arc, from: 0, to: level)
                    .stroke(low ? AnyShapeStyle(RococoInk.terracotta) : AnyShapeStyle(RococoMaterial.gold.gradient),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .shadow(color: RococoInk.shadow.opacity(0.3), radius: 0.4, x: 0.3, y: 0.5)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFCEBB4), Color(hex: 0xE6B85E), Color(hex: 0xB07E31)],
                                         center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: 5))
                    .frame(width: 8, height: 8)
                    .rococoRelief(0.7)
                    .position(arc.point(level, in: size))
            }
            Group {
                if let level {
                    Text("\(Int((level * 100).rounded()))").font(RococoType.serif(36))
                        + Text("%").font(RococoType.serif(17)).baselineOffset(13)
                } else {
                    Text("–").font(RococoType.serif(36))
                }
            }
            .foregroundStyle(low ? RococoInk.terracotta : RococoInk.ink)
            .fixedSize()
            .frame(width: size.width)
            .rococoBaseline(x: 0, y: 100, in: size)
            Text(caption)
                .font(RococoType.sansMedium(6.5))
                .tracking(1.6)
                .foregroundStyle(level == nil || low ? RococoInk.terracotta : RococoInk.inkSoft)
                .frame(width: size.width)
                .rococoBaseline(x: 0, y: 126, in: size)
            Text("as of \(RococoWords.clock(reading.at))")
                .font(RococoType.italic(11.5))
                .foregroundStyle(RococoInk.inkSoft)
                .frame(width: size.width)
                .rococoBaseline(x: 0, y: 148, in: size)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var caption: String {
        guard let level = reading.level else { return "LEVEL UNAVAILABLE" }
        if reading.charging { return level >= 0.995 ? "FULL" : "CHARGING" }
        return level <= 0.2 ? "LOW" : "IPHONE"
    }
}
