import SwiftUI

// Quote widget: the quote written on a taped-up card in front of the diorama, a balloon drifting
// past the mountains, and a stacked-paper "next" button sitting in the meadow.

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// The quote and its author, auto-fitted over decreasing sizes (as the app does with ViewThatFits).
struct FittedQuote: View {
    var quote: Quote
    var sizes: [CGFloat]
    var authorSize: CGFloat

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes, id: \.self) { s in
                block(s)
            }
            block(sizes.last ?? 12).minimumScaleFactor(0.6)
        }
    }

    private func block(_ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: s * 0.4) {
            Text(quote.text)
                .font(.pdAvenir(s, "DemiBold"))
                .foregroundStyle(PD.ink)
                .lineSpacing(s * 0.06)
                .fixedSize(horizontal: false, vertical: true)
            if let a = quote.author {
                Text("— " + a)
                    .font(.pdChalk(authorSize, "Regular"))
                    .foregroundStyle(PD.coralDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Large

struct QuoteLarge: View {
    var quote: Quote
    private let size = Mock.size(.large)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Diorama(size: size, pieces: scene, glow: pt(0.12, 0.1))
            card
                .frame(width: 314, height: 172)
                .rotationEffect(.degrees(-0.8))
                .position(x: size.width / 2, y: 219)
            Diorama(size: size, pieces: front, sky: false)
            NextButton()
                .position(x: size.width - 31, y: size.height - 31)
            ShadowboxRim(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var card: some View {
        FittedQuote(quote: quote, sizes: [24, 23, 22, 21, 20, 19, 18, 17, 16], authorSize: 14)
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)
            .frame(maxHeight: .infinity, alignment: .center)
            .background(IndexCard(seed: 41, dogEar: 16, lift: 3.6))
            .overlay(alignment: .topLeading) {
                WashiTape(color: PD.mint, width: 54, angle: -14, seed: 5).offset(x: -14, y: -4)
            }
            .overlay(alignment: .topTrailing) {
                WashiTape(color: PD.butter, width: 54, angle: 12, seed: 6).offset(x: 14, y: -4)
            }
    }

    private var scene: [Piece] {
        [
            .sun(pt(0.13, 0.1), 32),
            .cloud(pt(0.4, 0.06), 40, 11),
            .cloud(pt(0.7, 0.14), 30, 12),
            .ridge(Ridge(pts: [pt(-0.05, 0.25), pt(0.22, 0.2), pt(0.5, 0.235), pt(0.78, 0.19), pt(1.05, 0.23)],
                         color: Color(hex: 0xDDEDF4), smooth: true, lift: 1.2, seed: 400)),
            .balloon(pt(0.86, 0.035), 22),
            .ridge(Ridge(pts: [pt(-0.05, 0.3), pt(0.08, 0.23), pt(0.19, 0.29), pt(0.36, 0.13), pt(0.5, 0.25), pt(0.63, 0.18),
                               pt(0.77, 0.27), pt(0.9, 0.2), pt(1.05, 0.28)],
                         peaks: [1, 3, 5, 7], color: PD.periwinkle, shade: PD.periShade, snow: 9, lift: 2, seed: 401)),
            .ridge(Ridge(pts: [pt(-0.05, 0.33), pt(0.13, 0.27), pt(0.28, 0.335), pt(0.46, 0.26), pt(0.6, 0.325), pt(0.76, 0.275),
                               pt(0.9, 0.33), pt(1.05, 0.29)],
                         peaks: [1, 3, 5], color: PD.teal, shade: PD.tealShade, lift: 2.2, seed: 402)),
            .ridge(Ridge(pts: [pt(-0.05, 0.36), pt(0.25, 0.325), pt(0.5, 0.355), pt(0.75, 0.32), pt(1.05, 0.35)],
                         color: PD.peach, smooth: true, lift: 2.3, seed: 403)),
            .forest(Forest(ground: [pt(-0.05, 0.395), pt(0.5, 0.385), pt(1.05, 0.395)], color: PD.sage,
                           count: 19, heights: 17...25, lift: 2.2, seed: 404)),
            .ridge(Ridge(pts: [pt(-0.05, 0.84), pt(0.3, 0.82), pt(0.6, 0.85), pt(1.05, 0.82)],
                         color: PD.mint, smooth: true, lift: 2.3, seed: 407)),
            .forest(Forest(ground: [pt(-0.05, 0.92), pt(0.5, 0.905), pt(1.05, 0.92)], color: PD.pine,
                           xs: 0.3...0.85, count: 9, heights: 18...27, lift: 2.6, seed: 405)),
            .ridge(Ridge(pts: [pt(-0.05, 0.9), pt(0.2, 0.885), pt(0.5, 0.93), pt(0.8, 0.915), pt(1.05, 0.93)],
                         color: PD.meadow, smooth: true, lift: 2.6, seed: 406)),
            .cabin(pt(0.16, 0.915), 30),
            .confetti(CGRect(x: 0.06, y: 0.94, width: 0.68, height: 0.04), 14, 9)
        ]
    }

    private var front: [Piece] {
        [.tufts([pt(0.05, 0.98), pt(0.42, 0.985), pt(0.7, 0.98)], PD.sage, 9)]
    }
}

// MARK: - Medium

struct QuoteMedium: View {
    var quote: Quote
    private let size = Mock.size(.medium)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Diorama(size: size, pieces: scene, glow: pt(0.88, 0.2))
            card
                .frame(width: 232, height: 136)
                .rotationEffect(.degrees(0.7))
                .position(x: 130, y: 83)
            NextButton()
                .position(x: size.width - 31, y: size.height - 31)
            ShadowboxRim(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var card: some View {
        FittedQuote(quote: quote, sizes: [19, 18, 17, 16, 15, 14, 13], authorSize: 12)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .frame(maxHeight: .infinity, alignment: .center)
            .background(IndexCard(seed: 51, dogEar: 13, lift: 3.2))
            .overlay(alignment: .top) {
                WashiTape(color: PD.coral, width: 48, angle: -5, seed: 7).offset(y: -7)
            }
    }

    private var scene: [Piece] {
        [
            .sun(pt(0.885, 0.21), 28),
            .cloud(pt(0.86, 0.47), 30, 13),
            .balloon(pt(0.735, 0.08), 19),
            .ridge(Ridge(pts: [pt(0.6, 0.7), pt(0.8, 0.6), pt(1.05, 0.55)], color: Color(hex: 0xDDEDF4), smooth: true, lift: 1.2, seed: 500)),
            .ridge(Ridge(pts: [pt(0.6, 0.9), pt(0.71, 0.62), pt(0.8, 0.72), pt(0.9, 0.52), pt(1.05, 0.7)],
                         peaks: [1, 3], color: PD.periwinkle, shade: PD.periShade, snow: 8, lift: 1.8, seed: 501)),
            .ridge(Ridge(pts: [pt(-0.05, 0.8), pt(0.5, 0.78), pt(0.75, 0.74), pt(0.92, 0.79), pt(1.05, 0.76)],
                         color: PD.peach, smooth: true, lift: 2, seed: 502)),
            .forest(Forest(ground: [pt(-0.05, 0.9), pt(0.7, 0.88), pt(1.05, 0.9)], color: PD.pine,
                           xs: 0.6...1.02, count: 7, heights: 13...20, lift: 2.2, seed: 503)),
            .ridge(Ridge(pts: [pt(-0.05, 0.95), pt(0.6, 0.93), pt(1.05, 0.94)], color: PD.meadow, smooth: true, lift: 2, seed: 504)),
            .confetti(CGRect(x: 0.7, y: 0.95, width: 0.12, height: 0.04), 4, 10)
        ]
    }
}

// MARK: - Small

struct QuoteSmall: View {
    var quote: Quote
    private let size = Mock.size(.small)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Diorama(size: size, pieces: scene, glow: pt(0.85, 0.12))
            card
                .frame(width: 140, height: 92)
                .rotationEffect(.degrees(-1.2))
                .position(x: 82, y: 62)
            ShadowboxRim(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private var card: some View {
        FittedQuote(quote: quote, sizes: [18, 17, 16, 15, 14, 13, 12], authorSize: 11)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxHeight: .infinity, alignment: .center)
            .background(IndexCard(seed: 61, dogEar: 11, lift: 3))
            .overlay(alignment: .top) {
                WashiTape(color: PD.butter, width: 38, angle: 4, seed: 8).offset(y: -7)
            }
    }

    private var scene: [Piece] {
        [
            .ridge(Ridge(pts: [pt(-0.05, 0.72), pt(0.3, 0.66), pt(0.6, 0.7), pt(1.05, 0.64)], color: Color(hex: 0xDDEDF4),
                         smooth: true, lift: 1.2, seed: 600)),
            .sun(pt(0.8, 0.7), 18),
            .ridge(Ridge(pts: [pt(-0.05, 0.84), pt(0.17, 0.72), pt(0.36, 0.82), pt(0.58, 0.69), pt(0.72, 0.79), pt(0.9, 0.73), pt(1.05, 0.8)],
                         peaks: [1, 3, 5], color: PD.periwinkle, shade: PD.periShade, snow: 6, lift: 1.8, seed: 601)),
            .ridge(Ridge(pts: [pt(-0.05, 0.86), pt(0.3, 0.83), pt(0.65, 0.87), pt(1.05, 0.84)], color: PD.peach, smooth: true, lift: 2, seed: 602)),
            .forest(Forest(ground: [pt(-0.05, 0.92), pt(0.5, 0.91), pt(1.05, 0.925)], color: PD.pine,
                           xs: -0.02...0.62, count: 7, heights: 11...17, lift: 2.2, seed: 603)),
            .ridge(Ridge(pts: [pt(-0.05, 0.95), pt(0.5, 0.935), pt(1.05, 0.95)], color: PD.meadow, smooth: true, lift: 2, seed: 604)),
            .cabin(pt(0.8, 0.955), 17),
            .confetti(CGRect(x: 0.1, y: 0.94, width: 0.5, height: 0.04), 5, 11)
        ]
    }
}
