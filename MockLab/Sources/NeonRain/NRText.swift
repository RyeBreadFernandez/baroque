import SwiftUI

/// Burned-in subtitle: a bold sans, yellow (or white) with a dark outline and a soft shadow, centred.
struct NRSubtitle: View {
    var text: String
    var size: CGFloat
    var color: Color = NR.subtitle
    var lines: Int = 3
    var alignment: TextAlignment = .center
    var minScale: CGFloat = 0.82

    var body: some View {
        let t = Text(text)
            .font(NR.sub(size))
            .multilineTextAlignment(alignment)
            .lineLimit(lines)
            .truncationMode(.tail)
            .minimumScaleFactor(minScale)
            .lineSpacing(size * 0.08)
        let o = max(0.8, size * 0.065)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                t.foregroundStyle(Color(hex: 0x050808)).offset(x: o * cos(a), y: o * sin(a))
            }
            t.foregroundStyle(color)
                .nrFringe(0.45, opacity: 0.35)
        }
        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1.5)
    }
}

/// Voice-over timestamp: a small amber mono line, like narration over the first frame of a scene.
struct NRCaption: View {
    var text: String
    var size: CGFloat = 9
    var color: Color = NR.sodium

    var body: some View {
        Text(text)
            .font(NR.monoBold(size))
            .tracking(size * 0.12)
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 3)
            .nrLegible()
            .lineLimit(1)
            .fixedSize()
    }
}

/// Small caps source line for the quote, e.g. "— GEORGE ORWELL, 1984".
struct NRSource: View {
    var text: String
    var size: CGFloat = 9

    var body: some View {
        Text("— " + text.uppercased())
            .font(NR.mono(size))
            .tracking(size * 0.14)
            .foregroundStyle(NR.paper.opacity(0.88))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.8)
            .nrLegible()
    }
}
