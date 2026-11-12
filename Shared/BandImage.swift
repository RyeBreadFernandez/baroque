import CoreGraphics
import Foundation
import ImageIO

/// A picture cut to the large Today's band, 328 x 82 points, at 2 pixels per point as the widgets' own images are, so
/// WidgetKit's image budget holds (656 x 164, a few tens of kilobytes as JPEG). ImageIO downsamples the picture to just
/// cover the band and never decodes it whole: the widget extension has little memory, and the brief's paintings come
/// at 1800 pixels. The middle is cut out to the band's 4:1. The Daily Brief's picture of the day goes through it
/// (BriefPicture), and so do the stand-ins `-renderWidgets` draws.
enum BandImage {
    static let width = 656
    static let height = 164
    static let quality = 0.82
    /// The most the downsampled picture keeps on its long side. Only a very wide or tall picture reaches it, and it's
    /// then scaled up to cover the band.
    static let maxSide = 2048

    /// The picture in `data` cut to the band, as JPEG data; nil when ImageIO can't read it.
    static func jpeg(from data: Data, width: Int = width, height: Int = height) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return cut(source, width: width, height: height).flatMap { encode($0) }
    }

    /// The same for a picture in a file (a download), read from the file as it's needed.
    static func jpeg(fromFile url: URL, width: Int = width, height: Int = height) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return cut(source, width: width, height: height).flatMap { encode($0) }
    }

    /// Downsampled to cover `width` x `height`, then its middle cut out at that size.
    static func cut(_ source: CGImageSource, width: Int = width, height: Int = height) -> CGImage? {
        guard let small = downsample(source, toCover: width, height) else { return nil }
        return centreCrop(small, width: width, height: height)
    }

    /// ImageIO's thumbnail, upright, with its short side just covering the band, or the picture as it is if that's
    /// smaller. Never a picture's embedded thumbnail, which may be tiny.
    static func downsample(_ source: CGImageSource, toCover width: Int, _ height: Int) -> CGImage? {
        guard CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              var w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              var h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue, w > 0, h > 0 else { return nil }
        // Orientations 5 to 8 turn the picture on its side.
        if let o = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue, (5...8).contains(o) { swap(&w, &h) }
        let scale = min(1, max(Double(width) / w, Double(height) / h))
        let side = min(maxSide, max(1, Int((max(w, h) * scale - 1e-6).rounded(.up))))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The middle of `image` at `width` x `height`: scaled to cover it, then cropped evenly on both sides, in sRGB and
    /// with no transparency (what's clear shows the stone's colour).
    static func centreCrop(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let box = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(srgbRed: 0xDC / 255, green: 0xD1 / 255, blue: 0xBB / 255, alpha: 1))
        context.fill(box)
        context.interpolationQuality = .high
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        let scale = max(box.width / iw, box.height / ih)
        let drawn = CGSize(width: iw * scale, height: ih * scale)
        context.draw(image, in: CGRect(x: (box.width - drawn.width) / 2, y: (box.height - drawn.height) / 2,
                                       width: drawn.width, height: drawn.height))
        return context.makeImage()
    }

    static func encode(_ image: CGImage, quality: Double = quality) -> Data? {
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? out as Data : nil
    }
}
