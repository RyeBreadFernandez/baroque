// Reads the text in an image with Vision, for scripts/mirror_setup.py: one JSON object per line with the text, its
// confidence and its box (x, y, w, h as fractions of the image, origin at the top left).
// Build: swiftc -O scripts/mirror/ocr.swift -o build/mirror-ocr   (mirror_setup.py does this when needed)
import Foundation
import ImageIO
import Vision

guard CommandLine.arguments.count > 1,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("usage: mirror-ocr <image>\n".data(using: .utf8)!)
    exit(1)
}
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: image).perform([request])
for observation in request.results ?? [] {
    guard let best = observation.topCandidates(1).first else { continue }
    let box = observation.boundingBox   // Vision's origin is at the bottom left
    let line: [String: Any] = ["text": best.string, "conf": best.confidence,
                               "x": box.minX, "y": 1 - box.maxY, "w": box.width, "h": box.height]
    print(String(data: try JSONSerialization.data(withJSONObject: line), encoding: .utf8)!)
}
