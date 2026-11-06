import SwiftUI

// The Quote widget, inscribed. The quote is the sky: it is set in the italic serif across the heavy, low-key cloud
// ceiling that fills the upper part of the painting, centred like a title. Below it the light breaks low over a
// snowy range (the sun or moon on its path, by the clock), and the author signs the dark ground in the lower left
// corner, in spaced capitals after a short rule, the way a painter signs a canvas. The next-quote button rests in the
// opposite corner. No weather here, so the painting follows the clock alone.

struct OIQuote: View {
    var quote: Quote
    var family: Family
    var now: Date = Mock.now

    var body: some View {
        switch family {
        case .large: OIQuoteLarge(quote: quote, now: now)
        case .medium: OIQuoteMedium(quote: quote, now: now)
        case .small: OIQuoteSmall(quote: quote, now: now)
        }
    }
}

struct OIQuotePainting: View {
    var canvas: OICanvas
    var now: Date

    var body: some View {
        OIPainting(canvas: canvas, clock: SkyClock(now: now, weather: nil), condition: .clear, phase: MoonPhase(date: now))
    }
}

/// The quote in the largest of `sizes` that fits the space it is given; the last size truncates with an ellipsis.
struct OIQuoteText: View {
    var text: String
    var sizes: [CGFloat]
    var lineLimit: Int

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(sizes.dropLast(), id: \.self) { s in
                line(s).fixedSize(horizontal: false, vertical: true)
            }
            line(sizes.last ?? 13).lineLimit(lineLimit).truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .omOnPaint()
    }

    private func line(_ s: CGFloat) -> some View {
        Text(text)
            .font(OMType.italic(s))
            .lineSpacing(s * 0.16)
            .multilineTextAlignment(.center)
            .foregroundStyle(OMInk.cream)
            .frame(maxWidth: .infinity)
    }
}

/// The signature: a short rule and the author in spaced capitals (nothing at all when the author is unknown).
struct OISignature: View {
    var author: String?
    var size: CGFloat

    var body: some View {
        if let author, !author.isEmpty {
            HStack(spacing: 7) {
                Rectangle().fill(OMInk.creamSoft.opacity(0.8)).frame(width: 14, height: 0.8)
                Text(author).omCaps(size, OMInk.creamSoft, tracking: size * 0.17).lineLimit(1).truncationMode(.tail)
            }
            .omOnPaint()
        }
    }
}

// MARK: - Large

struct OIQuoteLarge: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack {
            OIQuotePainting(canvas: .quoteLarge, now: now)
            VStack(spacing: 0) {
                OIQuoteText(text: quote.text, sizes: [21, 19.5, 18, 16.5, 15], lineLimit: 7)
                    .frame(height: 148)
                    .padding(.top, 16)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 10) {
                    OISignature(author: quote.author, size: 9)
                    Spacer(minLength: 0)
                    OMNextButton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Medium

struct OIQuoteMedium: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack {
            OIQuotePainting(canvas: .quoteMedium, now: now)
            VStack(spacing: 0) {
                OIQuoteText(text: quote.text, sizes: [18, 17, 16, 15, 14, 13], lineLimit: 4)
                    .frame(height: 80)
                    .padding(.top, 12)
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 10) {
                    OISignature(author: quote.author, size: 8.5)
                    Spacer(minLength: 0)
                    OMNextButton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Small

struct OIQuoteSmall: View {
    var quote: Quote
    var now: Date

    var body: some View {
        ZStack {
            OIQuotePainting(canvas: .quoteSmall, now: now)
            VStack(spacing: 0) {
                OIQuoteText(text: quote.text, sizes: [16, 15, 14, 13, 12], lineLimit: 4)
                    .frame(height: 68)
                    .padding(.top, 12)
                Spacer(minLength: 0)
                OISignature(author: quote.author, size: 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
